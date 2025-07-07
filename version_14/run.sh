#!/bin/bash
set -e

# Minimal Product Page Generator
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="./data_default" # Use local directory for persistent storage
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
ENABLE_CHATBOT=${ENABLE_CHATBOT:-false}

# Logging
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(TZ='Asia/Kolkata' date '+%Y-%m-%d %H:%M:%S IST')
    # Only create log directory if it's domain-specific (contains underscore)
    if [[ "$LOG_FILE" == *"_"* ]]; then
        mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    else
        # Before domain setup, just echo to console
        echo "[$timestamp] [$level] $message"
    fi
}

# Get credentials file for domain
get_credentials_file() {
    local domain=$1
    if [[ -n "$domain" ]]; then
        local domain_data_dir="./data_${domain}"
        mkdir -p "$domain_data_dir"
        echo "$domain_data_dir/${domain}_database_credentials.conf"
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

# Check if script is run from correct directory (either root or script directory)
check_root_directory() {
    local current_dir=$(pwd)
    
    # Check if we're in the script directory (has package.json, gulpfile.js, ecommerce_chatbot)
    if [[ -f "package.json" && -f "gulpfile.js" && -d "ecommerce_chatbot" ]]; then
        log_message "INFO" "✅ Script running from script directory: $current_dir"
        return 0
    fi
    
    # Check if we're in the root directory (can find the script in relative path)
    local script_name=$(basename "$0")
    local script_dir_name=$(basename "$SCRIPT_DIR")
    if [[ -f "generate_html_from_csv/$script_dir_name/$script_name" && -f "generate_html_from_csv/$script_dir_name/package.json" ]]; then
        log_message "INFO" "✅ Script running from root directory: $current_dir"
        return 0
    fi
    
    # Neither location is correct
    echo "❌ Error: Script must be run from either:"
    echo "  1. The script directory: $SCRIPT_DIR"
    echo "  2. The root directory where the codebase exists"
    echo ""
    echo "Current directory: $current_dir"
    echo ""
    echo "Required files not found. Please navigate to the correct directory."
    echo ""
    exit 1
}

# Check if .env file is properly populated
check_env_populated() {
    local env_file="$SCRIPT_DIR/ecommerce_chatbot/.env"
    
    if [[ ! -f "$env_file" ]]; then
        log_message "WARN" ".env file not found at: $env_file"
        return 1
    fi
    
    # Check for empty required variables
    local missing_vars=()
    
    if grep -q "^DB_NAME=$" "$env_file"; then
        missing_vars+=("DB_NAME")
    fi
    if grep -q "^DB_USER=$" "$env_file"; then
        missing_vars+=("DB_USER")
    fi
    if grep -q "^DB_PASSWORD=$" "$env_file"; then
        missing_vars+=("DB_PASSWORD")
    fi
    if grep -q "^DB_HOST=$" "$env_file"; then
        missing_vars+=("DB_HOST")
    fi
    if grep -q "^WC_URL=$" "$env_file"; then
        missing_vars+=("WC_URL")
    fi
    if grep -q "^GEMINI_API_KEY=$" "$env_file"; then
        missing_vars+=("GEMINI_API_KEY")
    fi
    if grep -q "^GEMINI_MODEL=$" "$env_file"; then
        missing_vars+=("GEMINI_MODEL")
    fi
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        echo ""
        echo "⚠️  .env file is missing required values:"
        printf "   - %s\n" "${missing_vars[@]}"
        echo ""
        echo "The script will attempt to populate these automatically."
        echo "For GEMINI_API_KEY, you'll need to provide it manually."
        echo "Get your API key from: https://makersuite.google.com/app/apikey"
        echo ""
        return 1
    fi
    
    log_message "INFO" "✅ .env file is properly populated"
    return 0
}

# Force populate .env file
force_populate_env() {
    echo ""
    echo "❌ Automatic .env population is disabled."
    echo "Please manually configure the .env file with the following values:"
    echo ""
    echo "Required variables in ecommerce_chatbot/.env:"
    echo "  DB_NAME=your_database_name"
    echo "  DB_USER=your_database_user"
    echo "  DB_PASSWORD=your_database_password"
    echo "  DB_HOST=localhost"
    echo "  DB_PORT=5432"
    echo "  WC_URL=https://your-domain.com"
    echo "  GEMINI_API_KEY=your_gemini_api_key"
    echo "  GEMINI_MODEL=gemini-2.0-flash-exp"
    echo ""
    echo "Get your Gemini API key from: https://makersuite.google.com/app/apikey"
    echo ""
    return 1
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
                read -p "Recreate database? (Y/n): " recreate_db
                recreate_db=${recreate_db:-Y}  # Default to Y
                [[ $recreate_db =~ ^[Yy]$ ]] && cleanup_database "$domain" && setup_database "$domain"
            fi
        fi
    else
        if [[ "$FORCE_MODE" == "true" ]]; then
            setup_database "$domain"
        else
            read -p "Create database? (Y/n): " create_db
            create_db=${create_db:-Y}  # Default to Y
            [[ $create_db =~ ^[Yy]$ ]] && setup_database "$domain"
        fi
    fi
}

# Import product data
import_product_data() {
    local domain=$1
    local domain_data_dir="./data_${domain}"
    local csv_file=""
    
    if [[ -f "$domain_data_dir/products_database.csv" ]]; then
        csv_file="$domain_data_dir/products_database.csv"
    else
        csv_file=$(find "$domain_data_dir/" -name "*_database.csv" -type f 2>/dev/null | head -1)
    fi

    [[ -z "$csv_file" || ! -f "$csv_file" ]] && return 1

    get_database_credentials "$domain" || return 1
    PGPASSWORD="$DB_PASSWORD" psql -h localhost -U "$DB_USER" -d "$DB_NAME" -c "\COPY products(title, price, product_link, category, image_url) FROM '$csv_file' DELIMITER ',' CSV HEADER;" >/dev/null 2>&1 || true
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
        log_message "INFO" "search.php updated and deployed"
    fi
}

# ============================================================================
# CHATBOT SETUP FUNCTIONS
# ============================================================================

# Setup chatbot configuration
setup_chatbot_config() {
    log_message "INFO" "Setting up chatbot configuration"
    
    # Get current server IP (force IPv4)
    SERVER_IP=$(hostname -I | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1 || echo "127.0.0.1")
    EXTERNAL_IP=$(curl -s -4 http://ipecho.net/plain 2>/dev/null || echo "")
    
    # Default port (will be updated later if Flask uses different port)
    local port="5000"
    
    # Auto-select best IP option
    if [ ! -z "$EXTERNAL_IP" ] && [ "$EXTERNAL_IP" != "$SERVER_IP" ]; then
        API_URL="http://$EXTERNAL_IP:$port"
        log_message "INFO" "Using external IP for API: $API_URL"
    else
        API_URL="http://$SERVER_IP:$port"
        log_message "INFO" "Using server IP for API: $API_URL"
    fi
    
    # Save to config file in ecommerce_chatbot directory
    mkdir -p "$SCRIPT_DIR/ecommerce_chatbot"
    echo "$API_URL" > "$SCRIPT_DIR/ecommerce_chatbot/chatbot_config.txt"
    log_message "INFO" "Chatbot configuration saved to ecommerce_chatbot/chatbot_config.txt"
    
    # Check if .env file exists but don't auto-populate
    if [ -f "$SCRIPT_DIR/ecommerce_chatbot/.env" ]; then
        log_message "INFO" "Found .env file - checking if properly configured"
        
        if ! check_env_populated; then
            echo ""
            echo "⚠️  .env file needs to be manually configured before chatbot setup."
            echo "Please edit ecommerce_chatbot/.env and fill in the required values:"
            echo ""
            echo "Required variables:"
            echo "  DB_NAME=your_database_name"
            echo "  DB_USER=your_database_user"
            echo "  DB_PASSWORD=your_database_password"
            echo "  DB_HOST=localhost"
            echo "  DB_PORT=5432"
            echo "  WC_URL=https://${DOMAIN}"
            echo "  GEMINI_API_KEY=your_gemini_api_key"
            echo "  GEMINI_MODEL=gemini-2.0-flash-exp"
            echo ""
            echo "Get your Gemini API key from: https://makersuite.google.com/app/apikey"
            echo ""
            log_message "WARN" ".env file requires manual configuration"
        else
            log_message "INFO" ".env file is properly configured"
        fi
    else
        log_message "WARN" ".env file not found"
    fi
}

# Update chatbot config with actual Flask port
update_chatbot_config_port() {
    local actual_port="$1"
    log_message "INFO" "Updating chatbot config with actual port: $actual_port"
    
    # Get current server IP (force IPv4)
    SERVER_IP=$(hostname -I | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1 || echo "127.0.0.1")
    EXTERNAL_IP=$(curl -s -4 http://ipecho.net/plain 2>/dev/null || echo "")
    
    # Update API URL with actual port
    if [ ! -z "$EXTERNAL_IP" ] && [ "$EXTERNAL_IP" != "$SERVER_IP" ]; then
        API_URL="http://$EXTERNAL_IP:$actual_port"
        log_message "INFO" "Updated API URL with external IP: $API_URL"
    else
        API_URL="http://$SERVER_IP:$actual_port"
        log_message "INFO" "Updated API URL with server IP: $API_URL"
    fi
    
    # Update config file in ecommerce_chatbot directory
    mkdir -p "$SCRIPT_DIR/ecommerce_chatbot"
    echo "$API_URL" > "$SCRIPT_DIR/ecommerce_chatbot/chatbot_config.txt"
    log_message "INFO" "Chatbot configuration updated with actual port"
}

# Setup Python environment for chatbot
setup_python_environment() {
    log_message "INFO" "Setting up Python environment for chatbot"
    
    # Check if we're in the right directory
    if [ ! -d "ecommerce_chatbot" ]; then
        log_message "WARN" "ecommerce_chatbot directory not found, skipping chatbot setup"
        return 1
    fi
    
    # Navigate to the ecommerce_chatbot directory
    cd ecommerce_chatbot
    
    # Install python3-venv if not available
    if ! python3 -m venv --help > /dev/null 2>&1; then
        log_message "INFO" "Installing python3-venv..."
        if command -v apt > /dev/null 2>&1; then
            sudo apt update && sudo apt install -y python3-venv python3-pip > /dev/null 2>&1
        elif command -v yum > /dev/null 2>&1; then
            sudo yum install -y python3-venv python3-pip > /dev/null 2>&1
        elif command -v dnf > /dev/null 2>&1; then
            sudo dnf install -y python3-venv python3-pip > /dev/null 2>&1
        fi
    fi
    
    # Create virtual environment if it doesn't exist
    if [ ! -d "venv" ]; then
        log_message "INFO" "Creating virtual environment..."
        python3 -m venv venv
    fi
    
    # Activate virtual environment
    source venv/bin/activate
    
    # Upgrade pip and install requirements
    pip install --upgrade pip > /dev/null 2>&1
    if [ -f "requirements.txt" ]; then
        log_message "INFO" "Installing Python dependencies..."
        pip install -r requirements.txt > /dev/null 2>&1
    fi
    
    # Return to original directory
    cd ..
    log_message "INFO" "Python environment setup completed"
    return 0
}

# Start Flask chatbot application
start_flask_app() {
    log_message "INFO" "Starting Flask chatbot application"
    
    if [ ! -d "ecommerce_chatbot" ]; then
        log_message "WARN" "ecommerce_chatbot directory not found, skipping Flask startup"
        return 1
    fi
    
    cd ecommerce_chatbot
    
    # Check if virtual environment exists and activate it
    if [ -d "venv" ]; then
        source venv/bin/activate
    else
        log_message "WARN" "Virtual environment not found, skipping Flask startup"
        cd ..
        return 1
    fi
    
    # Check if app.py exists
    if [ ! -f "app.py" ]; then
        log_message "WARN" "app.py not found, skipping Flask startup"
        cd ..
        return 1
    fi
    
    # Kill any existing Flask process
    pkill -9 -f "python.*app.py" 2>/dev/null || true
    sleep 2  # Wait for processes to fully terminate
    
    # Remove old port file if exists
    rm -f flask_port.txt
    
    # Start Flask app in background (it will find its own port)
    nohup python app.py > flask_app.log 2>&1 &
    FLASK_PID=$!
    echo $FLASK_PID > flask_app.pid
    
    log_message "INFO" "Flask app started with PID: $FLASK_PID"
    
    # Wait for Flask to start and determine the port
    local attempts=0
    local max_attempts=15
    local flask_port=""
    
    while [ $attempts -lt $max_attempts ]; do
        sleep 1
        
        # Check if process is still running
        if ! kill -0 $FLASK_PID 2>/dev/null; then
            log_message "ERROR" "Flask process died unexpectedly"
            break
        fi
        
        # Check if port file was created
        if [ -f flask_port.txt ]; then
            flask_port=$(cat flask_port.txt)
            log_message "INFO" "Flask app found available port: $flask_port"
            
            # Verify Flask is actually listening on that port
            if netstat -tlnp | grep -q ":$flask_port.*$FLASK_PID"; then
                log_message "INFO" "Flask app is running successfully on port $flask_port"
                
                # Update chatbot config with the actual port
                update_chatbot_config_port "$flask_port"
                
                cd ..
                return 0
            fi
        fi
        
        attempts=$((attempts + 1))
    done
    
    log_message "ERROR" "Flask app failed to start properly"
    # Show last few lines of log for debugging
    if [ -f flask_app.log ]; then
        tail -10 flask_app.log | while read line; do
            log_message "ERROR" "Flask log: $line"
        done
    fi
    cd ..
    return 1
}

# Deploy chatbot proxy
deploy_chatbot_proxy() {
    local folder_location=$1
    log_message "INFO" "Deploying chatbot proxy"
    
    local proxy_source="./chatbot_proxy.php"
    local proxy_dest="$folder_location/chatbot_proxy.php"
    
    if [[ ! -f "$proxy_source" ]]; then
        log_message "WARN" "Source chatbot_proxy.php not found, skipping deployment"
        return 1
    fi
    
    # Copy chatbot proxy to website root
    cp "$proxy_source" "$proxy_dest"
    
    # Also copy chatbot_config.txt if it exists
    if [[ -f "$SCRIPT_DIR/ecommerce_chatbot/chatbot_config.txt" ]]; then
        cp "$SCRIPT_DIR/ecommerce_chatbot/chatbot_config.txt" "$folder_location/chatbot_config.txt"
        log_message "INFO" "chatbot_config.txt deployed to website"
    fi
    
    log_message "INFO" "chatbot_proxy.php deployed to: $proxy_dest"
    
    # Set proper permissions
    chmod 644 "$proxy_dest" 2>/dev/null || true
    if [[ -f "$folder_location/chatbot_config.txt" ]]; then
        chmod 644 "$folder_location/chatbot_config.txt" 2>/dev/null || true
    fi
    
    return 0
}

# Test chatbot API connection
test_chatbot_connection() {
    if [ -f "$SCRIPT_DIR/ecommerce_chatbot/chatbot_config.txt" ]; then
        local api_url=$(cat "$SCRIPT_DIR/ecommerce_chatbot/chatbot_config.txt")
        log_message "INFO" "Testing chatbot API connection to: $api_url"
        
        # Try multiple times as Flask might take a moment to be ready
        local test_attempts=0
        local max_test_attempts=5
        
        while [ $test_attempts -lt $max_test_attempts ]; do
            echo "Attempt $((test_attempts + 1))/$max_test_attempts..."
            if curl -s --connect-timeout 5 --max-time 10 "$api_url/message?input=hello" > /dev/null 2>&1; then
                log_message "INFO" "✅ Chatbot API connection successful!"
                echo "✅ Chatbot is responding at: $api_url"
                return 0
            fi
            test_attempts=$((test_attempts + 1))
            if [ $test_attempts -lt $max_test_attempts ]; then
                sleep 2
            fi
        done
        
        log_message "WARN" "❌ Chatbot API connection failed after $max_test_attempts attempts"
        echo "❌ Chatbot API not responding at: $api_url"
        return 1
    else
        log_message "WARN" "No chatbot configuration found"
        return 1
    fi
}

# Complete chatbot setup
setup_chatbot_complete() {
    local folder_location=$1
    local chatbot_success=true
    
    log_message "INFO" "Starting complete chatbot setup..."
    
    # Ensure we're in the script directory where ecommerce_chatbot exists
    cd "$SCRIPT_DIR"
    
    # Step 1: Configure API endpoints
    setup_chatbot_config || chatbot_success=false
    
    # Step 2: Setup Python environment
    if [ "$chatbot_success" = true ]; then
        setup_python_environment || chatbot_success=false
    fi
    
    # Step 3: Start Flask application
    if [ "$chatbot_success" = true ]; then
        start_flask_app || chatbot_success=false
    fi
    
    # Step 4: Deploy proxy files
    if [ "$chatbot_success" = true ]; then
        deploy_chatbot_proxy "$folder_location" || chatbot_success=false
    fi
    
    # Step 5: Test connection
    if [ "$chatbot_success" = true ]; then
        sleep 2  # Give Flask time to fully start
        test_chatbot_connection || chatbot_success=false
    fi
    
    if [ "$chatbot_success" = true ]; then
        log_message "INFO" "✅ Complete chatbot setup successful!"
        return 0
    else
        log_message "WARN" "⚠️ Chatbot setup completed with some issues"
        return 1
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
            
            read -p "Select option [1]: " choice
            choice=${choice:-1}  # Default to 1 if empty
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
    elif [[ -f "$SCRIPT_DIR/setup.sh" ]]; then
        setup_script="$SCRIPT_DIR/setup.sh"
    elif [[ -f "$SCRIPT_DIR/setup.sh" ]]; then
        setup_script="$SCRIPT_DIR/setup.sh"
    fi
    
    if [[ -f "$setup_script" ]]; then
        chmod +x "$setup_script"
        
        # Try to get admin email from config.json
        local admin_email=""
        if [[ -f "./config.json" ]]; then
            admin_email=$(node -e "try { console.log(JSON.parse(require('fs').readFileSync('config.json', 'utf8')).website.adminEmail || ''); } catch(e) { console.log(''); }" 2>/dev/null || echo "")
        fi
        
        if sudo "$setup_script" "$DOMAIN" "$FOLDER_LOCATION" "$admin_email"; then
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
        read -p "Setup required. Run setup.sh? (Y/n): " setup_choice
        setup_choice=${setup_choice:-Y}  # Default to Y
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
    
    # Update DATA_DIR to be domain-specific in temp directory
    DATA_DIR="./data_${DOMAIN}"
    LOG_FILE="$DATA_DIR/product_generator.log"
    SETUP_MARKER_FILE="$DATA_DIR/.setup_completed"
    CREDENTIALS_FILE="$DATA_DIR/database_credentials.conf"
    
    # Create domain-specific data directory in temp
    mkdir -p "$DATA_DIR"
    
    # Migrate old files if they exist
    if [[ -f "./data/product_generator.log" && ! -f "$LOG_FILE" ]]; then
        mv "./data/product_generator.log" "$LOG_FILE" 2>/dev/null || true
    fi
    if [[ -f "./data/.setup_completed" && ! -f "$SETUP_MARKER_FILE" ]]; then
        mv "./data/.setup_completed" "$SETUP_MARKER_FILE" 2>/dev/null || true
    fi
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

# Find npx command
find_npx() {
    # Try common locations
    if command -v npx >/dev/null 2>&1; then
        echo "npx"
    elif [ -f "/tmp/node-v20.11.0-linux-x64/bin/npx" ]; then
        echo "/tmp/node-v20.11.0-linux-x64/bin/npx"
    elif [ -f "/usr/local/bin/npx" ]; then
        echo "/usr/local/bin/npx"
    else
        # Fallback: try to find npx relative to npm
        local npm_path=$(which npm)
        if [ -n "$npm_path" ]; then
            local npx_path="${npm_path%/*}/npx"
            if [ -f "$npx_path" ]; then
                echo "$npx_path"
                return
            fi
        fi
        echo ""
    fi
}

# Handle generation
handle_generation_workflow() {
    local folder_location=$1
    local npx_cmd=$(find_npx)
    
    # Change to script directory where package.json is located
    cd "$SCRIPT_DIR"
    [[ ! -f "package.json" ]] && exit 1
    npm install >/dev/null 2>&1
    
    if [ -z "$npx_cmd" ]; then
        echo "Error: npx not found. Please install Node.js properly."
        exit 1
    fi
    
    read -p "Generation mode (1=incremental, 2=force, 3=skip): " generation_choice
    
    case $generation_choice in
        1) $npx_cmd gulp --folderLocation="$folder_location" ;;
        2) $npx_cmd gulp --folderLocation="$folder_location" --force ;;
        3) return 0 ;;
        *) $npx_cmd gulp --folderLocation="$folder_location" ;;
    esac
}

