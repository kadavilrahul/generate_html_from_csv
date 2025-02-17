# Silk Road e-Mart Product Generator

This project generates static HTML product pages, sitemap, and product XML from CSV data for the Silk Road e-Mart website.

## Prerequisites

- Node.js (v14 or higher)
- npm
- jq (for JSON processing in setup script)

## Setup

1. Rename `sample_config.json` to `config.json` and update the settings as per your requirements.

2. Replace `products.csv` with your version of the file containing the required data.
The CSV should have the following columns:
   - Title
   - Regular Price
   - Category
   - Image
   - Short_description
   - description

3. Run the setup script:
   ```bash
   bash setup.sh
   ```
   This will:
   - Create necessary directories
   - Install dependencies
   - Set up EJS templates
   - Configure API credentials

4. Run the parser to generate product pages:
```bash
node parse-csv.js
```

This will:
1. Generate individual HTML pages for each product
2. Download and store product images
3. Create a sitemap.xml
4. Generate a products.xml file


## Generated Files

- `public/products/*.html`: Individual product pages
- `public/images/*`: Product images
- `sitemap.xml`: Site map for search engines
- `products.xml`: Product catalog in XML format

## Error Handling

- Check the console output for any errors during processing
- Image download failures will be logged but won't stop the process
- Database connection errors will be reported in the console

## Security Notes

- API credentials are stored in config.json
- Database credentials should be properly secured
- Ensure proper file permissions are set

## Support

For any issues or questions, please contact the Silk Road e-Mart development team.

