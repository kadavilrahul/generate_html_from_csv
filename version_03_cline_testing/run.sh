#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

echo "Setting up and running the Version 03 project..."

# 1. Dependency Installation: Install all required packages.

# Install root Gulp Node.js dependencies
echo "1.1. Installing root Gulp Node.js dependencies..."
npm install
echo "Root Gulp Node.js dependencies installed."

# 2. Execution: Run the project's main scripts.

echo "2. Running the project components:"

# Gulp CSV to HTML conversion
echo "This will generate HTML files in /var/www/test.silkroademart.com."

# Ask user if they want to generate HTML pages
read -p "Do you want to generate HTML pages from CSV? (y/n): " generate_html_choice

if [[ "$generate_html_choice" =~ ^[Yy]$ ]]; then
    echo "Generating HTML pages..."
    npm run gulp csvToHtml
    echo "HTML page generation complete."
else
    echo "Skipping HTML page generation."
fi

# 4. Cleanup (Optional): Add a commented-out section for deactivating the virtual environment or cleaning up if necessary.
: '
# To stop the running processes (if they are still active):
# kill $BACKEND_PID
'