# Interactive menu functions
show_main_menu() {
    echo ""
    echo "=================================="
    echo "    Product Page Generator"
    echo "=================================="
    echo ""
    echo "Please select an option:"
    echo ""
    echo "1.  🚀 Complete Setup & Generate HTML Pages"
    echo "2.  ⚙️  Setup Configuration Only (No Generation)"
    echo "3.  🚀 Setup & Configure E-commerce Chatbot"
    echo "4.  🔄 Generate HTML Pages Only (Skip Setup)"
    echo "5.  🤖 Test E-commerce Chatbot Connection"
    echo "6.  🛑 Stop Running Chatbot Process"
    echo "7.  📊 Show Current Chatbot Status & Logs"
    echo "8.  🔍 Inspect SQLite Chatbot Session Database"
    echo "9.  🧹 Clean SQLite Session Database Only"
    echo "10. 🔍 Test MySQL and PostgreSQL Database Connections"
    echo "11. 🔮 Test Gemini AI API Connection"
    echo "12. 🌐 Test All Services (Database + Chatbot + API)"
    echo "13. 📝 Check Environment Variables Configuration"
    echo "14. 🗑️  Clean PostgreSQL Database (Remove All Data)"
    echo "15. 🧽 Full System Cleanup (All Files & Data)"
    echo "16. ❓ Show Help & Command Line Options"
    echo "17. 🚪 Exit Application"
    echo ""
    read -p "Enter your choice [1-17]: " choice
    echo ""
    return $choice
}

