#!/bin/bash

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

    echo -e "\nCreating database for domain: $domain"
    
    # Ask for confirmation
    read -p "Do you want to create a PostgreSQL database for $domain? (y/n): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo "Skipping database creation for $domain"
        return
    fi

    # Store credentials in a configuration file
    echo "Domain: $domain" >> /etc/website_db_credentials.conf
    echo "Database: $db_name" >> /etc/website_db_credentials.conf
    echo "Username: $db_user" >> /etc/website_db_credentials.conf
    echo "Password: $db_password" >> /etc/website_db_credentials.conf
    echo "----------------------------------------" >> /etc/website_db_credentials.conf

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
}

# Main script
WWW_PATH="/var/www"

# Create credentials file if it doesn't exist
touch /etc/website_db_credentials.conf
chmod 600 /etc/website_db_credentials.conf

# Ask for global confirmation
echo "This script will check for domains in $WWW_PATH and create PostgreSQL databases for them."
read -p "Do you want to proceed? (y/n): " proceed
if [[ ! $proceed =~ ^[Yy]$ ]]; then
    echo "Script execution cancelled."
    exit 0
fi

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
        fi
    done
else
    # Individual confirmation for each domain
    for site_dir in "$WWW_PATH"/*; do
        if [ -d "$site_dir" ]; then
            domain=$(basename "$site_dir")
            create_domain_db "$domain"
        fi
    done
fi

echo -e "\nDatabase creation process completed."
echo "Credentials have been saved to /etc/website_db_credentials.conf"
