#!/bin/bash

# Set variables
DB_NAME="products_db"
DB_USER="products_user"
DB_PASSWORD="products_2@"

# Switch to the postgres user and run the SQL commands
sudo -u postgres psql <<EOF
-- Create database and user
CREATE DATABASE $DB_NAME;
CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
\c $DB_NAME
GRANT ALL ON SCHEMA public TO $DB_USER;
ALTER USER $DB_USER WITH SUPERUSER;

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
GRANT ALL PRIVILEGES ON TABLE products TO $DB_USER;
GRANT USAGE, SELECT ON SEQUENCE products_id_seq TO $DB_USER;
EOF

echo "Database '$DB_NAME', user '$DB_USER', and table 'products' created successfully."
