#!/bin/bash

# Database configuration
DB_HOST="localhost"
DB_PORT="5432"
DB_NAME="products_db"
DB_USER="products_user"
DB_PASSWORD="products_2@"

# Set PGPASSWORD environment variable
export PGPASSWORD="$DB_PASSWORD"

CSV_FILE="data/products_database.csv"

# Check if CSV file exists
if [ ! -f "$CSV_FILE" ]; then
    echo "Error: CSV file not found: $CSV_FILE"
    exit 1
fi

# More aggressive CSV format fixing
echo "Fixing CSV format issues..."
TMP_CSV_FILE="data/products_database_fixed.csv"

# Create a Python script to fix the CSV
cat > fix_csv.py << 'EOF'
import csv
import re
import sys

def fix_csv(input_file, output_file):
    with open(input_file, 'r', encoding='utf-8', errors='replace') as infile, \
         open(output_file, 'w', encoding='utf-8') as outfile:
        
        # Read the entire file as text first
        content = infile.read()
        
        # Remove all special characters and symbols that might cause issues
        content = re.sub(r'[^\w\s,.]', ' ', content)
        
        # Make sure we have the right number of columns on each line
        lines = content.strip().split('\n')
        header = lines[0]
        expected_commas = header.count(',')
        
        fixed_lines = [header]
        for line in lines[1:]:
            if not line.strip():
                continue
            
            # Ensure each line has the correct number of commas
            commas = line.count(',')
            if commas < expected_commas:
                line += ',' * (expected_commas - commas)
            elif commas > expected_commas:
                parts = line.split(',')
                line = ','.join(parts[:expected_commas+1])
            
            fixed_lines.append(line)
        
        # Write the fixed content to the output file
        outfile.write('\n'.join(fixed_lines))

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python fix_csv.py input_file output_file")
        sys.exit(1)
    
    fix_csv(sys.argv[1], sys.argv[2])
EOF

# Run the Python script to fix the CSV
if command -v python3 >/dev/null 2>&1; then
    python3 fix_csv.py "$CSV_FILE" "$TMP_CSV_FILE"
elif command -v python >/dev/null 2>&1; then
    python fix_csv.py "$CSV_FILE" "$TMP_CSV_FILE"
else
    echo "Error: Python is not installed. Falling back to sed-based fix."
    # Fallback to sed-based fix if Python is not available
    cat "$CSV_FILE" | sed 's/[^a-zA-Z0-9,. ]/ /g' > "$TMP_CSV_FILE"
fi

# Add error checking for database operations
if ! psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME << EOF
-- Create temporary table with TEXT type for all columns to avoid length issues
DROP TABLE IF EXISTS temp_products;
CREATE TABLE temp_products (
    title TEXT,
    price TEXT,
    product_link TEXT,
    category TEXT,
    image_url TEXT
);

-- Copy CSV data into temporary table with more flexible error handling
\COPY temp_products FROM '$TMP_CSV_FILE' WITH CSV HEADER DELIMITER ',' NULL '';

-- Get the column definitions from the products table
DO \$\$
DECLARE
    title_max INT;
    product_link_max INT;
    category_max INT;
    image_url_max INT;
BEGIN
    SELECT character_maximum_length INTO title_max FROM information_schema.columns 
    WHERE table_name = 'products' AND column_name = 'title';
    
    SELECT character_maximum_length INTO product_link_max FROM information_schema.columns 
    WHERE table_name = 'products' AND column_name = 'product_link';
    
    SELECT character_maximum_length INTO category_max FROM information_schema.columns 
    WHERE table_name = 'products' AND column_name = 'category';
    
    SELECT character_maximum_length INTO image_url_max FROM information_schema.columns 
    WHERE table_name = 'products' AND column_name = 'image_url';
    
    -- Insert new records only if they don't exist with price conversion and truncation
    EXECUTE 'INSERT INTO products (title, price, product_link, category, image_url)
    SELECT 
        SUBSTRING(t.title, 1, ' || COALESCE(title_max, 100) || '), 
        CASE 
            WHEN t.price ~ ''^\d+$'' THEN t.price::integer
            WHEN t.price ~ ''^\d+\.\d+$'' THEN t.price::numeric::integer
            ELSE 0
        END as price,
        SUBSTRING(t.product_link, 1, ' || COALESCE(product_link_max, 100) || '), 
        SUBSTRING(t.category, 1, ' || COALESCE(category_max, 100) || '), 
        SUBSTRING(t.image_url, 1, ' || COALESCE(image_url_max, 100) || ')
    FROM temp_products t
    LEFT JOIN products p ON SUBSTRING(t.product_link, 1, ' || COALESCE(product_link_max, 100) || ') = p.product_link
    WHERE p.product_link IS NULL';
    
    -- Update existing records with price conversion and truncation
    EXECUTE 'UPDATE products p
    SET 
        title = SUBSTRING(t.title, 1, ' || COALESCE(title_max, 100) || '),
        price = CASE 
            WHEN t.price ~ ''^\d+$'' THEN t.price::integer
            WHEN t.price ~ ''^\d+\.\d+$'' THEN t.price::numeric::integer
            ELSE 0
        END,
        category = SUBSTRING(t.category, 1, ' || COALESCE(category_max, 100) || '),
        image_url = SUBSTRING(t.image_url, 1, ' || COALESCE(image_url_max, 100) || ')
    FROM temp_products t
    WHERE p.product_link = SUBSTRING(t.product_link, 1, ' || COALESCE(product_link_max, 100) || ')';
END;
\$\$;

-- Cleanup
DROP TABLE temp_products;
EOF
then
    echo "Error: Database operation failed"
    exit 1
fi

# Clean up temporary files
rm -f "$TMP_CSV_FILE" fix_csv.py

# Unset PGPASSWORD for security
unset PGPASSWORD

echo "CSV import completed successfully"
