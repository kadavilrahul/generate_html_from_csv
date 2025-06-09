# Product Page Generator v4

A simple tool that converts CSV product data into individual HTML pages with automatic image downloading and incremental generation.

What the project does - CSV to HTML product page generation
Key features - Including the new incremental generation
Quick setup - Simple 3-step process
Usage options - Both incremental and force modes
File structure - What gets generated where
Requirements - Node.js and npm

## What it does

- Reads product data from `products.csv`
- Downloads product images automatically
- Generates individual HTML pages for each product
- Creates a sitemap and products database
- **NEW**: Only processes changed products (incremental generation)

## Quick Start

1. **Install dependencies:**
   ```bash
   npm install
   ```

2. **Run the generator:**
   ```bash
   ./run.sh
   ```

3. **Follow the prompts:**
   - Enter your website folder (e.g., `/var/www/yoursite.com`)
   - Choose incremental or force regeneration

## Files you need

- `products.csv` - Your product data
- `product.ejs` - HTML template for product pages

## What gets generated

- **HTML pages** → `your-folder/public/products/`
- **Product images** → `your-folder/public/images/`
- **Sitemap** → `./data/sitemap.xml`
- **Products database** → `./data/products_database.csv`

## CSV Format

Your `products.csv` should have these columns:
```
Image,Title,Regular Price,Category,Short_description,description
```

## Generation Modes

- **Incremental** (default): Only processes new/changed products
- **Force**: Regenerates all products regardless of changes


That's it! 🚀