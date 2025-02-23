# Update package list
echo "Updating package list..."
sudo apt update

# Install all required packages
echo "Installing required packages..."
sudo apt install -y \
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
    php-pgsql

# Restart Apache to apply PHP changes
echo "Restarting Apache..."
sudo systemctl restart apache2

# Start and enable PostgreSQL service
echo "Starting PostgreSQL service..."
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Check PostgreSQL status
if sudo systemctl is-active --quiet postgresql; then
    echo "✓ PostgreSQL is running successfully"
    echo "✓ PostgreSQL version:"
    psql --version
else
    echo "✗ Error: PostgreSQL installation failed"
    exit 1
fi

echo "
All packages installed successfully!

Next steps:
1. Create database:    bash data/create_database.sh
2. Import CSV data:    bash data/import_csv.sh
3. Verify data:        bash data/check_data.sh
"
