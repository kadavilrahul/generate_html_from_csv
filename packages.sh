#!/bin/bash

# Set non-interactive mode for apt
export DEBIAN_FRONTEND=noninteractive

# Update package list
echo "Updating package list..."
sudo apt-get update -y

# Install required packages
echo "Installing required packages..."
sudo apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    nodejs \
    npm \
    python3 \
    python3-pip \
    postgresql \
    postgresql-contrib \
    libpq-dev \
    apache2 \
    php \
    php-fpm \
    libapache2-mod-php \
    php-pgsql \
    php-curl \
    php-gd \
    php-mbstring \
    php-xml \
    php-xmlrpc \
    php-soap \
    php-intl \
    xmlstarlet \
    php-zip

# Enable Apache modules and PHP-FPM
echo "Configuring Apache for PHP..."
sudo a2enmod proxy_fcgi setenvif
sudo a2enconf php*-fpm  # Adjusts for any installed PHP version
sudo a2enmod rewrite
sudo systemctl restart apache2

# Ensure Apache prioritizes index.php over index.html
echo "Setting Apache directory index preference..."
sudo sed -i 's/index.html/index.php/' /etc/apache2/mods-enabled/dir.conf

# Start and enable PostgreSQL service
echo "Starting PostgreSQL service..."
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Secure PostgreSQL setup
echo "Configuring PostgreSQL user and database..."
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '$(openssl rand -base64 12)';"
sudo -u postgres psql -c "CREATE DATABASE mydb;"

# Create a test PHP info file
echo "Creating test PHP info page..."
echo "<?php phpinfo(); ?>" | sudo tee /var/www/html/info.php > /dev/null

# Restart services to apply changes
echo "Restarting services..."
sudo systemctl restart apache2
sudo systemctl restart postgresql

# Check PostgreSQL status
if sudo systemctl is-active --quiet postgresql; then
    echo "✓ PostgreSQL is running successfully"
    echo "✓ PostgreSQL version: $(psql --version)"
else
    echo "✗ Error: PostgreSQL installation failed"
    exit 1
fi

echo "✓ All packages installed and configured successfully!"