# Removed old submenu functions - now using single consolidated menu

# Validation functions
validate_domain() {
    local domain=$1
    if [[ -z "$domain" ]]; then
        echo "❌ Domain cannot be empty"
        return 1
    fi
    if [[ ! "$domain" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo "❌ Invalid domain format. Example: example.com"
        return 1
    fi
    return 0
}

validate_folder_path() {
    local folder=$1
    if [[ -z "$folder" ]]; then
        echo "❌ Folder path cannot be empty"
        return 1
    fi
    if [[ ! "$folder" =~ ^/ ]]; then
        echo "❌ Please provide an absolute path (starting with /)"
        return 1
    fi
    return 0
}

get_user_confirmation() {
    local message=$1
    read -p "$message (Y/n): " confirm
    confirm=${confirm:-Y}  # Default to Y if empty
    [[ $confirm =~ ^[Yy]$ ]]
}

# Test functions
test_database_only() {
    local test_script="$SCRIPT_DIR/test_services.sh"
    if [[ ! -f "$test_script" ]]; then
        echo "❌ Test script not found: $test_script"
        return 1
    fi
    
    "$test_script" --database
}

test_chatbot_only() {
    echo "🤖 Testing chatbot connection..."
    if test_chatbot_connection; then
        echo "✅ Chatbot connection successful!"
        return 0
    else
        echo "❌ Chatbot connection failed"
        return 1
    fi
}

test_gemini_api() {
    local test_script="$SCRIPT_DIR/test_services.sh"
    if [[ ! -f "$test_script" ]]; then
        echo "❌ Test script not found: $test_script"
        return 1
    fi
    
    "$test_script" --gemini
}

test_all_connections() {
    echo "🌐 Testing all connections..."
    local success=true
    
    echo ""
    echo "Testing database..."
    if ! test_database_only; then
        success=false
    fi
    
    echo ""
    echo "Testing chatbot..."
    if ! test_chatbot_only; then
        success=false
    fi
    
    echo ""
    echo "Testing Gemini API..."
    if ! test_gemini_api; then
        success=false
    fi
    
    echo ""
    if [[ "$success" == "true" ]]; then
        echo "✅ All connections are working properly!"
        return 0
    else
        echo "❌ Some connections failed. Check the logs above."
        return 1
    fi
}

# Session inspection functions
inspect_sessions() {
    local session_script="$SCRIPT_DIR/ecommerce_chatbot/inspect_sessions.sh"
    if [[ ! -f "$session_script" ]]; then
        log_error "Session inspector script not found: $session_script"
        return 1
    fi
    
    bash "$session_script"
}

clean_sessions_only() {
    local session_script="$SCRIPT_DIR/ecommerce_chatbot/inspect_sessions.sh"
    if [[ ! -f "$session_script" ]]; then
        log_error "Session inspector script not found: $session_script"
        return 1
    fi
    
    bash "$session_script" --clean
}

# Cleanup functions
cleanup_node_modules() {
    echo "🧹 Cleaning up Node modules..."
    if [[ -d "node_modules" ]]; then
        echo "Removing local node_modules..."
        rm -rf node_modules 2>/dev/null
        echo "✅ Local node_modules removed"
    fi
    if [[ -n "$FOLDER_LOCATION" && -d "$FOLDER_LOCATION/node_modules" ]]; then
        echo "Removing target node_modules..."
        rm -rf "$FOLDER_LOCATION/node_modules" 2>/dev/null
        echo "✅ Target node_modules removed"
    fi
    echo "Node modules cleanup completed"
}

cleanup_database_interactive() {
    if [[ -z "$DOMAIN" ]]; then
        echo "❌ Domain not set. Cannot clean database."
        return 1
    fi
    
    echo "🗑️  Database cleanup for domain: $DOMAIN"
    if get_user_confirmation "⚠️  This will permanently delete all data. Continue?"; then
        cleanup_database "$DOMAIN"
        echo "✅ Database cleaned up"
    else
        echo "Database cleanup cancelled"
    fi
}

full_cleanup() {
    echo "🧽 Starting full cleanup..."
    if get_user_confirmation "⚠️  This will clean everything (databases, chatbot, node_modules, cache files). Continue?"; then
        echo "Cleaning Node.js files..."
        cleanup_node_modules
        
        echo "Cleaning Python cache files..."
        find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
        find . -name "*.pyc" -type f -delete 2>/dev/null || true
        find . -name "*.pyo" -type f -delete 2>/dev/null || true
        echo "✅ Python cache files removed"
        
        echo "Cleaning Python virtual environments..."
        find . -name "venv" -type d -exec rm -rf {} + 2>/dev/null || true
        find . -name ".venv" -type d -exec rm -rf {} + 2>/dev/null || true
        find . -name "env" -type d -exec rm -rf {} + 2>/dev/null || true
        echo "✅ Python virtual environments removed"
        
        echo "Cleaning build and cache files..."
        rm -rf .cache 2>/dev/null || true
        rm -rf .pytest_cache 2>/dev/null || true
        rm -rf .coverage 2>/dev/null || true
        rm -rf dist/ 2>/dev/null || true
        rm -rf build/ 2>/dev/null || true
        rm -rf *.egg-info/ 2>/dev/null || true
        echo "✅ Build and cache files removed"
        
        echo "Cleaning log files..."
        find . -name "*.log" -type f -delete 2>/dev/null || true
        find . -name "*.tmp" -type f -delete 2>/dev/null || true
        echo "✅ Log and temporary files removed"
        
        echo "Cleaning data directories..."
        rm -rf ./data_*/ 2>/dev/null || true
        echo "✅ Data directories removed"
        
        echo "Cleaning chatbot session data..."
        rm -rf ecommerce_chatbot/tmp/ 2>/dev/null || true
        find . -name "*.db" -path "*/ecommerce_chatbot/*" -delete 2>/dev/null || true
        echo "✅ Chatbot session data removed"
        
        echo "Stopping chatbot..."
        cleanup_chatbot
        
        if [[ -n "$DOMAIN" ]]; then
            echo "Cleaning database for domain: $DOMAIN"
            cleanup_database "$DOMAIN"
        fi
        
        echo "✅ Full cleanup completed"
    else
        echo "Full cleanup cancelled"
    fi
}

# Interactive workflow functions
interactive_setup() {
    echo "⚙️  Starting interactive setup..."
    
    # Get domain and folder location if not set
    if [[ -z "$DOMAIN" || -z "$FOLDER_LOCATION" ]]; then
        echo ""
        echo "Searching for domain folders..."
        search_domain_folders
        if [[ -n "$FOLDER_LOCATION" ]]; then
            export DOMAIN=$(basename "$FOLDER_LOCATION")
            if ! validate_folder_path "$FOLDER_LOCATION"; then
                echo "Invalid folder path provided"
                return 1
            fi
        else
            # Fallback to manual input if no domains found
            while true; do
                read -p "Enter domain (e.g., example.com): " input_domain
                if validate_domain "$input_domain"; then
                    export DOMAIN="$input_domain"
                    read -p "Enter folder location (e.g., /var/www/$input_domain): " FOLDER_LOCATION
                    if validate_folder_path "$FOLDER_LOCATION"; then
                        break
                    fi
                fi
            done
        fi
    fi
    
    echo ""
    echo "Configuration:"
    echo "  Domain: $DOMAIN"
    echo "  Folder: $FOLDER_LOCATION"
    echo ""
    
    if get_user_confirmation "Proceed with setup?"; then
# Create domain-specific data directory
        DATA_DIR="./data_${DOMAIN}"
        LOG_FILE="$DATA_DIR/product_generator.log"
        SETUP_MARKER_FILE="$DATA_DIR/.setup_completed"
        CREDENTIALS_FILE="$DATA_DIR/database_credentials.conf"
        mkdir -p "$DATA_DIR"
        
        # Install prerequisites
        echo "Installing prerequisites..."
        install_nodejs
        install_php
        install_mysql
        setup_postgresql
        
        # Handle setup
        if [[ "$SKIP_SETUP" != "true" ]]; then
            handle_setup_check
        fi
        
        # Handle database
        if handle_database_setup "$DOMAIN"; then
            echo "✅ Database setup completed"
            update_search_php "$FOLDER_LOCATION"
        else
            echo "❌ Database setup failed"
            return 1
        fi
        
        echo "✅ Setup completed successfully!"
        return 0
    else
        echo "Setup cancelled"
        return 1
    fi
}

interactive_generation() {
    echo "🔄 Starting interactive generation..."
    
    if [[ -z "$DOMAIN" || -z "$FOLDER_LOCATION" ]]; then
        echo "❌ Domain or folder not configured. Please run setup first."
        return 1
    fi
    
    echo "Generation will use:"
    echo "  Domain: $DOMAIN"
    echo "  Folder: $FOLDER_LOCATION"
    echo ""
    
    if get_user_confirmation "Proceed with generation?"; then
        if handle_generation_workflow "$FOLDER_LOCATION"; then
            echo "✅ Generation completed successfully!"
            
            # Import data if database is available
            if [[ -n "$DB_NAME" ]]; then
                echo "Importing product data..."
                import_product_data "$DOMAIN"
                echo "✅ Data import completed"
            fi
            
            return 0
        else
            echo "❌ Generation failed"
            return 1
        fi
    else
        echo "Generation cancelled"
        return 1
    fi
}

interactive_chatbot_setup() {
    echo "🤖 Starting chatbot setup..."
    
    # For standalone chatbot setup, we don't need domain/folder
    # The chatbot can run independently
    if [[ -z "$DOMAIN" || -z "$FOLDER_LOCATION" ]]; then
        echo "ℹ️  Running standalone chatbot setup (no domain integration)"
        FOLDER_LOCATION="/tmp/chatbot_standalone"
        mkdir -p "$FOLDER_LOCATION"
    fi
    
    # Check .env file
    if ! check_env_populated; then
        echo "📝 .env file needs to be manually configured before chatbot setup."
        echo "Please edit ecommerce_chatbot/.env and fill in all required values."
        echo "After configuration, you can run chatbot setup again."
        return 1
    fi
    
    read -p "Proceed with chatbot setup? (Y/n): " chatbot_confirm
    chatbot_confirm=${chatbot_confirm:-Y}
    if [[ $chatbot_confirm =~ ^[Yy] ]]; then
        if setup_chatbot_complete "$FOLDER_LOCATION"; then
            echo "✅ Chatbot setup completed successfully!"
            return 0
        else
            echo "❌ Chatbot setup failed"
            return 1
        fi
    else
        echo "Chatbot setup cancelled"
        return 1
    fi
}

show_chatbot_status() {
    echo "📊 Chatbot Status:"
    echo ""
    
    if [ -f "$SCRIPT_DIR/ecommerce_chatbot/chatbot_config.txt" ]; then
        echo "API URL: $(cat "$SCRIPT_DIR/ecommerce_chatbot/chatbot_config.txt")"
    else
        echo "❌ Chatbot configuration not found"
    fi
    
    if [ -f "$SCRIPT_DIR/ecommerce_chatbot/flask_app.pid" ]; then
        local flask_pid=$(cat "$SCRIPT_DIR/ecommerce_chatbot/flask_app.pid")
        if kill -0 $flask_pid 2>/dev/null; then
            echo "Flask App: ✅ Running (PID: $flask_pid)"
        else
            echo "Flask App: ❌ Not running (PID: $flask_pid)"
        fi
    else
        echo "Flask App: ❌ Not started"
    fi
    
    echo ""
    echo "Testing connection..."
    if test_chatbot_connection; then
        echo "✅ Chatbot is responding properly"
    else
        echo "❌ Chatbot is not responding"
    fi
}

# Main function
main() {
    # First check if we're running from the correct directory
    check_root_directory
    
    # Handle command line arguments
    local interactive_mode=true
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force) export FORCE_MODE=true; shift ;;
            --skip-setup) export SKIP_SETUP=true; shift ;;
            --skip-cleanup) export SKIP_CLEANUP=true; shift ;;
            --enable-chatbot) export ENABLE_CHATBOT=true; shift ;;
            --populate-env) force_populate_env; exit 1 ;;
            --check-env) check_env_populated && echo "✅ .env file is properly configured" || echo "❌ .env file needs configuration"; exit 0 ;;
            --stop-chatbot) cleanup_chatbot; echo "🛑 Chatbot stopped"; exit 0 ;;
            --cleanup-only) [[ -d "node_modules" ]] && rm -rf node_modules; exit 0 ;;
            --non-interactive) interactive_mode=false; shift ;;
            --help|-h) 
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --force              Force regeneration of all files"
                echo "  --skip-setup         Skip the setup.sh execution"
                echo "  --skip-cleanup       Skip cleanup of node_modules"
                echo "  --enable-chatbot     Automatically enable chatbot setup"
                echo "  --populate-env       Show .env configuration instructions"
                echo "  --check-env          Check if .env file is properly configured"
                echo "  --stop-chatbot       Stop running chatbot processes"
                echo "  --cleanup-only       Remove node_modules and exit"
                echo "  --non-interactive    Run in non-interactive mode (original behavior)"
                echo "  --help, -h           Show this help message"
                exit 0 ;;
            *) shift ;;
        esac
    done
    
    # If non-interactive mode is specified, run original workflow
    if [[ "$interactive_mode" == "false" ]]; then
        run_original_workflow
        return $?
    fi
    
    # Interactive mode
    while true; do
        show_main_menu
        choice=$?
        
        case $choice in
            1) 
                echo "🚀 Starting complete setup and generation..."
                if interactive_setup; then
                    interactive_generation
                    if get_user_confirmation "Setup chatbot?"; then
                        interactive_chatbot_setup
                    fi
                fi
                ;;
            2) 
                echo "⚙️ Starting configuration and setup..."
                interactive_setup
                ;;
            3) interactive_chatbot_setup ;;
            4) 
                echo "🔄 Starting page generation..."
                interactive_generation
                ;;
            5) test_chatbot_only ;;
            6) 
                echo "🛑 Stopping chatbot processes..."
                cleanup_chatbot
                echo "✅ Chatbot stopped successfully"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            7) show_chatbot_status ;;
            8) inspect_sessions ;;
            9) clean_sessions_only ;;
            10) 
                echo "🔍 Testing Database Connections..."
                echo ""
                
                # Load environment variables
                if [[ -f "$SCRIPT_DIR/ecommerce_chatbot/.env" ]]; then
                    source "$SCRIPT_DIR/ecommerce_chatbot/.env"
                fi
                
                # Test MySQL
                echo "📊 MySQL Database:"
                if timeout 5 bash -c "exec 3<>/dev/tcp/$DB_HOST/$DB_PORT" 2>/dev/null; then
                    if LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu mysql \
                        --connect-timeout=5 \
                        -h "$DB_HOST" \
                        -P "$DB_PORT" \
                        -u "$DB_USER" \
                        -p"$DB_PASSWORD" \
                        -D "$DB_NAME" \
                        -e "SELECT 1;" >/dev/null 2>&1; then
                        echo "   ✅ MySQL: Connected ($DB_HOST:$DB_PORT)"
                    else
                        echo "   ❌ MySQL: Authentication failed"
                    fi
                else
                    echo "   ❌ MySQL: Cannot connect to $DB_HOST:$DB_PORT"
                fi
                
                # Test PostgreSQL
                echo ""
                echo "🐘 PostgreSQL Database:"
                if [[ -n "$PG_DB_HOST" && -n "$PG_DB_USER" && -n "$PG_DB_PASSWORD" && -n "$PG_DB_NAME" ]]; then
                    if timeout 5 bash -c "exec 3<>/dev/tcp/$PG_DB_HOST/$PG_DB_PORT" 2>/dev/null; then
                        if PGPASSWORD="$PG_DB_PASSWORD" psql \
                            -h "$PG_DB_HOST" \
                            -p "$PG_DB_PORT" \
                            -U "$PG_DB_USER" \
                            -d "$PG_DB_NAME" \
                            -c "SELECT 1;" >/dev/null 2>&1; then
                            echo "   ✅ PostgreSQL: Connected ($PG_DB_HOST:$PG_DB_PORT)"
                        else
                            echo "   ❌ PostgreSQL: Authentication failed"
                        fi
                    else
                        echo "   ❌ PostgreSQL: Cannot connect to $PG_DB_HOST:$PG_DB_PORT"
                    fi
                else
                    echo "   ⚠️  PostgreSQL: Not configured"
                fi
                
                echo ""
                read -p "Press Enter to continue..."
                ;;
            11) 
                echo "🔮 Testing Gemini API..."
                echo ""
                
                # Load environment variables
                if [[ -f "$SCRIPT_DIR/ecommerce_chatbot/.env" ]]; then
                    source "$SCRIPT_DIR/ecommerce_chatbot/.env"
                fi
                
                if [[ -z "$GEMINI_API_KEY" ]]; then
                    echo "   ❌ Gemini API: API key not configured"
                elif [[ -z "$GEMINI_MODEL" ]]; then
                    echo "   ❌ Gemini API: Model not configured"
                else
                    echo "   🔑 API Key: ${GEMINI_API_KEY:0:10}... (masked)"
                    echo "   🤖 Model: $GEMINI_MODEL"
                    echo ""
                    echo "   Testing connection..."
                    
                    # Simple API test
                    local test_payload='{"contents": [{"parts": [{"text": "Say: API Test OK"}]}]}'
                    local api_url="https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}"
                    
                    local response=$(curl -s --connect-timeout 10 --max-time 30 \
                        -H "Content-Type: application/json" \
                        -d "$test_payload" \
                        "$api_url" 2>/dev/null)
                    
                    if [[ $? -eq 0 ]] && ! echo "$response" | grep -q '"error"' && echo "$response" | grep -q '"text"'; then
                        echo "   ✅ Gemini API: Connected and responding"
                    elif echo "$response" | grep -q '"error"'; then
                        echo "   ❌ Gemini API: API error (check key/model)"
                    else
                        echo "   ❌ Gemini API: Connection failed"
                    fi
                fi
                
                echo ""
                read -p "Press Enter to continue..."
                ;;
            12) test_all_connections ;;
            13) 
                echo "📝 Checking .env configuration..."
                if check_env_populated; then
                    echo "✅ .env file is properly configured"
                else
                    echo "❌ .env file needs configuration"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            14) cleanup_database_interactive ;;
            15) full_cleanup ;;
            16) 
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --force              Force regeneration of all files"
                echo "  --skip-setup         Skip the setup.sh execution"
                echo "  --skip-cleanup       Skip cleanup of node_modules"
                echo "  --enable-chatbot     Automatically enable chatbot setup"
                echo "  --populate-env       Show .env configuration instructions"
                echo "  --check-env          Check if .env file is properly configured"
                echo "  --stop-chatbot       Stop running chatbot processes"
                echo "  --cleanup-only       Remove node_modules and exit"
                echo "  --non-interactive    Run in non-interactive mode (original behavior)"
                echo "  --help, -h           Show this help message"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            17) 
                echo "👋 Goodbye!"
                exit 0
                ;;
            *) 
                echo "Invalid choice. Please enter a number between 1-17."
                sleep 2
                ;;
        esac
    done
}

