#!/bin/bash

# Database connection details
DB_NAME="products_db"
DB_USER="products_user"
DB_PASSWORD="products_2@"
CSV_FILE="data/products_database.csv"

# Check if CSV file exists
if [ ! -f "$CSV_FILE" ]; then
    echo "Error: CSV file not found at $CSV_FILE"
    exit 1
fi

# Export password for psql
export PGPASSWORD="$DB_PASSWORD"

# Use psql with \copy command
psql -h localhost -U "$DB_USER" -d "$DB_NAME" << EOF
-- First truncate the table if it exists
TRUNCATE TABLE products RESTART IDENTITY;

-- Copy data using \copy
\copy products(title, price, product_link, category, image_url) FROM '$CSV_FILE' WITH (FORMAT CSV, HEADER true, DELIMITER ',', QUOTE '"');
EOF

# Check if import was successful
if [ $? -eq 0 ]; then
    echo "CSV data imported successfully into $DB_NAME"
    echo "Imported records:"
    psql -h localhost -U "$DB_USER" -d "$DB_NAME" -c "SELECT COUNT(*) FROM products;"
else
    echo "Error importing CSV data"
fi

# Clean up
unset PGPASSWORD
