#!/bin/bash

# Product Page Generator - Consolidated Minimal Version
# This script combines all functionality from run.sh and all module files
set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#=============================================================================
# CONFIG MODULE - Configuration and global variables
#=============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Data directory for storing logs and credentials
DATA_DIR="./data"

# File paths (now in data directory)
LOG_FILE="$DATA_DIR/product_generator.log"
SETUP_MARKER_FILE="$DATA_DIR/.setup_completed"

# Function to get domain-specific credentials file
get_credentials_file() {
    local domain=$1
    if [[ -n "$domain" ]]; then
        echo "$DATA_DIR/${domain}_database_credentials.conf"
    else
        echo "$DATA_DIR/database_credentials.conf"
    fi
}

# Legacy credentials file (for backward compatibility)
CREDENTIALS_FILE="$DATA_DIR/database_credentials.conf"

# Global variables
DOMAIN=""
FOLDER_LOCATION=""
DB_NAME=""
DB_USER=""
DB_PASSWORD=""
FORCE_MODE=${FORCE_MODE:-false}
SKIP_SETUP=${SKIP_SETUP:-false}

# Create data directory if it doesn't exist
mkdir -p "$DATA_DIR"

# Cleanup function for node_modules
cleanup_node_modules() {
    if [[ -d "node_modules" ]]; then
        echo -e "${YELLOW}Cleaning up node_modules directory...${NC}"
        rm -rf node_modules
        echo -e "${GREEN}✓ node_modules cleaned up${NC}"
    fi
}

#=============================================================================
# LOGGING MODULE - Logging functionality
#=============================================================================

# Function to log messages with IST timestamp
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(TZ='Asia/Kolkata' date '+%Y-%m-%d %H:%M:%S IST')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    # Also display to console with colors
    case $level in
        "INFO")
            echo -e "${BLUE}[$timestamp] [INFO] $message${NC}"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[$timestamp] [SUCCESS] $message${NC}"
            ;;
        "WARNING")
            echo -e "${YELLOW}[$timestamp] [WARNING] $message${NC}"
            ;;
        "ERROR")
            echo -e "${RED}[$timestamp] [ERROR] $message${NC}"
            ;;
        *)
            echo -e "[$timestamp] [$level] $message"
            ;;
    esac
}

#=============================================================================
# VALIDATE ENVIRONMENT MODULE - Environment validation
#=============================================================================

# Function to validate script environment
validate_script_environment() {
    log_message "INFO" "Validating script environment"
    
    # Check if required files exist
    local required_files=("products.csv" "product.ejs" "gulpfile.js" "package.json")
    local missing_files=()
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        log_message "ERROR" "Missing required files: ${missing_files[*]}"
        echo -e "${RED}Error: Missing required files: ${missing_files[*]}${NC}"
        exit 1
    fi
    
    log_message "SUCCESS" "Environment validation completed"
    echo -e "${GREEN}✓ Environment validation completed${NC}"
}

#=============================================================================
# CHECK SETUP COMPLETION MODULE - Setup completion checking
#=============================================================================

# Function to check if setup.sh was run previously
check_setup_completion() {
    if [[ -f "$SETUP_MARKER_FILE" ]]; then
        log_message "INFO" "Setup marker file found - setup.sh was run previously"
        return 0  # Setup was completed
    else
        log_message "WARNING" "Setup marker file not found - setup.sh may not have been run"
        return 1  # Setup not completed
    fi
}

# Function to run setup.sh
run_setup_script() {
    # Look for setup.sh in current directory first, then modules
    local setup_script=""
    if [[ -f "./setup.sh" ]]; then
        setup_script="./setup.sh"
    elif [[ -f "$SCRIPT_DIR/modules/setup.sh" ]]; then
        setup_script="$SCRIPT_DIR/modules/setup.sh"
    elif [[ -f "$SCRIPT_DIR/setup.sh" ]]; then
        setup_script="$SCRIPT_DIR/setup.sh"
    fi
    
    if [[ -f "$setup_script" ]]; then
        log_message "INFO" "Running setup.sh script..."
        echo -e "\n${BLUE}=== Running Website Setup ===${NC}"
        
        # Make setup.sh executable
        chmod +x "$setup_script"
        
        # Run setup.sh
        if sudo "$setup_script"; then
            # Create setup completion marker
            touch "$SETUP_MARKER_FILE"
            log_message "SUCCESS" "setup.sh completed successfully - marker file created"
            echo -e "${GREEN}✓ Website setup completed successfully${NC}"
        else
            log_message "ERROR" "setup.sh failed to complete"
            echo -e "${RED}✗ Website setup failed${NC}"
            exit 1
        fi
    else
        log_message "ERROR" "setup.sh file not found"
        echo -e "${RED}Error: setup.sh file not found${NC}"
        echo "Please ensure setup.sh is in the current directory or modules directory"
        exit 1
    fi
}

# Function to handle setup check
handle_setup_check() {
    if ! check_setup_completion; then
        echo -e "\n${YELLOW}=== Website Setup Check ===${NC}"
        echo -e "${YELLOW}It appears that setup.sh has not been run previously.${NC}"
        echo "setup.sh configures Apache virtual hosts, directories, and .htaccess files."
        echo
        echo "Do you want to run setup.sh now? This will:"
        echo "  • Configure Apache virtual host for your domain"
        echo "  • Create necessary directories (/public/products, /public/images)"
        echo "  • Set up .htaccess files for URL rewriting"
        echo "  • Enable the Apache site configuration"
        echo
        
        while true; do
            read -p "Run setup.sh? (y/n): " setup_choice
            case $setup_choice in
                [Yy]* )
                    log_message "INFO" "User chose to run setup.sh"
                    run_setup_script
                    break
                    ;;
                [Nn]* )
                    log_message "WARNING" "User chose to skip setup.sh"
                    echo -e "${YELLOW}⚠ Skipping setup.sh - make sure your web server is configured properly${NC}"
                    echo "You can run setup.sh later if needed."
                    break
                    ;;
                * )
                    echo "Please answer yes (y) or no (n)."
                    ;;
            esac
        done
    else
        log_message "INFO" "Setup completion verified - proceeding with generation"
        echo -e "${GREEN}✓ Website setup was completed previously${NC}"
    fi
}

