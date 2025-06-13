#!/bin/bash
set -e

# Minimal Product Page Generator
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="./data"
LOG_FILE="$DATA_DIR/product_generator.log"
SETUP_MARKER_FILE="$DATA_DIR/.setup_completed"
CREDENTIALS_FILE="$DATA_DIR/database_credentials.conf"

# Global variables
DOMAIN=""
FOLDER_LOCATION=""
DB_NAME=""
DB_USER=""
DB_PASSWORD=""
FORCE_MODE=${FORCE_MODE:-false}
SKIP_SETUP=${SKIP_SETUP:-false}
SKIP_CLEANUP=${SKIP_CLEANUP:-false}

mkdir -p "$DATA_DIR"

# Logging
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(TZ='Asia/Kolkata' date '+%Y-%m-%d %H:%M:%S IST')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Get credentials file for domain
get_credentials_file() {
    local domain=$1
    if [[ -n "$domain" ]]; then
        echo "$DATA_DIR/${domain}_database_credentials.conf"
    else
        echo "$CREDENTIALS_FILE"
    fi
}

# Sanitize domain name for database
sanitize_db_name() {
    local domain=$1
    echo "${domain//[.-]/_}" | tr '[:upper:]' '[:lower:]'
}

# Generate password
generate_password() {
    local domain=$1
    echo "$(sanitize_db_name $domain)_2@"
}

# Check if database exists
check_database_exists() {
    local domain=$1
    local credentials_file=$(get_credentials_file "$domain")
    [[ -f "$credentials_file" ]] && grep -q "Domain: $domain" "$credentials_file"
}

# Get database credentials
get_database_credentials() {
    local domain=$1
    local credentials_file=$(get_credentials_file "$domain")
    
    if [[ -f "$credentials_file" ]]; then
        export DB_NAME=$(grep "Database:" "$credentials_file" | cut -d' ' -f2)
        export DB_USER=$(grep "Username:" "$credentials_file" | cut -d' ' -f2)
        export DB_PASSWORD=$(grep "Password:" "$credentials_file" | cut -d' ' -f2)
        [[ -n "$DB_NAME" && -n "$DB_USER" && -n "$DB_PASSWORD" ]]
    else
        return 1
    fi
}

# Setup database
setup_database() {
    local domain=$1
    local db_name="$(sanitize_db_name $domain)_db"
    local db_user="$(sanitize_db_name $domain)_user"
    local db_password="$(generate_password $domain)"
    local credentials_file=$(get_credentials_file "$domain")

    cat > "$credentials_file" <<EOF
Domain: $domain
Database: $db_name
Username: $db_user
Password: $db_password
EOF
    chmod 600 "$credentials_file"

    sudo -u postgres psql <<EOF
CREATE DATABASE $db_name;
CREATE USER $db_user WITH PASSWORD '$db_password';
GRANT ALL PRIVILEGES ON DATABASE $db_name TO $db_user;
\c $db_name
GRANT ALL ON SCHEMA public TO $db_user;
ALTER USER $db_user WITH SUPERUSER;
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255),
    price INTEGER,
    product_link TEXT,
    category VARCHAR(100),
    image_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_products_title ON products(title);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);
CREATE INDEX IF NOT EXISTS idx_products_title_search ON products USING gin(to_tsvector('english', title));
GRANT ALL PRIVILEGES ON TABLE products TO $db_user;
GRANT USAGE, SELECT ON SEQUENCE products_id_seq TO $db_user;
EOF

    export DB_NAME="$db_name"
    export DB_USER="$db_user"
    export DB_PASSWORD="$db_password"
}

# Test database connection
test_database_connection() {
    local domain=$1
    get_database_credentials "$domain" || return 1
    PGPASSWORD="$DB_PASSWORD" psql -h localhost -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" >/dev/null 2>&1
}

# Cleanup database
cleanup_database() {
    local domain=$1
    local db_name="$(sanitize_db_name $domain)_db"
    local db_user="$(sanitize_db_name $domain)_user"
    sudo -u postgres psql -c "DROP DATABASE IF EXISTS $db_name; DROP USER IF EXISTS $db_user;" 2>/dev/null
}

# Handle database setup
handle_database_setup() {
    local domain=$1
    
    if check_database_exists "$domain"; then
        get_database_credentials "$domain"
        if test_database_connection "$domain"; then
            return 0
        else
            if [[ "$FORCE_MODE" == "true" ]]; then
                cleanup_database "$domain" && setup_database "$domain"
            else
                read -p "Recreate database? (y/n): " recreate_db
                [[ $recreate_db =~ ^[Yy]$ ]] && cleanup_database "$domain" && setup_database "$domain"
            fi
        fi
    else
        if [[ "$FORCE_MODE" == "true" ]]; then
            setup_database "$domain"
        else
            read -p "Create database? (y/n): " create_db
            [[ $create_db =~ ^[Yy]$ ]] && setup_database "$domain"
        fi
    fi
}

