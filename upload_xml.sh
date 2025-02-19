#!/bin/bash

# Exit on any error
set -e
trap 'echo "An error occurred. Exiting..."' ERR

echo "Starting Python environment setup and database import process..."

# Define variables
VENV_NAME="venv"
SCRIPT_NAME="import_xml_to_db.py"

# 1. Create and activate Python virtual environment
echo "Creating Python virtual environment..."
python3 -m venv $VENV_NAME
source $VENV_NAME/bin/activate

# 2. Install required package
echo "Installing psycopg2-binary..."
pip3 install psycopg2-binary

# 3. Create the Python script
echo "Creating import_xml_to_db.py..."
cat > $SCRIPT_NAME << 'EOL'
#!/usr/bin/env python3

import xml.etree.ElementTree as ET
import psycopg2
from psycopg2.extras import execute_values
import sys
import os
from datetime import datetime

def connect_to_database():
    """Establish database connection"""
    try:
        conn = psycopg2.connect(
            dbname="products_db",
            user="products_user",
            password="products_2@",
            host="localhost",
            port="5432"
        )
        return conn
    except psycopg2.Error as e:
        print(f"Error connecting to database: {e}")
        sys.exit(1)

def parse_xml_file(xml_path):
    """Parse XML file and return list of products"""
    try:
        tree = ET.parse(xml_path)
        root = tree.getroot()
        products = []

        for product in root.findall('.//product'):
            # Extract data with CDATA handling
            title = product.find('title').text
            price = float(product.find('price').text.replace(',', ''))
            product_link = product.find('product_link').text
            category = product.find('category').text
            image_url = product.find('image_url').text

            products.append({
                'title': title,
                'price': price,
                'product_link': product_link,
                'category': category,
                'image_url': image_url,
                'created_at': datetime.now()
            })

        return products
    except ET.ParseError as e:
        print(f"Error parsing XML file: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error while parsing XML: {e}")
        sys.exit(1)

def create_table(conn):
    """Create products table if it doesn't exist"""
    try:
        with conn.cursor() as cur:
            cur.execute("""
                CREATE TABLE IF NOT EXISTS products (
                    id SERIAL PRIMARY KEY,
                    title TEXT NOT NULL,
                    price DECIMAL(10,2) NOT NULL,
                    product_link TEXT NOT NULL,
                    category TEXT NOT NULL,
                    image_url TEXT NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
        conn.commit()
    except psycopg2.Error as e:
        print(f"Error creating table: {e}")
        conn.rollback()
        sys.exit(1)

def insert_products(conn, products):
    """Insert products into database"""
    try:
        with conn.cursor() as cur:
            # Clear existing data
            cur.execute("TRUNCATE TABLE products RESTART IDENTITY CASCADE")

            # Prepare data for bulk insert
            values = [(
                p['title'],
                p['price'],
                p['product_link'],
                p['category'],
                p['image_url'],
                p['created_at']
            ) for p in products]

            # Bulk insert using execute_values
            execute_values(cur, """
                INSERT INTO products (title, price, product_link, category, image_url, created_at)
                VALUES %s
            """, values)

            # Get number of inserted records
            cur.execute("SELECT COUNT(*) FROM products")
            count = cur.fetchone()[0]

        conn.commit()
        return count
    except psycopg2.Error as e:
        print(f"Error inserting data: {e}")
        conn.rollback()
        sys.exit(1)

def main():
    """Main function to orchestrate the XML to PostgreSQL import"""
    print("Starting database import process...")

    # Check if XML file exists
    xml_path = "data/products_database.xml"
    if not os.path.exists(xml_path):
        print(f"Error: XML file not found at {xml_path}")
        sys.exit(1)

    try:
        # Connect to database
        print("Connecting to database...")
        conn = connect_to_database()

        # Create table
        print("Creating/verifying products table...")
        create_table(conn)

        # Parse XML
        print("Parsing XML file...")
        products = parse_xml_file(xml_path)

        # Insert data
        print("Inserting products into database...")
        inserted_count = insert_products(conn, products)

        print(f"Successfully imported {inserted_count} products into database!")

    except Exception as e:
        print(f"An unexpected error occurred: {e}")
        sys.exit(1)
    finally:
        if conn:
            conn.close()
            print("Database connection closed.")

if __name__ == "__main__":
    main()
EOL

# Make the script executable
chmod +x $SCRIPT_NAME

# 4. Execute the script
echo "Executing import_xml_to_db.py..."
python3 $SCRIPT_NAME

# 5. Deactivate and clean up
echo "Deactivating Python virtual environment..."
deactivate

# 6. Clean up files and directories
echo "Cleaning up..."
rm -rf $VENV_NAME
rm $SCRIPT_NAME

echo "Process completed successfully!"