#!/usr/bin/env python3
# /var/www/silkroademart.com/data/split_sitemap.py

import os
import sys
import re
from datetime import datetime

# Configuration
input_file = "data/sitemap.xml"  # Relative path
urls_per_file = 10000  # 10,000 URLs per file

# Check if input file exists
if not os.path.isfile(input_file):
    print(f"Error: Input file {input_file} not found!")
    sys.exit(1)

output_dir = os.path.dirname(input_file)
base_name = os.path.basename(input_file).split('.')[0]
timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

print(f"Processing sitemap: {input_file}")

# Read the file content
try:
    with open(input_file, 'r', encoding='utf-8') as f:
        content = f.read()
except UnicodeDecodeError:
    # Try with a different encoding if UTF-8 fails
    with open(input_file, 'r', encoding='latin-1') as f:
        content = f.read()

# Extract XML declaration
xml_decl_match = re.search(r'<\?xml[^>]+\?>', content)
xml_decl = xml_decl_match.group(0) if xml_decl_match else '<?xml version="1.0" encoding="UTF-8"?>'

# Find the root element and its attributes
root_match = re.search(r'<(urlset|sitemapindex)([^>]*)>', content)
if not root_match:
    print("Error: Could not find root element (urlset or sitemapindex)")
    sys.exit(1)

root_name = root_match.group(1)
root_attrs = root_match.group(2)
root_start = f"<{root_name}{root_attrs}>"
root_end = f"</{root_name}>"

# Extract all URL elements
print("Extracting URL elements...")
url_pattern = re.compile(r'<url>.*?</url>', re.DOTALL)
urls = url_pattern.findall(content)

total_urls = len(urls)
print(f"Found {total_urls} URLs in the sitemap")

if total_urls == 0:
    print("Error: No URLs found in the sitemap")
    sys.exit(1)

# Calculate number of files needed
num_files = (total_urls + urls_per_file - 1) // urls_per_file
print(f"Splitting into {num_files} files with {urls_per_file} URLs per file")

# Process in chunks
for i in range(num_files):
    start_idx = i * urls_per_file
    end_idx = min((i + 1) * urls_per_file, total_urls)
    
    output_file = f"{output_dir}/{base_name}_part{i+1}_{timestamp}.xml"
    
    print(f"Creating part {i+1} (URLs {start_idx+1} to {end_idx}) -> {output_file}")
    
    # Create the new file with proper XML structure
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(f"{xml_decl}\n")
        f.write(f"{root_start}\n")
        
        # Add URLs for this chunk
        for j in range(start_idx, end_idx):
            f.write(f"{urls[j]}\n")
        
        f.write(f"{root_end}\n")
    
    # Count URLs in the output file
    with open(output_file, 'r', encoding='utf-8') as f:
        url_count = f.read().count("<url>")
    
    print(f"  - Added {url_count} URLs to {output_file}")

print("Sitemap splitting complete!")
print(f"Output files are in: {output_dir}")
