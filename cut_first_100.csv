#!/bin/bash

# Database configuration
DB_HOST="localhost"
DB_PORT="5432"
DB_NAME="products_db"
DB_USER="products_user"
DB_PASSWORD="products_2@"

# Set PGPASSWORD environment variable
export PGPASSWORD="$DB_PASSWORD"

# Original CSV file
ORIGINAL_CSV="data/products_database.csv"
# CSV file with first 100 rows
TRUNCATED_CSV="data/products_first_100.csv"

# Check if original CSV file exists
if [ ! -f "$ORIGINAL_CSV" ]; then
    echo "Error: Original CSV file not found: $ORIGINAL_CSV"
    exit 1
fi

echo "Creating a new CSV file with only the first 100 rows..."

# Create a Python script to extract and fix the first 100 rows
cat > /tmp/extract_100.py << 'EOF'
import csv
import sys

input_file = sys.argv[1]
output_file = sys.argv[2]
max_rows = 100

# Field length limits based on database schema
FIELD_LIMITS = [100, 20, 100, 50, 100]  # title, price, product_link, category, image_url

# Read and process the CSV
with open(input_file, 'r', encoding='utf-8', errors='ignore') as infile:
    # Read header
    header = infile.readline().strip().split(',')
    
    # Open output file
    with open(output_file, 'w', newline='', encoding='utf-8') as outfile:
        writer = csv.writer(outfile, quoting=csv.QUOTE_ALL)
        writer.writerow(header[:5])  # Write header (limit to 5 fields)
        
        # Process only the first 100 rows
        row_count = 0
        for line in infile:
            if row_count >= max_rows:
                break
                
            # Clean the line - remove backslashes and problematic characters
            line = line.replace('\\', '')
            
            # Parse the line manually to handle potential CSV issues
            fields = []
            current_field = ""
            in_quotes = False
            
            for char in line:
                if char == '"':
                    in_quotes = not in_quotes
                elif char == ',' and not in_quotes:
                    fields.append(current_field.strip())
                    current_field = ""
                    continue
                current_field += char
            
            # Add the last field
            fields.append(current_field.strip())
            
            # Remove quotes from fields
            fields = [field.strip('"') for field in fields]
            
            # Ensure we have at least 5 fields
            while len(fields) < 5:
                fields.append("")
            
            # Truncate fields to their limits
            for i in range(min(5, len(fields))):
                if len(fields[i]) > FIELD_LIMITS[i]:
                    fields[i] = fields[i][:FIELD_LIMITS[i]]
            
            # Write the row (limit to 5 fields)
            writer.writerow(fields[:5])
            row_count += 1

print(f"CSV processing complete. Extracted {row_count} rows.")
EOF

# Run the Python script to extract first 100 rows
python3 /tmp/extract_100.py "$ORIGINAL_CSV" "$TRUNCATED_CSV"

# Check if the processing was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to process the CSV file"
    rm /tmp/extract_100.py
    exit 1
fi

# Clean up
rm /tmp/extract_100.py

echo "First 100 rows extracted and saved to $TRUNCATED_CSV"

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
\COPY temp_products FROM '$TRUNCATED_CSV' WITH CSV HEADER;

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

echo "First 100 rows imported successfully"
