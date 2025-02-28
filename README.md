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
https://github.com/kadavilrahul/generate_ssh_keys/blob/main/ssh-root-to-root-another-server.sh

## Installation

1. Move to the folder in terminal where you want to generate HTML files.

    Example: The domain folder where SSL is installed, 
    
    `/var/www/your_domain.com`

    Create new folder if not already present.
    Open the folder in VS code to easily modify files and use terminal (Optional)

2. Clone this repository files again to the current location. (Delete any unwanted files in the location first if it exists)

```bash
git clone https://github.com/kadavilrahul/generate_html_from_csv .
```

3. Modify following lines in setup.sh
```bash 
706, 707, 769, 519, 520, 548, 549, 550, 551
```
- Else create a blank file named replace.sh and paste the content provided to you into the file and then run replace.sh.
- Note: Do not copy paste the file itself using SFTP rather use nano command so that permission issue doesn't arise.
Run:
```bash 
nano replace.sh
```
- Copy contents using CTRl+C and paste using right click to paste contents
- Then Run:
```bash 
bash replace.sh
```

4. Create HTML products

```bash
bash setup.sh
```

5. Transfer data and public folders to new server.
- Update DEST_SERVER and BASE_PATH in the transfer.sh script before running.
- Check if root is enabled on destination server

```bash
bash data/transfer.sh
```

6. Update SSL to serve static HTML pages. Open this file and follow instructions.
Modify the domain name

```bash
data/SSL_for_static_HTML.txt

bash data/update_apache_config.sh
```

7. On the new server run package installation script

```bash 
bash data/packages.sh
```

7. Convert products_database.xml to products_database.csv so that it can be uploaded to database

```bash
bash data/convert.sh
```

8. Create poastgres database

```bash
bash data/create_database.sh
```

9. Import CSV products to postgres database

```bash
bash data/import_csv.sh
```

10. Check if data was imported sucessfully. Only first five products will be visible.
- Update the database credentials in search.php especially MySQL database
- Check also the HTML page if search bar is functional

```bash
bash data/check_data.sh
```

12. Run HTML pages count script and check if data is updated on data/public_files_count.log

```bash
bash data/count_public_files.sh
```

## Optional commands

1. Install SSL on the server for your domain or subdomain if not already installed.
   Make sure to point the DNS correctly

```bash
bash maindomain.sh
```
      or

```bash
bash subdomain.sh
```

2. Install pgadmin to manage postgres database. Else connect using remote database tool like dbeaver.

```bash
bash data/install_pgadmin.sh
```

3. Add timestamps if needed
    
```bash
bash data/add_timestamps.sh
```

4. Cleanup

```bash
rm -rf /var/www/your_domain.com/{*,.*}
```

```bash
rm -rf /root/generate_html_from_csv
```
