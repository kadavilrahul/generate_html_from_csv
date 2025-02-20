#!/bin/bash

# Define input and output files using relative paths
INPUT_FILE="./data/products_database.xml"
OUTPUT_FILE="./data/products_database.csv"

# Create CSV header
echo "title,price,product_link,category,image_url" > "$OUTPUT_FILE"

# Convert XML to CSV using grep and paste
cat "$INPUT_FILE" | grep -oP '(?<=<title><!\[CDATA\[).*?(?=\]\]></title>)|(?<=<price><!\[CDATA\[).*?(?=\]\]></price>)|(?<=<product_link><!\[CDATA\[).*?(?=\]\]></product_link>)|(?<=<category><!\[CDATA\[).*?(?=\]\]></category>)|(?<=<image_url><!\[CDATA\[).*?(?=\]\]></image_url>)' | paste -d, - - - - - >> "$OUTPUT_FILE"

echo "Conversion completed. CSV file created at: $OUTPUT_FILE"

# Created/Modified files during execution:
# ./data/products_database.csv