# Import product data
import_product_data() {
    local domain=$1
    local csv_file=""
    
    if [[ -f "$SCRIPT_DIR/data/products_database.csv" ]]; then
        csv_file="$SCRIPT_DIR/data/products_database.csv"
    else
        csv_file=$(find "$SCRIPT_DIR/data/" -name "*_database.csv" -type f 2>/dev/null | head -1)
    fi

    [[ -z "$csv_file" || ! -f "$csv_file" ]] && return 1

    get_database_credentials "$domain" || return 1
    PGPASSWORD="$DB_PASSWORD" psql -h localhost -U "$DB_USER" -d "$DB_NAME" -c "\COPY products(title, price, product_link, category, image_url) FROM '$csv_file' DELIMITER ',' CSV HEADER;" >/dev/null 2>&1
}

# Update search.php
update_search_php() {
    local folder_location=$1
    local search_php_source="./search.php"
    local search_php_dest="$folder_location/public/products/search.php"
    
    if [[ -f "$search_php_source" && -n "$DB_NAME" && -n "$DB_USER" && -n "$DB_PASSWORD" ]]; then
        mkdir -p "$(dirname "$search_php_dest")"
        cp "$search_php_source" "$search_php_dest"
        sed -i "s/'dbname'   => 'your_db_name'/'dbname'   => '$DB_NAME'/g" "$search_php_dest"
        sed -i "s/'user'    => 'your_user_name'/'user'    => '$DB_USER'/g" "$search_php_dest"
        sed -i "s/'password' => 'your_password'/'password' => '$DB_PASSWORD'/g" "$search_php_dest"
    fi
}

# Search domain folders
search_domain_folders() {
    local www_dir="/var/www"
    local folders=()
    
    if [[ -d "$www_dir" ]]; then
        while IFS= read -r -d '' folder; do
            local basename_folder=$(basename "$folder")
            if [[ "$basename_folder" == *.* ]] && [[ "$basename_folder" != "html" ]] && [[ -d "$folder" ]] && [[ -r "$folder" ]]; then
                folders+=("$folder")
            fi
        done < <(find "$www_dir" -maxdepth 1 -type d -print0 2>/dev/null)
        
        if [[ ${#folders[@]} -gt 0 ]]; then
            echo "Found domain folders:"
            for i in "${!folders[@]}"; do
                echo "  $((i+1)). ${folders[$i]}"
            done
            echo "  $((${#folders[@]}+1)). Enter custom path"
            
            read -p "Select option: " choice
            if [[ "$choice" -eq $((${#folders[@]}+1)) ]]; then
                read -p "Folder location: " FOLDER_LOCATION
            else
                FOLDER_LOCATION="${folders[$((choice-1))]}"
            fi
        else
            read -p "Folder location: " FOLDER_LOCATION
        fi
    else
        read -p "Folder location: " FOLDER_LOCATION
    fi
}
# Check setup completion
check_setup_completion() {
    [[ -f "$SETUP_MARKER_FILE" ]]
}

# Run setup script
run_setup_script() {
    local setup_script=""
    if [[ -f "./setup.sh" ]]; then
        setup_script="./setup.sh"
    elif [[ -f "$SCRIPT_DIR/modules/setup.sh" ]]; then
        setup_script="$SCRIPT_DIR/modules/setup.sh"
    elif [[ -f "$SCRIPT_DIR/setup.sh" ]]; then
        setup_script="$SCRIPT_DIR/setup.sh"
    fi
    
    if [[ -f "$setup_script" ]]; then
        chmod +x "$setup_script"
        if sudo "$setup_script"; then
            touch "$SETUP_MARKER_FILE"
        else
            exit 1
        fi
    else
        echo "Error: setup.sh not found"
        exit 1
    fi
}

# Handle setup check
handle_setup_check() {
    if ! check_setup_completion; then
        echo "Setup required. Run setup.sh? (y/n):"
        read -p "" setup_choice
        case $setup_choice in
            [Yy]*) run_setup_script ;;
            *) echo "Skipping setup" ;;
        esac
    fi
}

# Setup domain folder
setup_domain_folder() {
    search_domain_folders
    [[ -z "$FOLDER_LOCATION" ]] && exit 1
    
    export DOMAIN=$(basename "$FOLDER_LOCATION")
    [[ ! -d "$FOLDER_LOCATION" ]] && sudo mkdir -p "$FOLDER_LOCATION"
    export FOLDER_LOCATION
}

# Install prerequisites
install_nodejs() {
    if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
        if [[ -f /etc/debian_version ]]; then
            apt update && apt install -y nodejs npm
        elif [[ -f /etc/redhat-release ]]; then
            yum install -y nodejs npm
        fi
    fi
}

install_php() {
    if ! command -v php &> /dev/null || ! php -m | grep -q mysqli || ! php -m | grep -q pgsql; then
        if [[ -f /etc/debian_version ]]; then
            apt update && apt install -y php php-mysql php-pgsql php-cli
        elif [[ -f /etc/redhat-release ]]; then
            yum install -y php php-mysql php-pgsql php-cli
        fi
    fi
}

install_mysql() {
    if ! systemctl is-active --quiet mysql 2>/dev/null && ! systemctl is-active --quiet mysqld 2>/dev/null; then
        if [[ -f /etc/debian_version ]]; then
            export DEBIAN_FRONTEND=noninteractive
            apt update && apt install -y mysql-server mysql-client
            systemctl start mysql && systemctl enable mysql
            mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'root123';" 2>/dev/null || true
        elif [[ -f /etc/redhat-release ]]; then
            yum install -y mysql-server mysql
            systemctl start mysqld && systemctl enable mysqld
        fi
    fi
}

# Setup PostgreSQL
setup_postgresql() {
    if ! command -v psql >/dev/null 2>&1; then
        if [[ -f /etc/os-release ]]; then
            . /etc/os-release
            case $ID in
                ubuntu|debian)
                    sudo apt update && sudo apt install -y postgresql postgresql-contrib php-pgsql
                    sudo systemctl start postgresql && sudo systemctl enable postgresql
                    ;;
                centos|rhel|fedora)
                    if command -v dnf >/dev/null 2>&1; then
                        sudo dnf install -y postgresql postgresql-server postgresql-contrib
                    else
                        sudo yum install -y postgresql postgresql-server postgresql-contrib
                    fi
                    sudo postgresql-setup initdb
                    sudo systemctl start postgresql && sudo systemctl enable postgresql
                    ;;
            esac
        fi
    fi
    
    if ! sudo systemctl is-active --quiet postgresql; then
        sudo systemctl start postgresql
    fi
}

# Handle generation
handle_generation_workflow() {
    local folder_location=$1
    
    [[ ! -f "package.json" ]] && exit 1
    npm install >/dev/null 2>&1
    
    read -p "Generation mode (1=incremental, 2=force, 3=skip): " generation_choice
    
    case $generation_choice in
        1) npx gulp --folderLocation="$folder_location" ;;
        2) npx gulp --folderLocation="$folder_location" --force ;;
        3) return 0 ;;
        *) npx gulp --folderLocation="$folder_location" ;;
    esac
}

