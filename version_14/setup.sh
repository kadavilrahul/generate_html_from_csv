#!/bin/bash

# Minimalistic Static WooCommerce Setup Script
# Version: 2.0

set -e

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root"
    exit 1
fi

# Check prerequisites
check_prerequisites() {
    if ! command -v apache2 &> /dev/null; then
        echo "Error: Apache2 is not installed"
        exit 1
    fi
    
    # Enable mod_rewrite if not enabled
    if ! apache2ctl -M | grep -q rewrite_module; then
        echo "Enabling mod_rewrite..."
        a2enmod rewrite
    fi
}

# Detect domain folders
detect_domain_folders() {
    local folders=()
    
    # Look for common web directories
    for base_dir in /var/www /home /opt/www /usr/local/www; do
        if [[ -d "$base_dir" ]]; then
            while IFS= read -r -d '' folder; do
                if [[ -d "$folder" && "$folder" != "$base_dir" ]]; then
                    local domain_name=$(basename "$folder")
                    # Check if it looks like a domain (contains a dot)
                    if [[ "$domain_name" == *.* ]]; then
                        folders+=("$folder")
                    fi
                fi
            done < <(find "$base_dir" -maxdepth 1 -type d -print0 2>/dev/null)
        fi
    done
    
    printf '%s\n' "${folders[@]}"
}

# Get user inputs with domain detection
get_inputs() {
    # Check if domain and directory were passed as arguments
    if [[ -n "$1" && -n "$2" ]]; then
        DOMAIN="$1"
        WEBSITE_DIR="$2"
        echo "Using provided domain: $DOMAIN"
        echo "Using provided directory: $WEBSITE_DIR"
        
        # Check if admin email was also provided as third argument
        if [[ -n "$3" ]]; then
            ADMIN_EMAIL="$3"
            echo "Using provided admin email: $ADMIN_EMAIL"
            return 0
        fi
    else
        echo "Scanning for existing domain folders..."
        local domain_folders=()
        while IFS= read -r line; do
            [[ -n "$line" ]] && domain_folders+=("$line")
        done < <(detect_domain_folders)
        
        if [[ ${#domain_folders[@]} -gt 0 ]]; then
            echo "Found domain folders:"
            for i in "${!domain_folders[@]}"; do
                echo "  $((i+1)). ${domain_folders[i]}"
            done
            echo "  $((${#domain_folders[@]}+1)). Enter custom path"
            
            while true; do
                read -p "Select option: " choice
                if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le $((${#domain_folders[@]}+1)) ]]; then
                    if [[ "$choice" -le ${#domain_folders[@]} ]]; then
                        WEBSITE_DIR="${domain_folders[$((choice-1))]}"
                        DOMAIN=$(basename "$WEBSITE_DIR")
                        echo "Selected: $WEBSITE_DIR (Domain: $DOMAIN)"
                        break
                    else
                        echo "Enter custom path selected."
                        read -p "Enter website domain (e.g., example.com): " DOMAIN
                        read -p "Enter website directory (e.g., /var/www/example.com): " WEBSITE_DIR
                        break
                    fi
                else
                    echo "Invalid selection. Please try again."
                fi
            done
        else
            echo "No existing domain folders found."
            read -p "Enter website domain (e.g., example.com): " DOMAIN
            read -p "Enter website directory (e.g., /var/www/example.com): " WEBSITE_DIR
        fi
    fi
    
    read -p "Enter admin email: " ADMIN_EMAIL
    
    if [[ -z "$DOMAIN" || -z "$WEBSITE_DIR" || -z "$ADMIN_EMAIL" ]]; then
        echo "Error: All fields are required"
        exit 1
    fi
}

# Create directories
create_directories() {
    echo "Creating directories..."
    mkdir -p "$WEBSITE_DIR/public/products"
    mkdir -p "$WEBSITE_DIR/public/images"
    chown -R www-data:www-data "$WEBSITE_DIR/public"
    chmod -R 755 "$WEBSITE_DIR/public"
}

# Create Apache configuration
create_apache_config() {
    echo "Creating Apache configuration..."
    local config_file="/etc/apache2/sites-available/${DOMAIN}.conf"
    
    cat > "$config_file" <<EOF
<VirtualHost *:80>
    ServerAdmin $ADMIN_EMAIL
    ServerName $DOMAIN
    ServerAlias www.$DOMAIN
    DocumentRoot $WEBSITE_DIR

    <Directory $WEBSITE_DIR>
        AllowOverride All
        Options -Indexes +FollowSymLinks
        Require all granted
        DirectoryIndex index.html index.php
    </Directory>

    Alias /products $WEBSITE_DIR/public/products
    <Directory $WEBSITE_DIR/public/products>
        AllowOverride All
        Options -Indexes +FollowSymLinks
        Require all granted
        DirectoryIndex index.html
    </Directory>

    Alias /images $WEBSITE_DIR/public/images
    <Directory $WEBSITE_DIR/public/images>
        Options -Indexes +FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/error_${DOMAIN}.log
    CustomLog \${APACHE_LOG_DIR}/access_${DOMAIN}.log combined
</VirtualHost>
EOF
}

# Create .htaccess
create_htaccess() {
    echo "Creating .htaccess..."
    cat > "$WEBSITE_DIR/public/products/.htaccess" <<EOF
DirectoryIndex index.html index.php
Options -Indexes

RewriteEngine On
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^([^/]+)/?$ \$1.html [L]

<IfModule mod_expires.c>
    ExpiresActive On
    ExpiresByType text/html "access plus 1 day"
    ExpiresByType image/jpg "access plus 1 month"
    ExpiresByType image/jpeg "access plus 1 month"
    ExpiresByType image/png "access plus 1 month"
    ExpiresByType image/webp "access plus 1 month"
</IfModule>

<Files "*.csv">
    Order Allow,Deny
    Deny from all
</Files>
EOF
    chown www-data:www-data "$WEBSITE_DIR/public/products/.htaccess"
    chmod 644 "$WEBSITE_DIR/public/products/.htaccess"
}

# Enable site
enable_site() {
    echo "Enabling Apache site..."
    a2ensite "${DOMAIN}.conf"
    apache2ctl configtest
    systemctl reload apache2
}

# Main execution
main() {
    echo "Static WooCommerce Setup Script"
    echo "==============================="
    
    check_prerequisites
    get_inputs "$1" "$2" "$3"
    create_directories
    create_apache_config
    create_htaccess
    enable_site
    
    echo ""
    echo "Setup complete!"
    echo "Domain: $DOMAIN"
    echo "Directory: $WEBSITE_DIR"
    echo "Products URL: http://$DOMAIN/products/"
    echo "Images URL: http://$DOMAIN/images/"
    echo ""
    echo "Use ./run.sh to generate product pages"
}

main "$@"