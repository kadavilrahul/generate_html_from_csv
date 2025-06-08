#!/bin/bash

# Database configuration
DB_HOST="localhost"
DB_PORT="5432"
DB_NAME="products_db"
DB_USER="products_user"
DB_PASSWORD="products_2@"

# Set PGPASSWORD environment variable
export PGPASSWORD="$DB_PASSWORD"

CSV_FILE="data/products_first_100.csv"

# Check if CSV file exists
if [ ! -f "$CSV_FILE" ]; then
    echo "Error: CSV file not found: $CSV_FILE"
    exit 1
fi

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

echo "CSV import completed successfully"