#=============================================================================
# POSTGRESQL MODULE - PostgreSQL installation and setup
#=============================================================================

# Function to check if PostgreSQL is installed
check_postgresql_installed() {
    if command -v psql >/dev/null 2>&1 && command -v pg_config >/dev/null 2>&1; then
        return 0  # PostgreSQL is installed
    else
        return 1  # PostgreSQL is not installed
    fi
}

# Function to install PostgreSQL
install_postgresql() {
    log_message "INFO" "Starting PostgreSQL installation"
    echo -e "\n${BLUE}=== PostgreSQL Installation ===${NC}"
    echo -e "${YELLOW}PostgreSQL is not installed. Installing now...${NC}"
    
    # Detect the operating system
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        log_message "ERROR" "Cannot detect operating system"
        echo -e "${RED}Cannot detect operating system. Please install PostgreSQL manually.${NC}"
        exit 1
    fi
    
    log_message "INFO" "Detected operating system: $OS"
    case $OS in
        ubuntu|debian)
            log_message "INFO" "Installing PostgreSQL on Ubuntu/Debian system"
            echo -e "${BLUE}Detected Ubuntu/Debian system. Installing PostgreSQL...${NC}"
            
            # Update package list
            echo -e "${BLUE}Updating package list...${NC}"
            sudo apt update
            
            # Install PostgreSQL and contrib package
            echo -e "${BLUE}Installing PostgreSQL and PHP extension...${NC}"
            sudo apt install -y postgresql postgresql-contrib php-pgsql
            
            # Start and enable PostgreSQL service
            echo -e "${BLUE}Starting PostgreSQL service...${NC}"
            sudo systemctl start postgresql
            sudo systemctl enable postgresql
            
            log_message "SUCCESS" "PostgreSQL installed successfully on Ubuntu/Debian"
            echo -e "${GREEN}✓ PostgreSQL installed successfully${NC}"
            ;;
            
        centos|rhel|fedora)
            log_message "INFO" "Installing PostgreSQL on CentOS/RHEL/Fedora system"
            echo -e "${BLUE}Detected CentOS/RHEL/Fedora system. Installing PostgreSQL...${NC}"
            
            if command -v dnf >/dev/null 2>&1; then
                # Fedora or newer CentOS/RHEL with dnf
                sudo dnf update -y
                sudo dnf install -y postgresql postgresql-server postgresql-contrib
            elif command -v yum >/dev/null 2>&1; then
                # Older CentOS/RHEL with yum
                sudo yum update -y
                sudo yum install -y postgresql postgresql-server postgresql-contrib
            else
                log_message "ERROR" "Package manager not found on CentOS/RHEL/Fedora"
                echo -e "${RED}Package manager not found. Please install PostgreSQL manually.${NC}"
                exit 1
            fi
            
            # Initialize database (required for CentOS/RHEL)
            echo -e "${BLUE}Initializing PostgreSQL database...${NC}"
            sudo postgresql-setup initdb
            
            # Start and enable PostgreSQL service
            echo -e "${BLUE}Starting PostgreSQL service...${NC}"
            sudo systemctl start postgresql
            sudo systemctl enable postgresql
            
            log_message "SUCCESS" "PostgreSQL installed successfully on CentOS/RHEL/Fedora"
            echo -e "${GREEN}✓ PostgreSQL installed successfully${NC}"
            ;;
            
        arch|manjaro)
            log_message "INFO" "Installing PostgreSQL on Arch/Manjaro system"
            echo -e "${BLUE}Detected Arch/Manjaro system. Installing PostgreSQL...${NC}"
            
            # Update package database
            sudo pacman -Sy
            
            # Install PostgreSQL
            sudo pacman -S --noconfirm postgresql
            
            # Initialize database
            echo -e "${BLUE}Initializing PostgreSQL database...${NC}"
            sudo -u postgres initdb -D /var/lib/postgres/data
            
            # Start and enable PostgreSQL service
            echo -e "${BLUE}Starting PostgreSQL service...${NC}"
            sudo systemctl start postgresql
            sudo systemctl enable postgresql
            
            log_message "SUCCESS" "PostgreSQL installed successfully on Arch/Manjaro"
            echo -e "${GREEN}✓ PostgreSQL installed successfully${NC}"
            ;;
            
        *)
            log_message "ERROR" "Unsupported operating system: $OS"
            echo -e "${RED}Unsupported operating system: $OS${NC}"
            echo -e "${YELLOW}Please install PostgreSQL manually using your system's package manager:${NC}"
            echo "  - Ubuntu/Debian: sudo apt install postgresql postgresql-contrib"
            echo "  - CentOS/RHEL: sudo yum install postgresql postgresql-server postgresql-contrib"
            echo "  - Fedora: sudo dnf install postgresql postgresql-server postgresql-contrib"
            echo "  - Arch: sudo pacman -S postgresql"
            exit 1
            ;;
    esac
    
    # Verify installation
    log_message "INFO" "Verifying PostgreSQL installation"
    echo -e "\n${BLUE}Verifying PostgreSQL installation...${NC}"
    if check_postgresql_installed; then
        log_message "SUCCESS" "PostgreSQL installation verified"
        echo -e "${GREEN}✓ PostgreSQL installation verified${NC}"
        
        # Check service status
        if sudo systemctl is-active --quiet postgresql; then
            log_message "SUCCESS" "PostgreSQL service is running"
            echo -e "${GREEN}✓ PostgreSQL service is running${NC}"
        else
            log_message "WARNING" "PostgreSQL service is not running - attempting to start"
            echo -e "${YELLOW}⚠ PostgreSQL service is not running. Attempting to start...${NC}"
            sudo systemctl start postgresql
            if sudo systemctl is-active --quiet postgresql; then
                log_message "SUCCESS" "PostgreSQL service started successfully"
                echo -e "${GREEN}✓ PostgreSQL service started successfully${NC}"
            else
                log_message "ERROR" "Failed to start PostgreSQL service"
                echo -e "${RED}✗ Failed to start PostgreSQL service${NC}"
                echo -e "${YELLOW}Please check the service status manually: sudo systemctl status postgresql${NC}"
            fi
        fi
        
        # Display PostgreSQL version
        pg_version=$(sudo -u postgres psql -c "SELECT version();" 2>/dev/null | grep PostgreSQL | head -1)
        if [[ -n "$pg_version" ]]; then
            log_message "INFO" "PostgreSQL version: $pg_version"
            echo -e "${BLUE}Installed version: ${pg_version}${NC}"
        fi
        
    else
        log_message "ERROR" "PostgreSQL installation verification failed"
        echo -e "${RED}✗ PostgreSQL installation verification failed${NC}"
        echo -e "${YELLOW}Please check the installation manually${NC}"
        exit 1
    fi
}

