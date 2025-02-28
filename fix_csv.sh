#!/bin/bash

# Define input and output files
INPUT_CSV="data/products_database.csv"
OUTPUT_CSV="data/products_database_truncated.csv"

# Check if input file exists
if [ ! -f "$INPUT_CSV" ]; then
    echo "Error: Input CSV file not found: $INPUT_CSV"
    exit 1
fi

echo "Fixing CSV file: $INPUT_CSV"

# Create a Python script to properly handle CSV processing
cat > /tmp/fix_csv.py << 'EOF'
import csv
import sys
import re

input_file = sys.argv[1]
output_file = sys.argv[2]

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
        
        # Process each line
        line_num = 1
        for line in infile:
            line_num += 1
            
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

print(f"CSV processing complete. Processed {line_num} lines.")
EOF

# Run the Python script
python3 /tmp/fix_csv.py "$INPUT_CSV" "$OUTPUT_CSV"

# Check if the processing was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to process the CSV file"
    rm /tmp/fix_csv.py
    exit 1
fi

# Clean up
rm /tmp/fix_csv.py

echo "CSV file has been fixed and saved to $OUTPUT_CSV"
echo "All fields have been truncated to appropriate lengths:"
echo "  - title: 100 characters"
echo "  - price: 20 characters"
echo "  - product_link: 100 characters"
echo "  - category: 50 characters"
echo "  - image_url: 100 characters"
echo "You can now run: bash data/import_csv.sh"
