# Version 03: CSV to HTML Conversion Project

This project is designed to generate HTML pages from CSV files using Gulp.

## Project Structure

```
version_03/
├── products.csv      # Input CSV file
├── product.ejs       # EJS template for HTML generation
├── gulpfile.js       # Gulp tasks for CSV to HTML conversion
├── package.json      # Node.js dependencies for Gulp
├── README.md         # Project documentation
└── run.sh            # Script to set up and run the HTML generation
```

## Setup and Running the Project

### Prerequisites

*   Node.js and npm (or yarn)
*   Gulp CLI (`npm install -g gulp-cli`)

### Installation

You can use the `run.sh` script to set up and run the HTML generation.

```bash
cd version_03_cline_testing
```

```bash
bash run.sh
```

The script will prompt you if you want to generate HTML pages from CSV. If you confirm, it will execute the Gulp task.

## Gulp Tasks

*   `gulp csvToHtml`: Converts CSV data from `products.csv` into HTML files using `product.ejs` and outputs them to `/var/www/test.silkroademart.com`.
