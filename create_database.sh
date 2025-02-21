#!/bin/bash

# Set variables
DB_NAME="products_db"
DB_USER="products_user"
DB_PASSWORD="products_2@"

# Switch to the postgres user and run the SQL commands
sudo -u postgres psql <<EOF
CREATE DATABASE $DB_NAME;
CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
\c $DB_NAME
GRANT ALL ON SCHEMA public TO $DB_USER;
ALTER USER $DB_USER WITH SUPERUSER;
EOF

echo "Database '$DB_NAME' and user '$DB_USER' created successfully."
