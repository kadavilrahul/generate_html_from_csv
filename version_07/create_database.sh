#!/bin/bash

# Function to install required packages for database
install_database_packages() {
    echo "Checking and installing database-related packages..."
    
    # Update package list
    apt-get update
    
    # Install PostgreSQL
    if ! command -v psql &> /dev/null; then
        echo "Installing PostgreSQL..."
        apt-get install -y postgresql postgresql-contrib
        systemctl start postgresql
        systemctl enable postgresql
        echo "PostgreSQL installed and started."
    else
        echo "PostgreSQL is already installed."
    fi
    
    # Install PHP and required extensions
    if ! command -v php &> /dev/null; then
        echo "Installing PHP and extensions..."
        apt-get install -y php php-pgsql php-cli php-common php-curl php-json php-mbstring
        echo "PHP and extensions installed."
    else
        echo "PHP is already installed."
        # Check if php-pgsql is installed
        if ! php -m | grep -q pgsql; then
            echo "Installing PHP PostgreSQL extension..."
            apt-get install -y php-pgsql
        fi
    fi
    
    echo "Database-related packages are installed."
}

# Function to convert domain to valid database name
sanitize_db_name() {
    local domain=$1
    # Replace dots and hyphens with underscores and convert to lowercase
    echo "${domain//[.-]/_}" | tr '[:upper:]' '[:lower:]'
}

# Function to create database for a domain
create_domain_db() {
    local domain=$1
    local db_name="$(sanitize_db_name $domain)_db"
    local db_user="$(sanitize_db_name $domain)_user"
    local db_password="$(sanitize_db_name $domain)_2@"
    local credentials_file="./data/website_db_credentials.conf"

    echo -e "\nCreating database for domain: $domain"
    
    # Ask for confirmation
    read -p "Do you want to create a PostgreSQL database for $domain? (y/n): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo "Skipping database creation for $domain"
        return
    fi

    # Create data directory if it doesn't exist
    mkdir -p ./data

    # Store credentials in the project data folder
    echo "Domain: $domain" >> "$credentials_file"
    echo "Database: $db_name" >> "$credentials_file"
    echo "Username: $db_user" >> "$credentials_file"
    echo "Password: $db_password" >> "$credentials_file"
    echo "----------------------------------------" >> "$credentials_file"

    # Switch to the postgres user and run the SQL commands
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
        image_url TEXT
    );

    -- Grant permissions on the table
    GRANT ALL PRIVILEGES ON TABLE products TO $db_user;
    GRANT USAGE, SELECT ON SEQUENCE products_id_seq TO $db_user;
EOF

    echo "Database '$db_name' and user '$db_user' created successfully for domain '$domain'"
    
    # Return the database details for use in population
    echo "$db_name|$db_user|$db_password"
}

# Function to populate database with CSV data
populate_database() {
    local domain=$1
    local csv_file="./data/products_database.csv"
    local db_name="$(sanitize_db_name $domain)_db"
    local db_user="$(sanitize_db_name $domain)_user"
    local db_password="$(sanitize_db_name $domain)_2@"
    
    echo -e "\nPopulating database with product data..."
    
    # Check if CSV file exists
    if [[ ! -f "$csv_file" ]]; then
        echo "Error: $csv_file not found. Cannot populate database."
        return 1
    fi
    
    # Count lines in CSV (excluding header)
    local total_products=$(($(wc -l < "$csv_file") - 1))
    echo "Found $total_products products to import from $csv_file"
    
    if [[ $total_products -le 0 ]]; then
        echo "No products found in CSV file."
        return 1
    fi
    
    # Read CSV and populate database
    local count=0
    local success_count=0
    local error_count=0
    
    # Skip header line and process each product
    tail -n +2 "$csv_file" | while IFS=',' read -r title price product_link category image_url; do
        count=$((count + 1))
        
        # Clean up the fields (remove quotes if present)
        title=$(echo "$title" | sed 's/^"//;s/"$//')
        price=$(echo "$price" | sed 's/^"//;s/"$//')
        product_link=$(echo "$product_link" | sed 's/^"//;s/"$//')
        category=$(echo "$category" | sed 's/^"//;s/"$//')
        image_url=$(echo "$image_url" | sed 's/^"//;s/"$//')
        
        # Insert into database
        PGPASSWORD="$db_password" psql -h localhost -U "$db_user" -d "$db_name" -c "
            INSERT INTO products (title, price, product_link, category, image_url) 
            VALUES ('$(echo "$title" | sed "s/'/''/g")', '$price', '$product_link', '$(echo "$category" | sed "s/'/''/g")', '$image_url')
        " > /dev/null 2>&1
        
        if [[ $? -eq 0 ]]; then
            success_count=$((success_count + 1))
        else
            error_count=$((error_count + 1))
            echo "Error inserting product: $title"
        fi
        
        # Show progress every 10 products
        if [[ $((count % 10)) -eq 0 ]]; then
            echo "Processed $count/$total_products products..."
        fi
    done
    
    echo "Database population completed!"
    echo "Successfully imported: $success_count products"
    if [[ $error_count -gt 0 ]]; then
        echo "Errors encountered: $error_count products"
    fi
}

