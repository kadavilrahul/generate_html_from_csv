# Silk Road e-Mart Product Generator

This project generates static HTML product pages, sitemap, and product XML from CSV data for the Silk Road e-Mart website.

## Prerequisites

- Node.js (v14 or higher)
- npm
- jq (for JSON processing in setup script)

## Setup

1. Configure your settings in `config.json`:
   ```json
   {
     "project": {
       "directory": "/var/www/main.silkroademart.com",
       "baseUrl": "https://main.silkroademart.com"
     },
     "database": {
       "host": "your-db-host",
       "username": "your-db-username",
       "password": "your-db-password",
       "name": "your-db-name"
     },
     "api": {
       "url": "your-api-url",
       "consumerKey": "your-consumer-key",
       "consumerSecret": "your-consumer-secret"
     }
   }
   ```

2. Run the setup script:
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```
   This will:
   - Create necessary directories
   - Install dependencies
   - Set up EJS templates
   - Configure API credentials

3. Prepare your CSV data:
   Place your product CSV file in the `data` directory. The CSV should have the following columns:
   - Title
   - Regular Price
   - Category
   - Image
   - Short_description
   - description

## Usage

Run the parser to generate product pages:
```bash
node parse-csv.js
```

This will:
1. Generate individual HTML pages for each product
2. Download and store product images
3. Create a sitemap.xml
4. Generate a products.xml file

## Directory Structure

```
/var/www/main.silkroademart.com/
├── config.json          # Configuration file
├── setup.sh            # Setup script
├── parse-csv.js        # CSV parser and page generator
├── data/               # CSV data files
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


---------------------
OLD README
---------------------

# Instructions to run shellscript
First, make the script executable:

# Modify and set correct varialbles in lines 9, 861, 867 in setup.sh file which looks like below three lines.
# PROJECT_DIR=""
# const baseDir = '';
# const BASE_URL = '';

Set permissions
chmod +x /var/www/test.silkroademart.com/setup.sh
Run the script:
sudo /var/www/test.silkroademart.com/setup.sh

After the script completes add your CSV file to data directory
Run command as shown on terminal

Create database or add products to existing databse for the newly created products.

Access database
sudo mysql -u root -p
Password: Karimpadam2@

Check existing databases
SHOW DATABASES;
Check existing users
SELECT User FROM mysql.user;
EXIT;

If database "all_products_db" exists then leave below steps else go through below
CREATE DATABASE all_products_db;
CREATE USER 'all_products_user'@'%' IDENTIFIED WITH mysql_native_password BY 'all_products_2@';
GRANT ALL ON all_products_db.* TO 'all_products_user'@'%';
FLUSH PRIVILEGES;

Check existing databases
SHOW DATABASES;
Check existing users
SELECT User FROM mysql.user;
EXIT;

Login to php myadmin with above user and password i.e all_products_user and all_products_2@

Download the xml file located in /var/www/test.silkroademart.com/data/products_database.xml
Open a blank excel file and open the products_database.xml in it.
Save the excel file as products.csv

Open and login php myadmin
For uploading CSV creating the table first time
Click main database
Click Choose file
Select Format: CSV
Checkamrk this:
"The first line of the file contains the table column names (if this is unchecked, the first line will become part of the data)"
Click Import
Check if the csv has been uploaded correctly with all entries and headers.

When uploading CSV for other times follow these
Click main database
Click table products
Delete header from the CSV file
Click Choose file
Select Format: CSV
Click Import
Check if the csv has been uploaded correctly with all entries into the existing headers.

Add search.php to the below mentioned folder so that searchbar can work.
Enter correct database entries. Database should be hosted on same server, only then images etc are displayed correctly.
/var/www/test.silkroademart.com/public/products

In search.php modify lines 25, 26, 27, 28 to enter correct variables

    'host'     => '78.47.134.46',
    'username' => 'all_products_user',
    'password' => 'all_products_2@',
    'database' => 'all_products_db'

To remove or delete folder
rm -r /var/www/new.silkroademart.com

Empty the folder
sudo rm -rf /var/www/new.silkroademart.com/*