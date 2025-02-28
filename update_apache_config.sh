#!/bin/bash

# Check if domain name is provided
if [ -z "$1" ]; then
    echo "Usage: $0 domain_name"
    echo "Example: $0 silkroademart.com"
    exit 1
fi

# Set domain name from argument
DOMAIN=$1

# Set file paths
CONFIG_FILE="/etc/apache2/sites-enabled/${DOMAIN}.conf"
BACKUP_FILE="/etc/apache2/sites-enabled/${DOMAIN}.conf.bak.$(date +%Y%m%d%H%M%S)"

# Check if the original file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file $CONFIG_FILE does not exist."
    exit 1
fi

# Create backup
echo "Creating backup of $CONFIG_FILE to $BACKUP_FILE"
cp "$CONFIG_FILE" "$BACKUP_FILE"

if [ $? -ne 0 ]; then
    echo "Error: Failed to create backup. Check permissions."
    exit 1
fi

# Create new configuration file
echo "Creating new configuration file for $DOMAIN"
cat > "$CONFIG_FILE" << EOF
<VirtualHost *:80>
    ServerAdmin silkroademart@gmail.com
    ServerName ${DOMAIN}
    ServerAlias www.${DOMAIN}
    DocumentRoot /var/www/${DOMAIN}

    <Directory /var/www/${DOMAIN}>
        AllowOverride All
        Require all granted
    </Directory>

    # Exclude /products folder from being processed by WordPress
    Alias /products /var/www/${DOMAIN}/products
    <Directory /var/www/${DOMAIN}/products>
        Options Indexes FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/error_${DOMAIN}.log
    CustomLog \${APACHE_LOG_DIR}/access_${DOMAIN}.log combined

    RewriteEngine on
    RewriteCond %{SERVER_NAME} =${DOMAIN} [OR]
    RewriteCond %{SERVER_NAME} =www.${DOMAIN}
    RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URI} [L,NE,R=permanent]
</VirtualHost>
EOF

if [ $? -ne 0 ]; then
    echo "Error: Failed to create new configuration file. Check permissions."
    echo "Restoring backup..."
    cp "$BACKUP_FILE" "$CONFIG_FILE"
    exit 1
fi

echo "Configuration updated successfully."
echo "Backup saved as $BACKUP_FILE"
echo "To apply changes, restart Apache with: sudo systemctl restart apache2"

exit 0
