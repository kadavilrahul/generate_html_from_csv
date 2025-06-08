#!/bin/bash

# Install required dependencies
echo "Installing required dependencies..."
sudo apt install -y curl gnupg2

# Setup the repository
echo "Setting up pgAdmin repository..."
curl -fsS https://www.pgadmin.org/static/packages_pgadmin_org.pub | sudo gpg --dearmor -o /usr/share/keyrings/packages-pgadmin-org.gpg

# Add repository
sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/packages-pgadmin-org.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$(lsb_release -cs) pgadmin4 main" > /etc/apt/sources.list.d/pgadmin4.list'

# Update package list
echo "Updating package list..."
sudo apt update

# Install pgAdmin4
echo "Installing pgAdmin4..."
sudo apt install -y pgadmin4-web

# Configure pgAdmin4 web with automated responses
echo "Configuring pgAdmin4 web..."
# Create a temporary expect script
cat > /tmp/pgadmin_setup.exp << EOF
#!/usr/bin/expect -f
spawn sudo /usr/pgadmin4/bin/setup-web.sh
expect "Email address: "
send "kadavil.rahul@gmail.com\r"
expect "Password: "
send "Karimpadam2@\r"
expect "Retype password: "
send "Karimpadam2@\r"
expect "Do you wish to continue (y/n)?"
send "y\r"
expect "Continue (y/n)?"
send "y\r"
expect eof
EOF

# Make the expect script executable and run it
chmod +x /tmp/pgadmin_setup.exp
sudo apt-get install -y expect
/tmp/pgadmin_setup.exp

# Clean up
rm /tmp/pgadmin_setup.exp

echo "
pgAdmin4 installation completed!

Access pgAdmin4:
1. Open your web browser
2. Go to: http://your_server_ip/pgadmin4
3. Login with:
   - Email: kadavil.rahul@gmail.com
   - Password: products_2@

Database connection details:
- Host: localhost
- Port: 5432
- Database: products_db
- Username: products_user
- Password: products_2@
"
