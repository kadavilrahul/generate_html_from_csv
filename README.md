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

```bash
bash data/transfer.sh
```

6. Install Apache and Postgres on new server if not already installed

```bash
bash data/apache_postgres.sh
```

7. On the new server run package installation script

```bash 
bash data/packages.sh
```

8. Install SSL on the server for your domain or subdomain if not already installed.
   Make sure to point the DNS correctly

```bash
bash maindomain.sh
```
      or

```bash
bash subdomain.sh
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
- Check also the HTML page if search bar is functional

```bash
bash data/check_data.sh
```

13. Optionally install pgadmin to manage postgres database
- Else connect using remote database tool like dbeaver

```bash
bash data/install_pgadmin.sh
```

14. Add timestamps if needed
    
```bash
bash data/add_timestamps.sh
```

15. Cleanup

```bash
rm -rf /var/www/your_domain.com/{*,.*}
```

```bash
rm -rf /root/generate_html_from_csv
```
