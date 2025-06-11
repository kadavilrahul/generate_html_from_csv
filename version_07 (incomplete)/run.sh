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

# Install Node.js and npm if not present
echo "1.1. Checking and installing Node.js and npm..."
if ! command -v node &> /dev/null; then
    echo "Installing Node.js and npm..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo bash -
    sudo apt-get install -y nodejs
    echo "Node.js and npm installed."
else
    echo "Node.js is already installed."
fi

# Install root Gulp Node.js dependencies
echo "1.2. Installing root Gulp Node.js dependencies..."
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

# Ask user for generation mode
echo "Choose generation mode:"
echo "1. Incremental generation (only process new/changed products)"
echo "2. Force complete regeneration (process all products)"
echo "3. Skip generation"
read -p "Enter your choice (1/2/3): " generation_choice

if [[ "$generation_choice" == "1" ]]; then
    echo "Starting incremental HTML generation..."
    generation_mode="incremental"
elif [[ "$generation_choice" == "2" ]]; then
    echo "Starting force complete regeneration..."
    generation_mode="force"
elif [[ "$generation_choice" == "3" ]]; then
    echo "Skipping HTML page generation."
    generation_mode="skip"
else
    echo "Invalid choice. Defaulting to incremental generation."
    generation_mode="incremental"
fi

if [[ "$generation_mode" != "skip" ]]; then
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
    
    # Run gulp with appropriate flags
    if [[ "$generation_mode" == "force" ]]; then
        npx gulp --folderLocation="$folder_location" --force
    else
        npx gulp --folderLocation="$folder_location"
    fi
    
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

# 3. Database Setup (Optional)
echo ""
echo "=== Database Setup ==="
read -p "Do you want to set up a PostgreSQL database with search functionality? (y/n): " setup_database

if [[ $setup_database =~ ^[Yy]$ ]]; then
    echo "Setting up database and search functionality..."
    
    # Check if products_database.csv exists
    if [[ ! -f "./data/products_database.csv" ]]; then
        echo "Error: ./data/products_database.csv not found."
        echo "This file should be generated during HTML page creation."
        echo "Please run HTML generation first, or check if the file exists."
        read -p "Do you want to continue anyway? (y/n): " continue_anyway
        if [[ ! $continue_anyway =~ ^[Yy]$ ]]; then
            echo "Skipping database setup."
        else
            echo "Continuing with database setup (without data population)..."
            # Run database creation script
            if [[ -f "create_database.sh" ]]; then
                chmod +x create_database.sh
                ./create_database.sh "$folder_location"
            else
                echo "Error: create_database.sh not found."
            fi
        fi
    else
        echo "Found products database CSV file: ./data/products_database.csv"
        # Run database creation script
        if [[ -f "create_database.sh" ]]; then
            chmod +x create_database.sh
            ./create_database.sh "$folder_location"
        else
            echo "Error: create_database.sh not found."
        fi
    fi
else
    echo "Skipping database setup."
fi

echo "Project setup and execution completed successfully!"

# Display final summary
echo ""
echo "=== SUMMARY ==="
echo "Folder location: $folder_location"
if [[ "$generation_mode" != "skip" ]]; then
    echo "HTML pages generated: Yes"
    if [[ -d "$folder_location/public/products" ]]; then
        html_count=$(find "$folder_location/public/products" -name "*.html" | wc -l)
        echo "Total HTML files: $html_count"
    fi
else
    echo "HTML pages generated: No"
fi

if [[ $setup_database =~ ^[Yy]$ ]]; then
    echo "Database setup: Attempted"
    if [[ -f "./data/website_db_credentials.conf" ]]; then
        echo "Database credentials: ./data/website_db_credentials.conf"
    fi
    if [[ -f "$folder_location/public/search.php" ]]; then
        domain=$(basename "$folder_location")
        echo "Search functionality: https://$domain/search.php"
    fi
else
    echo "Database setup: Skipped"
fi

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