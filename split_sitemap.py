#!/usr/bin/env python3
# python3 data/split_sitemap.py

import os
import re
import sys
from datetime import datetime

# Get the base URL from the current directory structure
def get_base_url():
    # Get the current working directory
    current_path = os.getcwd()
    
    # Extract domain from path
    path_parts = current_path.split(os.sep)
    for part in path_parts:
        if '.' in part and any(tld in part for tld in ['.com', '.org', '.net']):
            return f"https://{part}"
    
    # If we couldn't find a domain in the path, try the parent directory name
    parent_dir = os.path.basename(os.path.dirname(current_path))
    if '.' in parent_dir and any(tld in parent_dir for tld in ['.com', '.org', '.net']):
        return f"https://{parent_dir}"
    
    # If we still can't find it, error out
    print("Error: Could not automatically detect domain name from directory structure.")
    print("Current path:", current_path)
    sys.exit(1)

# Configuration
input_file = "data/sitemap.xml"  # Original sitemap
base_url = get_base_url()  # Automatically get the base URL
sitemap_dir = "data/sitemap"  # New directory for sitemaps (inside /data)
urls_per_file = 10000  # 1,0000 URLs per file
timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

print(f"Using base URL: {base_url}")
print(f"Sitemap directory: {sitemap_dir}")

# Create sitemap directory if it doesn't exist
os.makedirs(sitemap_dir, exist_ok=True)

# Check if input file exists
if not os.path.isfile(input_file):
    print(f"Error: Input file {input_file} not found!")
    print("Generating test data instead...")
    
    # Generate test data
    num_urls = 3500  # Generate enough URLs for multiple files
    urls = []
    
    for i in range(1, num_urls + 1):
        product_id = f"test-product-{i}"
        product_url = f"{base_url}/product/{product_id}/"
        lastmod_date = datetime.now().strftime("%Y-%m-%d")
        
        url_entry = f"""  <url>
    <loc>{product_url}</loc>
    <lastmod>{lastmod_date}</lastmod>
    <changefreq>weekly</changefreq>
    <priority>0.8</priority>
  </url>"""
        urls.append(url_entry)
else:
    print(f"Processing sitemap: {input_file}")
    
    # Read the file content
    try:
        with open(input_file, 'r', encoding='utf-8') as f:
            content = f.read()
    except UnicodeDecodeError:
        try:
            with open(input_file, 'r', encoding='latin-1') as f:
                content = f.read()
        except Exception as e:
            print(f"Error reading file: {e}")
            sys.exit(1)
    
    # Extract all URL elements
    print("Extracting URL elements...")
    url_pattern = re.compile(r'<url>.*?</url>', re.DOTALL)
    urls = url_pattern.findall(content)

total_urls = len(urls)
print(f"Found {total_urls} URLs to process")

if total_urls == 0:
    print("Error: No URLs found")
    sys.exit(1)

# Calculate number of files needed
num_files = (total_urls + urls_per_file - 1) // urls_per_file
print(f"Splitting into {num_files} files with {urls_per_file} URLs per file")

# List to store sitemap filenames for the index
sitemap_files = []

# Process in chunks
for i in range(num_files):
    start_idx = i * urls_per_file
    end_idx = min((i + 1) * urls_per_file, total_urls)
    
    # Create filename with part number
    sitemap_filename = f"sitemap-{i+1}.xml"
    output_file = f"{sitemap_dir}/{sitemap_filename}"
    sitemap_files.append(sitemap_filename)
    
    print(f"Creating part {i+1} (URLs {start_idx+1} to {end_idx}) -> {output_file}")
    
    # Create the new file with proper XML structure
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n')
        f.write('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n')
        
        # Add URLs for this chunk
        for j in range(start_idx, end_idx):
            f.write(f"{urls[j]}\n")
        
        f.write('</urlset>\n')
    
    # Count URLs in the output file
    with open(output_file, 'r', encoding='utf-8') as f:
        url_count = f.read().count("<url>")
    
    print(f"  - Added {url_count} URLs to {output_file}")

# Create sitemap index file
sitemap_index = f"{sitemap_dir}/sitemap-index.xml"
print(f"Creating sitemap index -> {sitemap_index}")

with open(sitemap_index, 'w', encoding='utf-8') as f:
    f.write('<?xml version="1.0" encoding="UTF-8"?>\n')
    f.write('<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n')
    
    # Add each sitemap file to the index
    for sitemap_file in sitemap_files:
        lastmod = datetime.now().strftime("%Y-%m-%d")
        f.write('  <sitemap>\n')
        f.write(f'    <loc>{base_url}/{sitemap_dir}/{sitemap_file}</loc>\n')
        f.write(f'    <lastmod>{lastmod}</lastmod>\n')
        f.write('  </sitemap>\n')
    
    f.write('</sitemapindex>\n')

print("Sitemap splitting complete!")
print(f"Created {num_files} sitemap files in the '{sitemap_dir}' directory")
print(f"Created sitemap index at '{sitemap_index}'")
print(f"You can access the sitemap index at: {base_url}/{sitemap_dir}/sitemap-index.xml")
