#!/bin/bash

# Database connection details
DB_NAME="products_db"
DB_USER="products_user"
DB_PASSWORD="products_2@"

# Export password for psql
export PGPASSWORD="$DB_PASSWORD"

# SQL commands to check table structure and data
psql -h localhost -U $DB_USER -d $DB_NAME << EOF
-- Show table structure
\d products;

-- Show first 5 rows of data
SELECT * FROM products LIMIT 5;

-- Show total count of records
SELECT COUNT(*) as total_records FROM products;
EOF

# Clean up
unset PGPASSWORD
