# Development Environment Setup Script

This repository contains a setup script to automate the installation of development tools and configurations on Ubuntu/Debian-based systems.

## Prerequisites

- Ubuntu/Debian-based operating system
- Sudo privileges
- Internet connection
- Apache/Nginx server
- Php

### Tested on: Ubuntu 24.04 Apache

### Setup ssh keys (optional)
Needed only if you want to login from another machine securely without password.
https://github.com/kadavilrahul/generate_ssh_keys/blob/main/ssh-to-another-server.txt

## Installation

1. Clone this repository

```bash
git clone https://github.com/kadavilrahul/generate_html_from_csv
```
```bash
cd generate_html_from_csv
```

2. Install Apache and Postgres on new server if not already installed

```bash
bash apache_postgres.sh
```
3. Install SSL on the sever for your domain or subdomain if not already installed.
   Make sure to point the DNS correctly

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
Else create a blank file named replace.sh and paste the content provided to you to the file and then run replace.sh.
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
10. Transfer data and public folders to new server. Update DEST_SERVER and BASE_PATH in the script before running.

```bash
bash data/transfer.sh
```
11. Create poastgres database

```bash
bash data/create_database.sh
```

12. Import CSV products to postgres database

```bash
bash data/import_csv.sh
```

13. Check if data was imported sucessfully. Only firsst five products are see
    Check also the HTML page if search bar is functional

```bash
bash data/check_data.sh
```

14. Optionally install pgadmin to manage postgres database
    Else connect using remote database tool like dbeaver

```bash
bash data/install_pgadmin.sh
```

15. Add timestamps if needed
    
```bash
bash data/add_timestamps.sh
```

16. Cleanup

```bash
rm -rf /var/www/new.silkroademart.com/{*,.*}
```

```bash
rm -rf /root/generate_html_from_csv
```
