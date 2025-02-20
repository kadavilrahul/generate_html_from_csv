#!/bin/bash

# Define input and output files using relative paths
INPUT_FILE="data/products_database.xml"
OUTPUT_FILE="data/products_database.csv"
TEMP_FILE="data/temp.txt"

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file not found at $INPUT_FILE"
    exit 1
fi

# Create CSV header
echo "title,price,product_link,category,image_url" > "$OUTPUT_FILE"

# Extract data and properly quote fields to handle commas
while IFS= read -r line; do
    if [[ $line =~ \<\!\[CDATA\[(.*?)\]\]\> ]]; then
        echo "\"${BASH_REMATCH[1]}\"" >> "$TEMP_FILE"
    fi
done < "$INPUT_FILE"

# Combine every 5 lines with commas
paste -d, - - - - - < "$TEMP_FILE" >> "$OUTPUT_FILE"

# Clean up temporary file
rm -f "$TEMP_FILE"

echo "Conversion completed. CSV file created at: $OUTPUT_FILE"

# Created/Modified files during execution:
# data/products_database.csv
# data/temp.txt (temporary file, deleted after execution)