# Original workflow function (for non-interactive mode)
run_original_workflow() {
    # Setup domain folder first to get correct DATA_DIR paths
    setup_domain_folder
    
    # Now migrate old files with correct domain-specific paths
    [[ -f "product_generator.log" && ! -f "$LOG_FILE" ]] && mv "product_generator.log" "$LOG_FILE" 2>/dev/null || true
    [[ -f ".setup_completed" && ! -f "$SETUP_MARKER_FILE" ]] && mv ".setup_completed" "$SETUP_MARKER_FILE" 2>/dev/null || true
    
    install_nodejs
    install_php
    install_mysql
    
    if [[ "$SKIP_SETUP" != "true" ]]; then
        handle_setup_check
    fi
    setup_postgresql
    
    database_setup_success=false
    if handle_database_setup "$DOMAIN"; then
        database_setup_success=true
        update_search_php "$FOLDER_LOCATION"
    fi
    
    if handle_generation_workflow "$FOLDER_LOCATION"; then
        echo "Generation workflow completed successfully"
        
        if [[ "$database_setup_success" == "true" ]]; then
            echo "Importing product data to database..."
            import_product_data "$DOMAIN"
            echo "Database import completed"
        fi
        
        # Setup chatbot based on flag or user choice
        if [[ "$ENABLE_CHATBOT" == "true" ]]; then
            log_message "INFO" "Setting up chatbot integration (forced by --enable-chatbot flag)..."
            
            # Check .env file before proceeding
            if ! check_env_populated; then
                echo "📝 .env file needs to be manually configured before chatbot setup."
                echo "Please edit ecommerce_chatbot/.env and fill in all required values."
                echo "After configuration, run the script again to setup the chatbot."
                log_message "ERROR" ".env file not configured. Skipping chatbot setup."
            else
                setup_chatbot_complete "$FOLDER_LOCATION"
            fi
        else
            echo ""
            read -p "Do you want to setup the chatbot integration? (Y/n): " setup_chatbot_choice
            setup_chatbot_choice=${setup_chatbot_choice:-Y}  # Default to Y
            if [[ $setup_chatbot_choice =~ ^[Yy]$ ]]; then
                log_message "INFO" "Setting up chatbot integration..."
                
                # Check .env file before proceeding
                if ! check_env_populated; then
                    echo "📝 .env file needs to be manually configured before chatbot setup."
                    echo "Please edit ecommerce_chatbot/.env and fill in all required values."
                    echo "After configuration, run the script again to setup the chatbot."
                    log_message "ERROR" ".env file not configured. Skipping chatbot setup."
                else
                    setup_chatbot_complete "$FOLDER_LOCATION"
                fi
            else
                log_message "INFO" "Skipping chatbot setup"
            fi
        fi
        
        echo "Complete! Domain: $DOMAIN, Location: $FOLDER_LOCATION"
        [[ -n "$DB_NAME" ]] && echo "Database: $DB_NAME"
        
        # Show chatbot status
        if [ -f "$SCRIPT_DIR/ecommerce_chatbot/chatbot_config.txt" ]; then
            echo "Chatbot API: $(cat "$SCRIPT_DIR/ecommerce_chatbot/chatbot_config.txt")"
            echo "🤖 Chatbot is running in the background"
        fi
        if [ -f "$SCRIPT_DIR/ecommerce_chatbot/flask_app.pid" ]; then
            local flask_pid=$(cat "$SCRIPT_DIR/ecommerce_chatbot/flask_app.pid")
            if kill -0 $flask_pid 2>/dev/null; then
                echo "Flask App PID: $flask_pid (running)"
            else
                echo "Flask App PID: $flask_pid (not running)"
            fi
        fi
        
        # Disable strict error checking for cleanup
        set +e
        echo "Starting cleanup process..."
        if [[ "$SKIP_CLEANUP" != "true" ]]; then
            if [[ -d "node_modules" ]]; then
                echo "Removing local node_modules..."
                rm -rf node_modules 2>/dev/null
            fi
            if [[ -n "$FOLDER_LOCATION" && -d "$FOLDER_LOCATION/node_modules" ]]; then
                echo "Removing target node_modules..."
                rm -rf "$FOLDER_LOCATION/node_modules" 2>/dev/null
            fi
        fi
        echo "Cleanup completed"
        set -e
    fi
    
    echo "Script execution completed successfully"
}

# Cleanup function for chatbot
cleanup_chatbot() {
    log_message "INFO" "Cleaning up chatbot processes..."
    # Kill Flask app if running
    if [ -f "$SCRIPT_DIR/ecommerce_chatbot/flask_app.pid" ]; then
        local pid=$(cat "$SCRIPT_DIR/ecommerce_chatbot/flask_app.pid")
        if kill -0 $pid 2>/dev/null; then
            kill -9 $pid 2>/dev/null || true
            log_message "INFO" "Flask app stopped (PID: $pid)"
        fi
        rm -f "$SCRIPT_DIR/ecommerce_chatbot/flask_app.pid"
    fi
    
    # Also kill any python app.py processes
    pkill -9 -f "python.*app.py" 2>/dev/null || true
}

# Set up error handling
trap 'echo "Error at line $LINENO in function ${FUNCNAME[1]:-main}"; cleanup_chatbot' ERR
# Don't cleanup chatbot on normal exit - let it run
# trap 'cleanup_chatbot' EXIT

# Run main function and handle any errors
if main "$@"; then
    echo "Script completed successfully"
    exit 0
else
    echo "Script failed with error code $?"
    exit 1
fi