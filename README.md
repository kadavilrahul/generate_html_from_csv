# Development Environment Setup Script

This repository contains a setup script to automate the installation of development tools and configurations on Ubuntu/Debian-based systems.

## Prerequisites

- Ubuntu/Debian-based operating system
- Sudo privileges
- Internet connection
- Apache/Nginx server
- php

### Tested on: Ubuntu 24.04 Apache

### Setup ssh keys (optional)
Needed ony if you want to login from another machine securely without password 
https://github.com/kadavilrahul/generate_ssh_keys/blob/main/ssh-to-another-server.txt

## Installation

1. Clone this repository

```bash
git clone https://github.com/kadavilrahul/generate_html_from_csv
```
```bash
cd generate_html_from_csv
```

2. Install Apache and Posstgres on new server if already installed

```bash
bash apache_postgres.sh
```
3. Install SSL on the sever for your domain or subdomain if not already installed.
   Make sure to point th DNS correctly

```bash
bash maindomain.sh
```
or

```bash
bash subdomain.sh
```

4. Move to the folder where you want to generate HTML files
Example: The domain folder where SSL is installed like /var/www/your_domain.com

Optionally open the folder in VS code to easily modify files and use terminal

```bash
cd <project-folder>
```

5. Clone this repository files again to the new location. Delete any unwanted files in th location.

```bash
git clone https://github.com/kadavilrahul/generate_html_from_csv .
```

6. Modify following lines in setup.sh
```bash 
706, 707, 769, 519, 520, 548, 549, 550, 551
```
or
Create a blank file replace.sh and paste th content provided to it and then replace.sh.

Note: Do not copy paste the file itself using SFTP
```bash 
bash replace.sh
```

7. Run packages.sh

```bash 
bash packages.sh
```
8. Create HTML products

```bash
bash setup.sh
```
9. Convert products_database.xml to products_database.csv so that it can be uploaded to database

```bash
bash data/convert.sh
```

10. Create poastgres database

```bash
bash data/create_database.sh
```

11. Import CSV products to postgres database

```bash
bash data/import_csv.sh
```

12. Check if data was imported sucessfully. Only firsst five products are see
    Check also the HTML page if search bar is functional

```bash
bash data/check_data.sh
```

13. Optionally install pgadmin to manage postgres database
    Else connect using remote database tool like dbeaver

```bash
bash data/install_pgadmin.sh
```

14. After installation access pgadmin on your web browser
```
Navigate to: http://your_server_ip/pgadmin4
Log in with your email and password
Add a new server connection using:
Host: localhost
Port: 5432
Database: products_db
Username: products_user
Password: products_2@
This will give you a web-based interface to manage your PostgreSQL database.
```

15. Check the database tables and imported products:
```
In pgAdmin4 interface:

Expand Servers (left sidebar)
Expand your PostgreSQL server
Expand Databases
Expand products_db
Expand Schemas
Expand public
Expand Tables
You should see 'products' table
To view the data:

Right-click on the 'products' table
Select "View/Edit Data"
Click "All Rows"
```

After everything check if HTML pages are displayed correctly and the searchbar is functioning properly.
