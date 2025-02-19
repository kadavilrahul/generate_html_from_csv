import psycopg2
from psycopg2 import Error
import xml.etree.ElementTree as ET
import os

def create_database():
    try:
        # Connect to PostgreSQL server with root privileges
        conn = psycopg2.connect(
            host="localhost",
            user="postgres",
            password="Karimpadam2@"
        )
        conn.autocommit = True
        cursor = conn.cursor()

        # Create database
        cursor.execute("CREATE DATABASE products_db")
        print("Database 'products_db' created successfully")

        # Close connection to PostgreSQL server
        cursor.close()
        conn.close()

        # Connect to the newly created database
        conn = psycopg2.connect(
            host="localhost",
            database="products_db",
            user="postgres",
            password="Karimpadam2@"
        )
        conn.autocommit = True
        cursor = conn.cursor()

        # Create products_user with password
        cursor.execute("CREATE USER products_user WITH PASSWORD 'products_2@'")
        cursor.execute("GRANT ALL PRIVILEGES ON DATABASE products_db TO products_user")
        print("User 'products_user' created and granted privileges")

        # Create products table
        cursor.execute("""
            CREATE TABLE products (
                id SERIAL PRIMARY KEY,
                title TEXT NOT NULL,
                price DECIMAL(10,2) NOT NULL,
                product_link TEXT NOT NULL,
                category TEXT NOT NULL,
                image_url TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        print("Table 'products' created successfully")

        # Grant privileges on products table to products_user
        cursor.execute("GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO products_user")
        cursor.execute("GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO products_user")

    except (Exception, Error) as error:
        print("Error while connecting to PostgreSQL:", error)
    finally:
        if conn:
            cursor.close()
            conn.close()

def import_data_from_xml():
    try:
        # Connect to database as products_user
        conn = psycopg2.connect(
            host="localhost",
            database="products_db",
            user="products_user",
            password="products_2@"
        )
        cursor = conn.cursor()

        # Parse XML file
        xml_file = os.path.join('data', 'products_database.xml')
        tree = ET.parse(xml_file)
        root = tree.getroot()

        # Insert data from XML
        for product in root.findall('product'):
            title = product.find('title').text
            price = float(product.find('price').text.replace('₹', '').strip())
            product_link = product.find('product_link').text
            category = product.find('category').text
            image_url = product.find('image_url').text

            cursor.execute("""
                INSERT INTO products (title, price, product_link, category, image_url)
                VALUES (%s, %s, %s, %s, %s)
            """, (title, price, product_link, category, image_url))

        conn.commit()
        print("Data imported successfully from XML")

    except (Exception, Error) as error:
        print("Error while importing data:", error)
    finally:
        if conn:
            cursor.close()
            conn.close()

def main():
    # Create database and table
    create_database()

    # Import data from XML
    import_data_from_xml()

    print("Database setup and data import completed!")

if __name__ == "__main__":
    main()