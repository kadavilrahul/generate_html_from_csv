#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

echo "Setting up and running the Product Page Generator project..."

# Ask for the folder location
read -p "Please provide the folder location (e.g., /var/www/yourwebsite.com): " folder_location

# Validate folder location input
if [[ -z "$folder_location" ]]; then
    echo "Error: Folder location cannot be empty."
    exit 1
fi

# Create the folder if it doesn't exist
if [[ ! -d "$folder_location" ]]; then
    echo "Creating directory: $folder_location"
    sudo mkdir -p "$folder_location"
    echo "Directory created successfully."
else
    echo "Directory already exists: $folder_location"
fi

# 1. Dependency Installation: Install all required packages.

# Install root Gulp Node.js dependencies
echo "1.1. Installing root Gulp Node.js dependencies..."
if [[ ! -f "package.json" ]]; then
    echo "Error: package.json not found in current directory."
    exit 1
fi

npm install
echo "Root Gulp Node.js dependencies installed."

# 2. Execution: Run the project's main scripts.

echo "2. Running the project components:"

# Gulp CSV to HTML conversion
echo "This will generate HTML files in $folder_location."

# Ask user if they want to generate HTML pages
read -p "Do you want to generate HTML pages from CSV? (y/n): " generate_html_choice

if [[ "$generate_html_choice" =~ ^[Yy]$ ]]; then
    echo "Generating HTML pages..."
    
    # Check if required files exist
    if [[ ! -f "products.csv" ]]; then
        echo "Error: products.csv not found in current directory."
        exit 1
    fi
    
    if [[ ! -f "product.ejs" ]]; then
        echo "Error: product.ejs template not found in current directory."
        exit 1
    fi
    
    if [[ ! -f "gulpfile.js" ]]; then
        echo "Error: gulpfile.js not found in current directory."
        exit 1
    fi
    
    # Run gulp with the folder location as an argument
    npx gulp --folderLocation="$folder_location"
    
    echo "HTML page generation complete."
    echo "Generated files are located in:"
    echo "  - HTML files: $folder_location/public/products/"
    echo "  - Images: $folder_location/public/images/"
    echo "  - Data files: ./data/"
    
    # Display summary of generated files
    if [[ -d "$folder_location/public/products" ]]; then
        html_count=$(find "$folder_location/public/products" -name "*.html" | wc -l)
        echo "Total HTML files generated: $html_count"
    fi
    
    if [[ -d "$folder_location/public/images" ]]; then
        image_count=$(find "$folder_location/public/images" -type f | wc -l)
        echo "Total images downloaded: $image_count"
    fi
    
    if [[ -f "./data/sitemap.xml" ]]; then
        echo "Sitemap generated: ./data/sitemap.xml"
    fi
    
    if [[ -f "./data/products_database.csv" ]]; then
        echo "Products database generated: ./data/products_database.csv"
    fi
    
else
    echo "Skipping HTML page generation."
fi

echo "Project setup and execution completed successfully!"

# 4. Cleanup (Optional): Add a commented-out section for deactivating the virtual environment or cleaning up if necessary.
: '
# To stop the running processes (if they are still active):
# pkill -f "npx gulp"

# To clean up generated files (use with caution):
# rm -rf "$folder_location/public"
# rm -rf "./data"

# To reinstall dependencies:
# rm -rf node_modules package-lock.json
# npm install
'