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

# Clear temp file if it exists
> "$TEMP_FILE"

# Try using xmlstarlet if available
if command -v xmlstarlet &> /dev/null; then
    echo "Using xmlstarlet for XML parsing..."
    xmlstarlet sel -t -m "//product" \
        -v "title" -o "," \
        -v "price" -o "," \
        -v "product_link" -o "," \
        -v "category" -o "," \
        -v "image_url" -n \
        "$INPUT_FILE" | \
        awk -F, '{
            for(i=1; i<=NF; i++) {
                if($i ~ /[,"\n]/) {
                    gsub(/"/, "\"\"", $i);
                    $i = "\"" $i "\"";
                }
            }
            print $1 "," $2 "," $3 "," $4 "," $5;
        }' >> "$OUTPUT_FILE"
    
    XML_PARSE_RESULT=$?
else
    XML_PARSE_RESULT=1
fi

# If xmlstarlet is not available or failed, use the original method
if [ $XML_PARSE_RESULT -ne 0 ]; then
    echo "Using basic parsing method..."
    > "$OUTPUT_FILE"  # Clear the output file
    echo "title,price,product_link,category,image_url" > "$OUTPUT_FILE"
    
    # Extract data and properly quote fields to handle commas
    count=0
    declare -a product_data
    
    while IFS= read -r line; do
        if [[ $line =~ \<\!\[CDATA\[(.*?)\]\]\> ]]; then
            # Properly escape the field for CSV
            field="${BASH_REMATCH[1]}"
            # If field contains comma, quote, or newline, enclose in quotes
            if [[ "$field" == *","* || "$field" == *"\""* || "$field" == *$'\n'* ]]; then
                field="${field//\"/\"\"}"  # Double up quotes within the field
                field="\"$field\""
            fi
            
            product_data[$count]="$field"
            count=$((count + 1))
            
            # When we have 5 fields, write a complete product record
            if [ $count -eq 5 ]; then
                echo "${product_data[0]},${product_data[1]},${product_data[2]},${product_data[3]},${product_data[4]}" >> "$OUTPUT_FILE"
                count=0
                unset product_data
                declare -a product_data
            fi
        fi
    done < "$INPUT_FILE"
    
    # Check if we have incomplete records
    if [ $count -ne 0 ]; then
        echo "Warning: Found incomplete product record at the end of the file"
    fi
fi

echo "Conversion completed. CSV file created at: $OUTPUT_FILE"

# Validate the CSV file
echo "Validating CSV file..."
line_count=$(wc -l < "$OUTPUT_FILE")
field_count=$(head -n 1 "$OUTPUT_FILE" | tr ',' '\n' | wc -l)
echo "CSV file has $line_count lines with $field_count fields per line"

# Check for any rows with incorrect number of fields
incorrect_rows=$(awk -F, '{if (NF != 5) print NR}' "$OUTPUT_FILE")
if [ -n "$incorrect_rows" ]; then
    echo "Warning: Found rows with incorrect number of fields: $incorrect_rows"
fi
