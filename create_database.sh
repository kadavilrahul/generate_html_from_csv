#!/bin/bash

# Exit on any error
set -e
trap 'echo "An error occurred. Exiting..."' ERR

echo "Starting database setup..."

# Variables
DB_NAME="products_db"
DB_USER="products_user"
DB_PASSWORD="products_2@"
POSTGRES_PASSWORD="Karimpadam2@"

# Check if the database exists
DB_EXISTS=$(PGPASSWORD=$POSTGRES_PASSWORD psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'")
if [ "$DB_EXISTS" == "1" ]; then
    echo "Database '$DB_NAME' already exists. Skipping creation."
else
    echo "Creating database '$DB_NAME'..."
    PGPASSWORD=$POSTGRES_PASSWORD psql -U postgres -c "CREATE DATABASE $DB_NAME;"
fi

# Check if the user exists
USER_EXISTS=$(PGPASSWORD=$POSTGRES_PASSWORD psql -U postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'")
if [ "$USER_EXISTS" == "1" ]; then
    echo "User '$DB_USER' already exists. Skipping creation."
else
    echo "Creating user '$DB_USER'..."
    PGPASSWORD=$POSTGRES_PASSWORD psql -U postgres -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
    PGPASSWORD=$POSTGRES_PASSWORD psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
fi

# Create the products table
echo "Creating products table..."
PGPASSWORD=$POSTGRES_PASSWORD psql -U postgres -d $DB_NAME << EOF
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    product_link TEXT NOT NULL,
    category TEXT NOT NULL,
    image_url TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $DB_USER;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO $DB_USER;
EOF