# Function to setup PostgreSQL
setup_postgresql() {
    log_message "INFO" "Checking PostgreSQL installation"
    echo -e "\n${BLUE}=== Checking PostgreSQL Installation ===${NC}"
    if check_postgresql_installed; then
        log_message "SUCCESS" "PostgreSQL is already installed"
        echo -e "${GREEN}✓ PostgreSQL is already installed${NC}"
        
        # Check if service is running
        if sudo systemctl is-active --quiet postgresql; then
            log_message "SUCCESS" "PostgreSQL service is running"
            echo -e "${GREEN}✓ PostgreSQL service is running${NC}"
        else
            log_message "WARNING" "PostgreSQL service is not running - attempting to start"
            echo -e "${YELLOW}⚠ PostgreSQL service is not running. Starting it...${NC}"
            sudo systemctl start postgresql
            if sudo systemctl is-active --quiet postgresql; then
                log_message "SUCCESS" "PostgreSQL service started successfully"
                echo -e "${GREEN}✓ PostgreSQL service started${NC}"
            else
                log_message "ERROR" "Failed to start PostgreSQL service"
                echo -e "${RED}✗ Failed to start PostgreSQL service${NC}"
                echo -e "${YELLOW}Please check: sudo systemctl status postgresql${NC}"
            fi
        fi
    else
        log_message "WARNING" "PostgreSQL is not installed - starting installation"
        install_postgresql
    fi
}

#=============================================================================
# DATABASE MODULE - Database management functions
#=============================================================================

# Sanitize domain name for database naming
sanitize_db_name() {
    local domain=$1
    echo "${domain//[.-]/_}" | tr '[:upper:]' '[:lower:]'
}

# Generate secure password (simplified format)
generate_password() {
    local domain=$1
    echo "$(sanitize_db_name $domain)_2@"
}

# Check if database exists for domain
check_database_exists() {
    local domain=$1
    local credentials_file=$(get_credentials_file "$domain")
    
    if [[ -f "$credentials_file" ]]; then
        if grep -q "Domain: $domain" "$credentials_file"; then
            return 0  # Database exists
        fi
    fi
    return 1  # Database doesn't exist
}

# Get database credentials for domain
get_database_credentials() {
    local domain=$1
    local credentials_file=$(get_credentials_file "$domain")
    
    if [[ -f "$credentials_file" ]]; then
        # Since each file contains only one domain, extract credentials directly
        export DB_NAME=$(grep "Database:" "$credentials_file" | cut -d' ' -f2)
        export DB_USER=$(grep "Username:" "$credentials_file" | cut -d' ' -f2)
        export DB_PASSWORD=$(grep "Password:" "$credentials_file" | cut -d' ' -f2)
        
        if [[ -n "$DB_NAME" && -n "$DB_USER" && -n "$DB_PASSWORD" ]]; then
            return 0
        fi
    fi
    return 1
}

# Remove existing credentials for a domain (delete domain-specific file)
remove_domain_credentials() {
    local domain=$1
    local credentials_file=$(get_credentials_file "$domain")
    
    if [[ -f "$credentials_file" ]]; then
        log_message "INFO" "Removing credentials file for domain: $domain"
        rm -f "$credentials_file"
        log_message "SUCCESS" "Removed credentials file: $credentials_file"
        echo -e "${GREEN}✓ Removed credentials for domain: $domain${NC}"
    else
        log_message "INFO" "No credentials file found for domain: $domain"
        echo -e "${YELLOW}No credentials file found for domain: $domain${NC}"
    fi
}

