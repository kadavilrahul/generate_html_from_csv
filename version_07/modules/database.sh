#!/bin/bash

# Database management functions

# Sanitize domain name for database naming
sanitize_db_name() {
    local domain=$1
    echo "${domain//[.-]/_}" | tr '[:upper:]' '[:lower:]'
}

# Generate secure password
generate_password() {
    local domain=$1
    echo "$(sanitize_db_name $domain)_$(openssl rand -hex 8)"
}

# Check if database exists for domain
check_database_exists() {
    local domain=$1
    local credentials_file="./database_credentials.conf"
    
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
    local credentials_file="./database_credentials.conf"
    
    if [[ -f "$credentials_file" ]]; then
        # Extract credentials for the specific domain
        local section_start=$(grep -n "Domain: $domain" "$credentials_file" | cut -d: -f1)
        if [[ -n "$section_start" ]]; then
            local section_end=$(tail -n +$((section_start + 1)) "$credentials_file" | grep -n "^Domain:" | head -1 | cut -d: -f1)
            if [[ -n "$section_end" ]]; then
                section_end=$((section_start + section_end))
            else
                section_end=$(wc -l < "$credentials_file")
            fi
            
            # Extract credentials from the section
            local section=$(sed -n "${section_start},${section_end}p" "$credentials_file")
            export DB_NAME=$(echo "$section" | grep "Database:" | cut -d' ' -f2)
            export DB_USER=$(echo "$section" | grep "Username:" | cut -d' ' -f2)
            export DB_PASSWORD=$(echo "$section" | grep "Password:" | cut -d' ' -f2)
            
            return 0
        fi
    fi
    return 1
}

# Setup database for domain (following old_run.sh approach)
setup_database() {
    local domain=$1
    local db_name="$(sanitize_db_name $domain)_db"
    local db_user="$(sanitize_db_name $domain)_user"
    local db_password="$(generate_password $domain)"

    log_message "INFO" "Starting database setup for domain: $domain"
    echo -e "\n${YELLOW}=== Database Setup ===${NC}"
    echo -e "${BLUE}Setting up database for domain: $domain${NC}"
    echo "Database name: $db_name"
    echo "Username: $db_user"

    # Create credentials file if it doesn't exist
    touch ./database_credentials.conf
    chmod 600 ./database_credentials.conf

    log_message "INFO" "Storing database credentials in configuration file"
    # Store credentials in configuration file
    echo "Domain: $domain" >> ./database_credentials.conf
    echo "Database: $db_name" >> ./database_credentials.conf
    echo "Username: $db_user" >> ./database_credentials.conf
    echo "Password: $db_password" >> ./database_credentials.conf
    echo "----------------------------------------" >> ./database_credentials.conf

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
        
        # Update database credentials if available
        if [[ -n "$DB_NAME" && -n "$DB_USER" && -n "$DB_PASSWORD" ]]; then
            sed -i "s/'dbname'   => 'your_db_name'/'dbname'   => '$DB_NAME'/g" "$search_php_dest"
            sed -i "s/'user'    => 'your_user_name'/'user'    => '$DB_USER'/g" "$search_php_dest"
            sed -i "s/'password' => 'your_password'/'password' => '$DB_PASSWORD'/g" "$search_php_dest"
            
            echo -e "${GREEN}✓ search.php updated and copied to: $search_php_dest${NC}"
            echo -e "${BLUE}Database configuration updated with:${NC}"
            echo "  - Database: $DB_NAME"
            echo "  - User: $DB_USER"
            echo "  - Password: [hidden]"
        else
            echo -e "${RED}✗ Could not extract database credentials for search.php update${NC}"
            echo -e "${YELLOW}⚠ search.php copied but database credentials need manual update${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ search.php not found in current directory${NC}"
        echo "  Please ensure search.php is in the same directory as this script"
    fi
}

# Handle database setup workflow (following old_run.sh approach)
handle_database_setup() {
    local domain=$1
    
    log_message "INFO" "Starting database setup check"
    echo -e "\n${BLUE}=== Database Setup ===${NC}"
    
    if check_database_exists "$domain"; then
        log_message "SUCCESS" "Database already exists for domain: $domain"
        echo -e "${GREEN}✓ Database already exists for domain: $domain${NC}"
        echo "Database credentials found in ./database_credentials.conf"
        
        # Load existing credentials
        get_database_credentials "$domain"
        return 0
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