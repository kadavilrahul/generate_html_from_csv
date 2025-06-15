#!/bin/bash

# Database management functions

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