# Function to setup search functionality
setup_search_functionality() {
    local folder_location=$1
    local domain=$2
    local search_dest="$folder_location/public/products/search.php"
    
    echo -e "\nSetting up search functionality..."
    
    # Ensure the products directory exists
    mkdir -p "$folder_location/public/products"
    
    # Copy search.php to the public/products directory
    if [[ -f "search.php" ]]; then
        cp "search.php" "$search_dest"
        echo "Copied search.php to $search_dest"
        
        # Update database configuration in search.php
        local db_name="$(sanitize_db_name $domain)_db"
        local db_user="$(sanitize_db_name $domain)_user"
        local db_password="$(sanitize_db_name $domain)_2@"
        
        # Replace database configuration in search.php
        sed -i "s/'dbname'   => 'your_pg_db_name'/'dbname'   => '$db_name'/g" "$search_dest"
        sed -i "s/'user'    => 'your_pg_user_name'/'user'    => '$db_user'/g" "$search_dest"
        sed -i "s/'password' => 'your_pg_password'/'password' => '$db_password'/g" "$search_dest"
        
        echo "Updated database configuration in search.php"
        echo "Search functionality is now available at: https://$domain/products/search.php"
    else
        echo "Warning: search.php not found in current directory. Skipping search setup."
    fi
}

# Main script - Updated to work with run.sh integration
main() {
    local folder_location=$1
    local auto_confirm=${2:-false}
    
    # Extract domain from folder location
    local domain=$(basename "$folder_location")
    
    echo "Setting up database for domain: $domain"
    echo "Folder location: $folder_location"
    
    # Install required packages
    install_required_packages
    
    # Create credentials file if it doesn't exist
    mkdir -p ./data
    touch ./data/website_db_credentials.conf
    chmod 600 ./data/website_db_credentials.conf
    
    # Create database
    local db_details=$(create_domain_db "$domain")
    
    if [[ -n "$db_details" ]]; then
        # Populate database with CSV data
        populate_database "$domain"
        
        # Setup search functionality
        setup_search_functionality "$folder_location" "$domain"
        
        echo -e "\nDatabase setup completed successfully!"
        echo "Credentials saved to: ./data/website_db_credentials.conf"
    else
        echo "Database creation was skipped."
    fi
}

# Legacy main script for standalone execution
legacy_main() {
    WWW_PATH="/var/www"

    # Create credentials file if it doesn't exist
    mkdir -p ./data
    touch ./data/website_db_credentials.conf
    chmod 600 ./data/website_db_credentials.conf

    # Ask for global confirmation
    echo "This script will check for domains in $WWW_PATH and create PostgreSQL databases for them."
    read -p "Do you want to proceed? (y/n): " proceed
    if [[ ! $proceed =~ ^[Yy]$ ]]; then
        echo "Script execution cancelled."
        exit 0
    fi

    # Install required packages
    install_required_packages

    # Iterate through all directories in www path
    echo -e "\nScanning for domains in $WWW_PATH..."
    domains_found=0

    for site_dir in "$WWW_PATH"/*; do
        if [ -d "$site_dir" ]; then
            domains_found=$((domains_found + 1))
            domain=$(basename "$site_dir")
            echo "Found domain: $domain"
        fi
    done

    if [ $domains_found -eq 0 ]; then
        echo "No domains found in $WWW_PATH"
        exit 0
    fi

    echo -e "\nFound $domains_found domain(s)"
    read -p "Would you like to create databases for all domains automatically? (y/n): " auto_create

    if [[ $auto_create =~ ^[Yy]$ ]]; then
        # Automatic creation for all domains
        for site_dir in "$WWW_PATH"/*; do
            if [ -d "$site_dir" ]; then
                domain=$(basename "$site_dir")
                create_domain_db "$domain"
                populate_database "$domain"
                setup_search_functionality "$site_dir" "$domain"
            fi
        done
    else
        # Individual confirmation for each domain
        for site_dir in "$WWW_PATH"/*; do
            if [ -d "$site_dir" ]; then
                domain=$(basename "$site_dir")
                create_domain_db "$domain"
                populate_database "$domain"
                setup_search_functionality "$site_dir" "$domain"
            fi
        done
    fi

    echo -e "\nDatabase creation process completed."
    echo "Credentials have been saved to ./data/website_db_credentials.conf"
}

# Check if script is called with parameters (from run.sh) or standalone
if [[ $# -gt 0 ]]; then
    # Called from run.sh with parameters
    main "$@"
else
    # Standalone execution
    legacy_main
fi