# Main function
main() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force) export FORCE_MODE=true; shift ;;
            --skip-setup) export SKIP_SETUP=true; shift ;;
            --skip-cleanup) export SKIP_CLEANUP=true; shift ;;
            --cleanup-only) [[ -d "node_modules" ]] && rm -rf node_modules; exit 0 ;;
            --help|-h) echo "Usage: $0 [--force] [--skip-setup] [--skip-cleanup] [--cleanup-only]"; exit 0 ;;
            *) shift ;;
        esac
    done

    mkdir -p "$DATA_DIR"
    [[ -f "product_generator.log" && ! -f "$LOG_FILE" ]] && mv "product_generator.log" "$LOG_FILE"
    [[ -f ".setup_completed" && ! -f "$SETUP_MARKER_FILE" ]] && mv ".setup_completed" "$SETUP_MARKER_FILE"
    
    install_nodejs
    install_php
    install_mysql
    
    if [[ "$SKIP_SETUP" != "true" ]]; then
        handle_setup_check
    fi
    
    setup_domain_folder
    setup_postgresql
    
    database_setup_success=false
    if handle_database_setup "$DOMAIN"; then
        database_setup_success=true
        update_search_php "$FOLDER_LOCATION"
    fi
    
    if handle_generation_workflow "$FOLDER_LOCATION"; then
        [[ "$database_setup_success" == "true" ]] && import_product_data "$DOMAIN"
        
        echo "Complete! Domain: $DOMAIN, Location: $FOLDER_LOCATION"
        [[ -n "$DB_NAME" ]] && echo "Database: $DB_NAME"
        
        if [[ "$SKIP_CLEANUP" != "true" ]]; then
            [[ -d "node_modules" ]] && rm -rf node_modules
            [[ -n "$FOLDER_LOCATION" && -d "$FOLDER_LOCATION/node_modules" ]] && rm -rf "$FOLDER_LOCATION/node_modules"
        fi
    fi
}

trap 'echo "Error at line $LINENO"' ERR
main "$@"