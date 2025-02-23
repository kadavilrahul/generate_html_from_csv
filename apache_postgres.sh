#!/bin/bash
# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Set non-interactive mode for apt
export DEBIAN_FRONTEND=noninteractive

# Update package lists
apt-get update -y

# Install Apache2
apt-get install -y apache2

# Install PostgreSQL and its requirements
apt-get install -y postgresql-common
/usr/share/postgresql-common/pgdg/apt.postgresql.org.sh
apt-get install -y postgresql

# Install PHP and common extensions
apt-get install php php-fpm libapache2-mod-php php-pgsql php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip -y
a2enmod proxy_fcgi setenvif
a2enconf php8.3-fpm  # Adjust version if needed
systemctl restart apache2

# Configure Apache to prioritize PHP files
sed -i 's/index.html/index.php/' /etc/apache2/mods-enabled/dir.conf

# Enable Apache modules
a2enmod rewrite

# Start PostgreSQL service
systemctl start postgresql

# Configure PostgreSQL
# Switch to postgres user and create a new database user
su - postgres -c "psql -c \"ALTER USER postgres WITH PASSWORD 'Karimpadam2@';\""
su - postgres -c "createdb mydb"  # Create a default database

# Create a test PHP info file
echo "<?php phpinfo(); ?>" > /var/www/html/info.php

# Restart services
systemctl restart apache2
systemctl restart postgresql

# Print completion message
echo "LAMP stack with PostgreSQL installed successfully!"
echo "PostgreSQL postgres user password is set to: Karimpadam2@"
echo "PHP info page is available at: http://IPaddress/info.php"
echo "Test commands:"
echo "sudo systemctl status apache2"
echo "sudo systemctl status postgresql"
echo "php --version"
echo "psql --version"
