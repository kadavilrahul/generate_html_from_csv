#!/bin/bash

# Function to convert domain to valid database name
sanitize_db_name() {
    local domain=$1
    echo "${domain//[.-]/_}" | tr '[:upper:]' '[:lower:]'
}

# Function to get database credentials from config file
get_db_credentials() {
    local domain=$1
    local db_name="$(sanitize_db_name $domain)_db"
    local credentials_file="/etc/website_db_credentials.conf"
    
    if [ ! -f "$credentials_file" ]; then
        echo "Error: Credentials file not found"
        return 1
    fi

    # Read credentials from file
    local db_user=""
    local db_password=""
    local found=false
    while IFS= read -r line; do
        if [[ $line == "Domain: $domain" ]]; then
            found=true
            continue
        fi
        if [ "$found" = true ]; then
            if [[ $line == "Username:"* ]]; then
                db_user=$(echo $line | cut -d' ' -f2)
            elif [[ $line == "Password:"* ]]; then
                db_password=$(echo $line | cut -d' ' -f2)
            elif [[ $line == "----------------------------------------" ]]; then
                break
            fi
        fi
    done < "$credentials_file"

    if [ -z "$db_user" ] || [ -z "$db_password" ]; then
        echo "Error: Credentials not found for domain $domain"
        return 1
    fi

    echo "DB_NAME=$db_name"
    echo "DB_USER=$db_user"
    echo "DB_PASSWORD=$db_password"
}

# Database host configuration
DB_HOST="localhost"
DB_PORT="5432"

# Get current directory name (domain)
CURRENT_DIR=$(basename $(pwd))
if [ -z "$CURRENT_DIR" ]; then
    echo "Error: Cannot determine current directory"
    exit 1
fi

# Get database credentials
eval $(get_db_credentials "$CURRENT_DIR")
if [ $? -ne 0 ]; then
    echo "Error: Failed to get database credentials"
    exit 1
fi

CSV_FILE="data/products_database.csv"

# Check if CSV file exists
if [ ! -f "$CSV_FILE" ]; then
    echo "Error: CSV file not found: $CSV_FILE"
    exit 1
fi

# Set PGPASSWORD environment variable
export PGPASSWORD="$DB_PASSWORD"

echo "Importing CSV data into database: $DB_NAME"
echo "Using credentials for domain: $CURRENT_DIR"

# Add error checking for database operations
if ! psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME << EOF
-- Create temporary table
DROP TABLE IF EXISTS temp_products;
CREATE TABLE temp_products (
    title TEXT,
    price TEXT,
    product_link TEXT,
    category TEXT,
    image_url TEXT
);

-- Copy CSV data into temporary table
\COPY temp_products FROM '$CSV_FILE' WITH CSV HEADER;

-- Insert new records only if they don't exist with price conversion
INSERT INTO products (title, price, product_link, category, image_url)
SELECT 
    t.title, 
    CASE 
        WHEN t.price ~ '^\d+$' THEN t.price::integer
        WHEN t.price ~ '^\d+\.\d+$' THEN t.price::numeric::integer
        ELSE 0
    END as price,
    t.product_link, 
    t.category, 
    t.image_url
FROM temp_products t
LEFT JOIN products p ON t.product_link = p.product_link
WHERE p.product_link IS NULL;

-- Update existing records with price conversion
UPDATE products p
SET 
    title = t.title,
    price = CASE 
        WHEN t.price ~ '^\d+$' THEN t.price::integer
        WHEN t.price ~ '^\d+\.\d+$' THEN t.price::numeric::integer
        ELSE 0
    END,
    category = t.category,
    image_url = t.image_url
FROM temp_products t
WHERE p.product_link = t.product_link;

-- Cleanup
DROP TABLE temp_products;
EOF
then
    echo "Error: Database operation failed"
    exit 1
fi

# Unset PGPASSWORD for security
unset PGPASSWORD

echo "CSV import completed successfully for domain: $CURRENT_DIR"
