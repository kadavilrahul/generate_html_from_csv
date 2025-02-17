Trying to add features delete unnecessary file and folder after running node.js, 

# HTML Product Generator

This project generates static HTML product pages, sitemap, and product XML from CSV data for a website.

## Prerequisites

- Node.js (v14 or higher)
- npm
- jq (for JSON processing in setup script)
- PHP with mysqli extension

## Setup
1. Prepare products.csv as per sample_products.csv 
   Place it in main project directory
   

2. Run the main script:
   ```bash
   bash main.sh
   ```
   This will:
   - Update configuration in config.json (if needed)
   - Update database settings in search.php
   - Run setup.sh (optional)
   - Convert XML to CSV format

3. The setup script (setup.sh) will:
   - Create necessary directories
   - Install dependencies
   - Set up EJS templates
   - Configure API credentials
   - Prices are currently setup n India Rupees

## Search Functionality

The project includes a search.php file that provides product search capabilities:
- Searches through product titles, descriptions, and categories
- Returns results in a responsive grid layout
- Includes product images, prices, and details
- Supports error handling and proper sanitization

## Directory Structure

```
/var/www/main.silkroademart.com/
├── config.json         # Configuration file
├── main.sh             # Main script for setup and configuration
├── setup.sh            # Setup script
├── search.php          # Product search functionality
├── products.csv        # CSV file of products that is to be converted to HTML
├── data/               # Data files
│   ├── products_database.xml   # Source XML file
│   └── products_database.csv   # Converted CSV file
├── views/              # EJS templates
│   └── product.ejs     # Product page template
└── public/             # Generated files
    ├── products/       # Generated HTML files
    └── images/         # Downloaded product images
```

## Generated Files

- `public/products/*.html`: Individual product pages
- `public/images/*`: Product images
- `sitemap.xml`: Site map for search engines
- `products.xml`: Product catalog in XML format
- `products_database.csv`: Converted product data in CSV format

## Error Handling

- Check the console output for any errors during processing
- Image download failures will be logged but won't stop the process
- Database connection errors will be reported in the console
- Search functionality includes proper error handling and user feedback

## Security Notes

- API credentials are stored in config.json
- Database credentials are properly secured
- All user inputs are sanitized
- Prepared statements are used for database queries
- Ensure proper file permissions are set

## Support

For support, please contact:
- Technical support: support@silkroademart.com
- General inquiries: info@silkroademart.com
