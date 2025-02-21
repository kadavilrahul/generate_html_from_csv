# Development Environment Setup Script

This repository contains a setup script to automate the installation of development tools and configurations on Ubuntu/Debian-based systems.

## Prerequisites

- Ubuntu/Debian-based operating system
- Sudo privileges
- Internet connection
- Apache/Nginx server
- php

## Tested on: Ubuntu 24.04 Apache

## Installation

1. Move to the folder where you want to generate HTML files

```bash
cd <project-folder>
```
2. Clone this repository files

```bash
git clone https://github.com/kadavilrahul/generate_html_from_csv .
```
3. Modify following lines in setup.sh
```bash 
706, 707, 769, 519, 520, 548, 549, 550, 551
```
or
Run replace.sh
```bash 
bash replace.sh
```

4. Run packages.sh

```bash 
bash packages.sh
```
5. Run setup.sh

```bash
bash setup.sh
```
6. Run convert.sh

```bash
bash data/convert.sh
```

7. Run create_database.sh

```bash
bash data/create_database.sh
```

8. Run create_database.sh

```bash
bash data/import_csv.sh
```

9. Run create_database.sh

```bash
bash data/check_data.sh
```

10. Run create_database.sh

```bash
bash data/install_pgadmin.sh
```
After installation:

11. Access pgadmin on your web browser
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


12. Check the tables and imported products:
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
