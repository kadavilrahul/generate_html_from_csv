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