# List all domains that have credential files
list_domains_in_credentials() {
    local domains=()
    
    # Find all domain-specific credential files in data directory
    for file in "$DATA_DIR"/*_database_credentials.conf; do
        if [[ -f "$file" ]]; then
            # Extract domain name from filename
            local filename=$(basename "$file")
            local domain="${filename%_database_credentials.conf}"
            domains+=("$domain")
        fi
    done
    
    # Also check legacy credentials file for backward compatibility
    if [[ -f "$CREDENTIALS_FILE" ]]; then
        while IFS= read -r line; do
            if [[ "$line" =~ ^Domain:\ (.+)$ ]]; then
                local legacy_domain="${BASH_REMATCH[1]}"
                # Only add if not already in domains array
                if [[ ! " ${domains[@]} " =~ " ${legacy_domain} " ]]; then
                    domains+=("$legacy_domain")
                fi
            fi
        done < "$CREDENTIALS_FILE"
    fi
    
    printf '%s\n' "${domains[@]}"
}

# Clean up stale credential files for non-existent databases
cleanup_stale_credentials() {
    log_message "INFO" "Cleaning up stale database credentials"
    echo -e "${BLUE}Checking for stale database credentials...${NC}"
    
    local domains=($(list_domains_in_credentials))
    local cleaned_count=0
    
    for domain in "${domains[@]}"; do
        if get_database_credentials "$domain"; then
            # Test if database actually exists
            if ! PGPASSWORD="$DB_PASSWORD" psql -h localhost -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" >/dev/null 2>&1; then
                log_message "WARNING" "Database for domain '$domain' not accessible, removing credentials file"
                echo -e "${YELLOW}⚠ Removing stale credentials for domain: $domain${NC}"
                remove_domain_credentials "$domain"
                ((cleaned_count++))
            fi
        fi
    done
    
    if [[ $cleaned_count -gt 0 ]]; then
        log_message "SUCCESS" "Cleaned up $cleaned_count stale credential files"
        echo -e "${GREEN}✓ Cleaned up $cleaned_count stale credential files${NC}"
    else
        log_message "INFO" "No stale credentials found"
        echo -e "${GREEN}✓ No stale credentials found${NC}"
    fi
}

# Setup database for domain
setup_database() {
    local domain=$1
    local db_name="$(sanitize_db_name $domain)_db"
    local db_user="$(sanitize_db_name $domain)_user"
    local db_password="$(generate_password $domain)"
    local credentials_file=$(get_credentials_file "$domain")

    log_message "INFO" "Starting database setup for domain: $domain"
    echo -e "\n${YELLOW}=== Database Setup ===${NC}"
    echo -e "${BLUE}Setting up database for domain: $domain${NC}"
    echo "Database name: $db_name"
    echo "Username: $db_user"
    echo "Credentials file: $credentials_file"

    log_message "INFO" "Storing database credentials in domain-specific file: $credentials_file"
    
    # Create/overwrite domain-specific credentials file
    cat > "$credentials_file" <<EOF
Domain: $domain
Database: $db_name
Username: $db_user
Password: $db_password
----------------------------------------
EOF
    chmod 600 "$credentials_file"

    log_message "INFO" "Creating PostgreSQL database and user"
    # Create database, user, and table in single session (like old_run.sh)
    sudo -u postgres psql <<EOF
-- Create database and user
CREATE DATABASE $db_name;
CREATE USER $db_user WITH PASSWORD '$db_password';
GRANT ALL PRIVILEGES ON DATABASE $db_name TO $db_user;
\c $db_name
GRANT ALL ON SCHEMA public TO $db_user;
ALTER USER $db_user WITH SUPERUSER;

-- Create products table
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

-- Create indexes for better search performance
CREATE INDEX IF NOT EXISTS idx_products_title ON products(title);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);
CREATE INDEX IF NOT EXISTS idx_products_title_search ON products USING gin(to_tsvector('english', title));

-- Grant permissions on the table
GRANT ALL PRIVILEGES ON TABLE products TO $db_user;
GRANT USAGE, SELECT ON SEQUENCE products_id_seq TO $db_user;
EOF

    if [ $? -eq 0 ]; then
        log_message "SUCCESS" "Database '$db_name' and user '$db_user' created successfully"
        echo -e "${GREEN}✓ Database '$db_name' and user '$db_user' created successfully${NC}"
        
        # Export for use by other functions
        export DB_NAME="$db_name"
        export DB_USER="$db_user"
        export DB_PASSWORD="$db_password"
        
        return 0
    else
        log_message "ERROR" "Error creating database for domain '$domain'"
        echo -e "${RED}✗ Error creating database for domain '$domain'${NC}"
        return 1
    fi
}

# Cleanup database for domain
cleanup_database() {
    local domain=$1
    local db_name="$(sanitize_db_name $domain)_db"
    local db_user="$(sanitize_db_name $domain)_user"
    
    sudo -u postgres psql -c "DROP DATABASE IF EXISTS $db_name; DROP USER IF EXISTS $db_user;" 2>/dev/null
}

# Import data from CSV into the products table
import_product_data() {
    local domain=$1
    local csv_file=""
    
    # Look for products_database.csv first, then pattern-based files
    if [[ -f "$SCRIPT_DIR/data/products_database.csv" ]]; then
        csv_file="$SCRIPT_DIR/data/products_database.csv"
    else
        # Look for pattern-based database CSV files (e.g., products_01_database.csv)
        # Use find instead of ls to avoid exit code issues with set -e
        local pattern_file=$(find "$SCRIPT_DIR/data/" -name "*_database.csv" -type f 2>/dev/null | head -1)
        if [[ -n "$pattern_file" && -f "$pattern_file" ]]; then
            csv_file="$pattern_file"
        fi
    fi

    # Check if we found a CSV file
    if [[ -z "$csv_file" || ! -f "$csv_file" ]]; then
        log_message "ERROR" "Product data CSV file not found. Looked for: $SCRIPT_DIR/data/products_database.csv and $SCRIPT_DIR/data/*_database.csv"
        echo -e "${RED}✗ Product data CSV file not found${NC}"
        return 1
    fi

    log_message "INFO" "Starting data import for domain: $domain from $csv_file"
    echo -e "\n${BLUE}=== Data Import ===${NC}"
    echo -e "${BLUE}Importing data from $csv_file into database for domain: $domain${NC}"

    # Get credentials
    if ! get_database_credentials "$domain"; then
        log_message "ERROR" "Could not get database credentials for $domain for data import"
        echo -e "${RED}✗ Could not get database credentials for data import${NC}"
        return 1
    fi

    # Use psql to import data from CSV
    # Ensure the CSV header matches the table columns
    PGPASSWORD="$DB_PASSWORD" psql -h localhost -U "$DB_USER" -d "$DB_NAME" -c "\COPY products(title, price, product_link, category, image_url) FROM '$csv_file' DELIMITER ',' CSV HEADER;"

    if [ $? -eq 0 ]; then
        log_message "SUCCESS" "Data imported successfully into products table for domain: $domain"
        echo -e "${GREEN}✓ Data imported successfully into products table${NC}"
        return 0
    else
        log_message "ERROR" "Error importing data into products table for domain: $domain"
        echo -e "${RED}✗ Error importing data into products table${NC}"
        return 1
    fi
}

# Test database connection
test_database_connection() {
    local domain=$1
    
    # Get credentials
    if ! get_database_credentials "$domain"; then
        log_message "ERROR" "Could not get database credentials for $domain"
        return 1
    fi
    
    log_message "INFO" "Testing database connection for domain: $domain"
    
    # Test connection
    PGPASSWORD="$DB_PASSWORD" psql -h localhost -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        log_message "SUCCESS" "Database connection test successful"
        return 0
    else
        log_message "ERROR" "Database connection test failed"
        return 1
    fi
}

# Update search.php with database credentials
update_search_php() {
    local folder_location=$1
    local search_php_source="./search.php"
    local search_php_dest="$folder_location/public/products/search.php"
    
    log_message "INFO" "Updating search.php with database credentials"
    echo -e "\n${BLUE}=== Updating search.php ===${NC}"
    
    if [[ -f "$search_php_source" ]]; then
        # Create destination directory if it doesn't exist
        mkdir -p "$(dirname "$search_php_dest")"
        
        # Copy search.php to destination
        cp "$search_php_source" "$search_php_dest"
        
        # Update PostgreSQL database credentials if available
        if [[ -n "$DB_NAME" && -n "$DB_USER" && -n "$DB_PASSWORD" ]]; then
            # Update PostgreSQL configuration
            sed -i "s/'dbname'   => 'your_db_name'/'dbname'   => '$DB_NAME'/g" "$search_php_dest"
            sed -i "s/'user'    => 'your_user_name'/'user'    => '$DB_USER'/g" "$search_php_dest"
            sed -i "s/'password' => 'your_password'/'password' => '$DB_PASSWORD'/g" "$search_php_dest"
            
            echo -e "${GREEN}✓ PostgreSQL configuration updated in search.php${NC}"
            echo -e "${BLUE}PostgreSQL Database configuration updated with:${NC}"
            echo "  - Database: $DB_NAME"
            echo "  - User: $DB_USER"
            echo "  - Password: [hidden]"
        else
            echo -e "${RED}✗ Could not extract PostgreSQL database credentials for search.php update${NC}"
        fi
        
        # Note: WordPress MySQL credentials need to be configured separately
        echo -e "${YELLOW}⚠ WordPress MySQL configuration in search.php needs manual setup${NC}"
        echo -e "${BLUE}Please update the WordPress MySQL configuration section with:${NC}"
        echo "  - host: your WordPress MySQL host"
        echo "  - dbname: your WordPress database name"
        echo "  - user: your WordPress database user"
        echo "  - password: your WordPress database password"
        echo "  - prefix: your WordPress table prefix (usually 'wp_')"
        
        echo -e "${GREEN}✓ search.php copied to: $search_php_dest${NC}"
    else
        echo -e "${YELLOW}⚠ search.php not found in current directory${NC}"
        echo "  Please ensure search.php is in the same directory as this script"
    fi
}

# Handle database setup workflow
handle_database_setup() {
    local domain=$1
    local credentials_file=$(get_credentials_file "$domain")
    
    log_message "INFO" "Starting database setup check for domain: $domain"
    echo -e "\n${BLUE}=== Database Setup ===${NC}"
    echo -e "${BLUE}Domain: $domain${NC}"
    echo -e "${BLUE}Credentials file: $credentials_file${NC}"
    
    if check_database_exists "$domain"; then
        log_message "SUCCESS" "Database credentials found for domain: $domain"
        echo -e "${GREEN}✓ Database credentials found for domain: $domain${NC}"
        echo "Database credentials found in $credentials_file"
        
        # Load existing credentials
        get_database_credentials "$domain"
        
        # Test connection
        if test_database_connection "$domain"; then
            log_message "SUCCESS" "Database connection test successful"
            echo -e "${GREEN}✓ Database connection working properly${NC}"
            return 0
        else
            log_message "WARNING" "Database connection failed - authentication issue detected"
            echo -e "${YELLOW}⚠ Database connection failed - authentication issue detected${NC}"
            echo -e "${BLUE}This usually happens when database exists but password doesn't match${NC}"
            
            if [[ "$FORCE_MODE" == "true" ]]; then
                recreate_db="y"
            else
                read -p "Do you want to recreate the database with correct credentials? (y/n): " recreate_db
            fi
            
            if [[ $recreate_db =~ ^[Yy]$ ]]; then
                log_message "INFO" "User chose to recreate database"
                echo -e "${BLUE}Cleaning up and recreating database...${NC}"
if cleanup_database "$domain" && setup_database "$domain"; then
                    log_message "SUCCESS" "Database recreated successfully"
                    echo -e "${GREEN}✓ Database recreated successfully${NC}"
                    return 0
                else
                    log_message "ERROR" "Failed to recreate database"
                    echo -e "${RED}✗ Failed to recreate database${NC}"
                    return 1
                fi
            else
                log_message "WARNING" "User chose to continue with broken database"
                echo -e "${YELLOW}Continuing with existing database (may cause issues)${NC}"
                return 1
            fi
        fi
    else
        log_message "WARNING" "Database not found for domain: $domain"
        echo -e "${YELLOW}Database not found for domain: $domain${NC}"
        
        if [[ "$FORCE_MODE" == "true" ]]; then
            log_message "INFO" "Force mode enabled - creating database automatically"
            echo -e "${BLUE}Force mode enabled - creating database...${NC}"
            create_db="y"
        else
            read -p "Do you want to create a database for search functionality? (y/n): " create_db
        fi
        
        if [[ $create_db =~ ^[Yy]$ ]]; then
            log_message "INFO" "User chose to create database"
            if setup_database "$domain"; then
                log_message "SUCCESS" "Database setup completed successfully"
                echo -e "${GREEN}✓ Database setup completed successfully${NC}"
                return 0
            else
                log_message "ERROR" "Database setup failed"
                echo -e "${RED}✗ Database setup failed${NC}"
                
                if [[ "$FORCE_MODE" != "true" ]]; then
                    read -p "Continue without database? (y/n): " continue_without_db
                    if [[ ! $continue_without_db =~ ^[Yy]$ ]]; then
                        log_message "INFO" "User chose to exit due to database setup failure"
                        return 1
                    else
                        log_message "WARNING" "User chose to continue without database"
                    fi
                fi
                return 1
            fi
        else
            log_message "WARNING" "User chose to skip database setup"
            echo -e "${YELLOW}Skipping database setup. HTML generation will continue without database integration.${NC}"
            return 1
        fi
    fi
}

#=============================================================================
# DOMAIN MANAGER MODULE - Domain folder management
#=============================================================================

# Function to search for domain folders in /var/www/
search_domain_folders() {
    local www_dir="/var/www"
    local folders=()
    
    if [[ -d "$www_dir" ]]; then
        echo -e "${BLUE}Searching for domain folders in $www_dir...${NC}"
        
        # Find directories that look like domains (contain dots and are not system folders)
        while IFS= read -r -d '' folder; do
            local basename_folder=$(basename "$folder")
            # Check if folder name contains a dot and is not a system folder
            if [[ "$basename_folder" == *.* ]] && [[ "$basename_folder" != "html" ]] && [[ "$basename_folder" != "." ]] && [[ "$basename_folder" != ".." ]]; then
                # Additional check: make sure it's a directory and readable
                if [[ -d "$folder" ]] && [[ -r "$folder" ]]; then
                    folders+=("$folder")
                fi
            fi
        done < <(find "$www_dir" -maxdepth 1 -type d -print0 2>/dev/null)
        
        # Sort folders alphabetically
        IFS=$'\n' folders=($(sort <<<"${folders[*]}"))
        unset IFS
        
        if [[ ${#folders[@]} -gt 0 ]]; then
            echo -e "${GREEN}Found ${#folders[@]} domain folder(s):${NC}"
            echo
            
            # Display options
            for i in "${!folders[@]}"; do
                local folder_name=$(basename "${folders[$i]}")
                echo "  $((i+1)). ${folders[$i]} (domain: $folder_name)"
            done
            echo "  $((${#folders[@]}+1)). Enter custom path"
            echo
            
            while true; do
                read -p "Select an option (1-$((${#folders[@]}+1))): " choice
                
                if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le $((${#folders[@]}+1)) ]]; then
                    if [[ "$choice" -eq $((${#folders[@]}+1)) ]]; then
                        # Custom path option
                        read -p "Please provide the folder location (e.g., /var/www/yourwebsite.com): " FOLDER_LOCATION
                        break
                    else
                        # Selected from list
                        FOLDER_LOCATION="${folders[$((choice-1))]}"
                        echo -e "${GREEN}Selected: $FOLDER_LOCATION${NC}"
                        break
                    fi
                else
                    echo -e "${RED}Invalid choice. Please select a number between 1 and $((${#folders[@]}+1)).${NC}"
                fi
            done
        else
            echo -e "${YELLOW}No domain folders found in $www_dir${NC}"
            echo "Looking for folders with domain-like names (containing dots)..."
            read -p "Please provide the folder location (e.g., /var/www/yourwebsite.com): " FOLDER_LOCATION
        fi
    else
        echo -e "${YELLOW}Directory $www_dir does not exist.${NC}"
        read -p "Please provide the folder location (e.g., /var/www/yourwebsite.com): " FOLDER_LOCATION
    fi
}

# Function to setup domain folder
setup_domain_folder() {
    log_message "INFO" "Starting domain folder search"
    search_domain_folders
    
    log_message "INFO" "Selected folder location: $FOLDER_LOCATION"
    
    # Validate folder location input
    if [[ -z "$FOLDER_LOCATION" ]]; then
        log_message "ERROR" "Folder location is empty"
        echo -e "${RED}Error: Folder location cannot be empty.${NC}"
        exit 1
    fi
    
    # Extract domain from folder location for database operations
    export DOMAIN=$(basename "$FOLDER_LOCATION")
    log_message "INFO" "Detected domain: $DOMAIN"
    echo -e "${BLUE}Detected domain: $DOMAIN${NC}"
    
    # Create the folder if it doesn't exist
    if [[ ! -d "$FOLDER_LOCATION" ]]; then
        log_message "INFO" "Creating directory: $FOLDER_LOCATION"
        echo -e "${YELLOW}Creating directory: $FOLDER_LOCATION${NC}"
        sudo mkdir -p "$FOLDER_LOCATION"
        log_message "SUCCESS" "Directory created successfully: $FOLDER_LOCATION"
        echo -e "${GREEN}Directory created successfully.${NC}"
    else
        log_message "INFO" "Directory already exists: $FOLDER_LOCATION"
        echo -e "${GREEN}Directory already exists: $FOLDER_LOCATION${NC}"
    fi
    
    export FOLDER_LOCATION
}

#=============================================================================
# GENERATOR MODULE - HTML generation and workflow management
#=============================================================================

# Function to check if Node.js and npm are installed
check_nodejs_installation() {
    if ! command -v node &> /dev/null; then
        log_message "ERROR" "Node.js is not installed"
        echo -e "${RED}Error: Node.js is not installed${NC}"
        echo -e "${YELLOW}Please install Node.js first:${NC}"
        echo "  Ubuntu/Debian: sudo apt update && sudo apt install -y nodejs npm"
        echo "  CentOS/RHEL: sudo yum install -y nodejs npm"
        echo "  Or visit: https://nodejs.org/"
        return 1
    fi
    
    if ! command -v npm &> /dev/null; then
        log_message "ERROR" "npm is not installed"
        echo -e "${RED}Error: npm is not installed${NC}"
        echo -e "${YELLOW}Please install npm first:${NC}"
        echo "  Ubuntu/Debian: sudo apt install -y npm"
        echo "  CentOS/RHEL: sudo yum install -y npm"
        return 1
    fi
    
    # Check Node.js version
    local node_version=$(node --version 2>/dev/null)
    local npm_version=$(npm --version 2>/dev/null)
    
    log_message "INFO" "Node.js version: $node_version"
    log_message "INFO" "npm version: $npm_version"
    echo -e "${GREEN}✓ Node.js $node_version detected${NC}"
    echo -e "${GREEN}✓ npm $npm_version detected${NC}"
    
    return 0
}

# Function to install dependencies
install_dependencies() {
    log_message "INFO" "Starting dependency installation"
    echo -e "\n${BLUE}=== Installing Dependencies ===${NC}"
    
    # Check if Node.js and npm are installed
    if ! check_nodejs_installation; then
        log_message "ERROR" "Node.js/npm installation check failed"
        echo -e "${RED}Cannot proceed without Node.js and npm${NC}"
        echo -e "${YELLOW}Please install Node.js and npm, then run the script again${NC}"
        exit 1
    fi
    
    # Install root Gulp Node.js dependencies
    echo "Installing Node.js dependencies..."
    if [[ ! -f "package.json" ]]; then
        log_message "ERROR" "package.json not found in current directory"
        echo -e "${RED}Error: package.json not found in current directory.${NC}"
        exit 1
    fi
    
    log_message "INFO" "Running npm install"
    if npm install; then
        log_message "SUCCESS" "Node.js dependencies installed successfully"
        echo -e "${GREEN}✓ Node.js dependencies installed successfully${NC}"
    else
        log_message "ERROR" "npm install failed"
        echo -e "${RED}✗ npm install failed${NC}"
        echo -e "${YELLOW}Please check your npm configuration and try again${NC}"
        exit 1
    fi
}

# Function to validate generation files
validate_generation_files() {
    log_message "INFO" "Checking required files for generation"
    echo -e "\n${BLUE}Checking required files...${NC}"
    
    # Check for CSV files in root directory
    local csv_files=(*.csv)
    if [[ ! -f "${csv_files[0]}" ]]; then
        log_message "ERROR" "No CSV files found in current directory"
        echo -e "${RED}Error: No CSV files found in current directory.${NC}"
        echo -e "${YELLOW}Please ensure you have at least one CSV file in the root directory${NC}"
        exit 1
    fi
    
    # Display found CSV files
    log_message "INFO" "Found CSV files for processing"
    echo -e "${GREEN}✓ Found CSV files:${NC}"
    for csv_file in "${csv_files[@]}"; do
        if [[ -f "$csv_file" ]]; then
            log_message "INFO" "CSV file found: $csv_file"
            echo -e "${GREEN}  - $csv_file${NC}"
        fi
    done
    
    if [[ ! -f "product.ejs" ]]; then
        log_message "ERROR" "product.ejs template not found in current directory"
        echo -e "${RED}Error: product.ejs template not found in current directory.${NC}"
        exit 1
    fi
    log_message "SUCCESS" "product.ejs template found"
    echo -e "${GREEN}✓ product.ejs template found${NC}"
    
    if [[ ! -f "gulpfile.js" ]]; then
        log_message "ERROR" "gulpfile.js not found in current directory"
        echo -e "${RED}Error: gulpfile.js not found in current directory.${NC}"
        exit 1
    fi
    log_message "SUCCESS" "gulpfile.js found"
    echo -e "${GREEN}✓ gulpfile.js found${NC}"
}

# Function to display generation summary
display_generation_summary() {
    local folder_location=$1
    
    log_message "SUCCESS" "Generation process completed successfully"
    echo -e "\n${GREEN}=== Generation Complete ===${NC}"
    echo -e "${BLUE}Generated files are located in:${NC}"
    echo "  - HTML files: $folder_location/public/products/"
    echo "  - Images: $folder_location/public/images/"
    echo "  - Search functionality: $folder_location/public/products/search.php"
    echo "  - Data files: ./data/"
    
    # Display summary of generated files
    if [[ -d "$folder_location/public/products" ]]; then
        html_count=$(find "$folder_location/public/products" -name "*.html" | wc -l)
        log_message "INFO" "Total HTML files generated: $html_count"
        echo -e "${GREEN}✓ Total HTML files generated: $html_count${NC}"
    fi
    
    if [[ -d "$folder_location/public/images" ]]; then
        image_count=$(find "$folder_location/public/images" -type f | wc -l)
        log_message "INFO" "Total images downloaded: $image_count"
        echo -e "${GREEN}✓ Total images downloaded: $image_count${NC}"
    fi
    
    if [[ -f "./data/sitemap.xml" ]] || [[ -f "./data/"*"_sitemap.xml" ]]; then
        log_message "SUCCESS" "Sitemap generated successfully"
        echo -e "${GREEN}✓ Sitemap generated in ./data/${NC}"
    fi
    
    if [[ -f "./data/products_database.csv" ]] || [[ -f "./data/"*"_database.csv" ]]; then
        log_message "SUCCESS" "Products database CSV generated successfully"
        echo -e "${GREEN}✓ Products database CSV generated in ./data/${NC}"
    fi
    
    # Check for database summary
    if [[ -f "./data/"*"_database_summary.txt" ]]; then
        log_message "SUCCESS" "Database operations completed - summary available"
        echo -e "${GREEN}✓ Database operations completed - check ./data/ for summary${NC}"
        # Display database summary if available
        summary_file=$(ls ./data/*_database_summary.txt 2>/dev/null | head -1)
        if [[ -f "$summary_file" ]]; then
            echo -e "\n${BLUE}=== Database Summary ===${NC}"
            cat "$summary_file"
        fi
    fi
}

# Function to handle generation workflow
handle_generation_workflow() {
    local folder_location=$1
    
    log_message "INFO" "Starting HTML generation and database population phase"
    echo -e "\n${BLUE}=== HTML Generation & Database Population ===${NC}"
    
    # Install dependencies first
    install_dependencies
    
    # Gulp CSV to HTML conversion
    echo "This will generate HTML files and populate the database in $folder_location."
    
    # Ask user for generation mode
    echo -e "\n${YELLOW}Choose generation mode:${NC}"
    echo "1. Incremental generation (only process new/changed products)"
    echo "2. Force complete regeneration (process all products + clear database)"
    echo "3. Skip generation"
    read -p "Enter your choice (1/2/3): " generation_choice
    
    local generation_mode
    if [[ "$generation_choice" == "1" ]]; then
        log_message "INFO" "User selected incremental generation mode"
        echo -e "${GREEN}Starting incremental HTML generation and database update...${NC}"
        generation_mode="incremental"
    elif [[ "$generation_choice" == "2" ]]; then
        log_message "INFO" "User selected force complete regeneration mode"
        echo -e "${GREEN}Starting force complete regeneration and database rebuild...${NC}"
        generation_mode="force"
    elif [[ "$generation_choice" == "3" ]]; then
        log_message "INFO" "User selected to skip generation"
        echo -e "${YELLOW}Skipping HTML page generation and database operations.${NC}"
        generation_mode="skip"
    else
        log_message "WARNING" "Invalid choice - defaulting to incremental generation"
        echo -e "${YELLOW}Invalid choice. Defaulting to incremental generation.${NC}"
        generation_mode="incremental"
    fi
    
    if [[ "$generation_mode" != "skip" ]]; then
        # Check if required files exist
        validate_generation_files
        
        log_message "INFO" "Starting gulp generation process with mode: $generation_mode"
        echo -e "\n${BLUE}Starting generation process...${NC}"
        
        # Run gulp with appropriate flags
        if [[ "$generation_mode" == "force" ]]; then
            log_message "INFO" "Running gulp with force flag"
            if ! npx gulp --folderLocation="$folder_location" --force; then
                log_message "ERROR" "Gulp generation with force flag failed"
                echo -e "${RED}✗ Generation process failed${NC}"
                echo -e "${YELLOW}Check if gulpfile.js is properly configured and all dependencies are installed${NC}"
                return 1
            fi
        else
            log_message "INFO" "Running gulp with incremental mode"
            if ! npx gulp --folderLocation="$folder_location"; then
                log_message "ERROR" "Gulp generation in incremental mode failed"
                echo -e "${RED}✗ Generation process failed${NC}"
                echo -e "${YELLOW}Check if gulpfile.js is properly configured and all dependencies are installed${NC}"
                return 1
            fi
        fi
        
        # If we reach here, gulp was successful
        log_message "SUCCESS" "Gulp generation completed successfully"
        display_generation_summary "$folder_location"
        return 0
    else
        log_message "INFO" "User chose to skip generation process"
        echo -e "${YELLOW}Skipping HTML page generation and database operations.${NC}"
        return 0
    fi
}

#=============================================================================
# MAIN SCRIPT FUNCTIONS - Core functionality from run.sh
#=============================================================================

# Install Node.js and npm if missing
install_nodejs() {
    if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
        echo "Installing Node.js and npm..."
        if [[ -f /etc/debian_version ]]; then
            apt update && apt install -y nodejs npm
        elif [[ -f /etc/redhat-release ]]; then
            yum install -y nodejs npm
        fi
    fi
}

# Install PHP with extensions if missing
install_php() {
    if ! command -v php &> /dev/null || ! php -m | grep -q mysqli || ! php -m | grep -q pgsql; then
        echo "Installing PHP and extensions..."
        if [[ -f /etc/debian_version ]]; then
            apt update && apt install -y php php-mysql php-pgsql php-cli
        elif [[ -f /etc/redhat-release ]]; then
            yum install -y php php-mysql php-pgsql php-cli
        fi
    fi
}

# Install MySQL server if missing
install_mysql() {
    if ! systemctl is-active --quiet mysql 2>/dev/null && ! systemctl is-active --quiet mysqld 2>/dev/null; then
        echo "Installing MySQL server..."
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

# Main execution
main() {
    # Handle arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force) export FORCE_MODE=true; shift ;;
            --skip-setup) export SKIP_SETUP=true; shift ;;
            --skip-cleanup) export SKIP_CLEANUP=true; shift ;;
            --cleanup-only)
                [[ -d "node_modules" ]] && rm -rf node_modules
                exit 0 ;;
            --help|-h)
                echo "Usage: $0 [--force] [--skip-setup] [--skip-cleanup] [--cleanup-only] [--help]"
                exit 0 ;;
            *) shift ;;
        esac
    done

    echo "=== Product Page Generator ==="
    
    # Ensure data directory exists and move legacy files if needed
    mkdir -p "$DATA_DIR"
    
    # Move legacy log file to data directory if it exists in root
    if [[ -f "product_generator.log" && ! -f "$LOG_FILE" ]]; then
        echo "Moving product_generator.log to data directory..."
        mv "product_generator.log" "$LOG_FILE"
    fi
    
    # Move legacy setup marker to data directory if it exists in root
    if [[ -f ".setup_completed" && ! -f "$SETUP_MARKER_FILE" ]]; then
        echo "Moving .setup_completed to data directory..."
        mv ".setup_completed" "$SETUP_MARKER_FILE"
    fi
    
    # Install prerequisites
    install_nodejs
    install_php
    install_mysql

    # Validate environment
    validate_script_environment
    
    # Handle setup check
    if [[ "$SKIP_SETUP" != "true" ]]; then
        handle_setup_check
    fi
    
    # Setup domain folder
    setup_domain_folder
    
    # Setup PostgreSQL
    setup_postgresql
    
    # Setup database
    database_setup_success=false
    if handle_database_setup "$DOMAIN"; then
        database_setup_success=true
        update_search_php "$FOLDER_LOCATION"
    fi
    
    # Handle HTML generation
    if handle_generation_workflow "$FOLDER_LOCATION"; then
        # Import data after HTML generation
        if [[ "$database_setup_success" == "true" ]]; then
            import_product_data "$DOMAIN"
        fi
        
        echo "Setup Complete!"
        echo "Domain: $DOMAIN"
        echo "Location: $FOLDER_LOCATION"
        [[ -n "$DB_NAME" ]] && echo "Database: $DB_NAME"
        
        # Cleanup
        if [[ "$SKIP_CLEANUP" != "true" ]]; then
            [[ -d "node_modules" ]] && rm -rf node_modules || true
            [[ -n "$FOLDER_LOCATION" && -d "$FOLDER_LOCATION/node_modules" ]] && rm -rf "$FOLDER_LOCATION/node_modules" || true
        fi
    else
        exit 1
    fi
}

# Error handling
trap 'echo "Error at line $LINENO"' ERR

# Execute
main "$@"