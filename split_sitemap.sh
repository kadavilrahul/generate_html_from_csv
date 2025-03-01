#!/bin/bash
# split_sitemap.sh

# Configuration
INPUT_FILE="data/sitemap.xml"  # Relative path
OUTPUT_DIR=$(dirname "$INPUT_FILE")
BASE_NAME=$(basename "$INPUT_FILE" .xml)
URLS_PER_FILE=10000  # Changed to 10,000 URLs per file
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file $INPUT_FILE not found!"
    exit 1
fi

# Check if xmlstarlet is installed
if ! command -v xmlstarlet &> /dev/null; then
    echo "Error: xmlstarlet is not installed. Please install it first."
    echo "You can install it with: apt-get install xmlstarlet"
    exit 1
fi

echo "Processing sitemap: $INPUT_FILE"

# First, let's examine the structure of the XML file
echo "Analyzing XML structure..."
xmlstarlet el "$INPUT_FILE" | head -5

# Try to detect the namespace
NAMESPACE=$(grep -o 'xmlns="[^"]*"' "$INPUT_FILE" | head -1 | cut -d'"' -f2)
if [ -n "$NAMESPACE" ]; then
    echo "Detected namespace: $NAMESPACE"
    # Count total URLs in the sitemap with namespace
    TOTAL_URLS=$(xmlstarlet sel -N ns="$NAMESPACE" -t -v "count(//ns:url)" "$INPUT_FILE")
else
    # Try without namespace
    TOTAL_URLS=$(xmlstarlet sel -t -v "count(//url)" "$INPUT_FILE")
fi

# If still 0, try a different approach with grep
if [ "$TOTAL_URLS" -eq 0 ]; then
    echo "Using alternative method to count URLs..."
    TOTAL_URLS=$(grep -c "<url>" "$INPUT_FILE")
    echo "Found $TOTAL_URLS URLs using grep"
fi

echo "Found $TOTAL_URLS URLs in the sitemap"

# If still no URLs found, try to show the root element
if [ "$TOTAL_URLS" -eq 0 ]; then
    echo "Could not find URLs. Showing file structure:"
    head -20 "$INPUT_FILE"
    echo "..."
    echo "Please check if this is a valid sitemap XML file."
    exit 1
fi

# Calculate number of files needed
NUM_FILES=$(( (TOTAL_URLS + URLS_PER_FILE - 1) / URLS_PER_FILE ))
echo "Splitting into $NUM_FILES files with $URLS_PER_FILE URLs per file"

# Create a temporary directory for processing
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Extract the XML declaration and root element
XML_DECL=$(head -1 "$INPUT_FILE")
ROOT_START=$(grep -m1 "<urlset" "$INPUT_FILE" || grep -m1 "<sitemapindex" "$INPUT_FILE")
ROOT_END=$(echo "$ROOT_START" | sed 's/<\([^ ]*\).*/<\/\1>/')

# Process the sitemap in chunks using line-based splitting
# This is more reliable for large files with potential namespace issues
echo "Splitting file..."
LINES_PER_URL=$(grep -A10 -m1 "<url>" "$INPUT_FILE" | grep -m1 -n "</url>" | cut -d: -f1)
TOTAL_LINES=$(wc -l < "$INPUT_FILE")
HEADER_LINES=$(grep -m1 -n "<url>" "$INPUT_FILE" | cut -d: -f1)
FOOTER_LINES=$((TOTAL_LINES - $(grep -n "</urlset>" "$INPUT_FILE" | tail -1 | cut -d: -f1) + 1))

for ((i=1; i<=NUM_FILES; i++)); do
    START_URL=$(( (i-1) * URLS_PER_FILE + 1 ))
    END_URL=$(( i * URLS_PER_FILE ))
    
    if [ $END_URL -gt $TOTAL_URLS ]; then
        END_URL=$TOTAL_URLS
    fi
    
    OUTPUT_FILE="${OUTPUT_DIR}/${BASE_NAME}_part${i}_${TIMESTAMP}.xml"
    
    echo "Creating part $i ($START_URL to $END_URL) -> $OUTPUT_FILE"
    
    # Calculate line numbers
    START_LINE=$((HEADER_LINES + (START_URL - 1) * LINES_PER_URL))
    END_LINE=$((HEADER_LINES + END_URL * LINES_PER_URL - 1))
    
    # Create the new file
    echo "$XML_DECL" > "$OUTPUT_FILE"
    echo "$ROOT_START" >> "$OUTPUT_FILE"
    
    # Extract the URLs for this chunk
    sed -n "${START_LINE},${END_LINE}p" "$INPUT_FILE" >> "$OUTPUT_FILE"
    
    # Close the root element
    echo "$ROOT_END" >> "$OUTPUT_FILE"
    
    # Count URLs in the output file to verify
    URL_COUNT=$(grep -c "<url>" "$OUTPUT_FILE")
    echo "  - Added $URL_COUNT URLs to $OUTPUT_FILE"
done

echo "Sitemap splitting complete!"
echo "Output files are in: $OUTPUT_DIR"
