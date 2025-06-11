#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging configuration
LOG_FILE="./product_generator.log"
SETUP_MARKER_FILE="./.setup_completed"

# Function to log messages with IST timestamp
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(TZ='Asia/Kolkata' date '+%Y-%m-%d %H:%M:%S IST')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    # Also display to console with colors
    case $level in
        "INFO")
            echo -e "${BLUE}[$timestamp] [INFO] $message${NC}"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[$timestamp] [SUCCESS] $message${NC}"
            ;;
        "WARNING")
            echo -e "${YELLOW}[$timestamp] [WARNING] $message${NC}"
            ;;
        "ERROR")
            echo -e "${RED}[$timestamp] [ERROR] $message${NC}"
            ;;
        *)
            echo -e "[$timestamp] [$level] $message"
            ;;
    esac
}

# Function to check if setup.sh was run previously
check_setup_completion() {
    if [[ -f "$SETUP_MARKER_FILE" ]]; then
        log_message "INFO" "Setup marker file found - setup.sh was run previously"
        return 0  # Setup was completed
    else
        log_message "WARNING" "Setup marker file not found - setup.sh may not have been run"
        return 1  # Setup not completed
    fi
}

# Function to run setup.sh
run_setup_script() {
    if [[ -f "./setup.sh" ]]; then
        log_message "INFO" "Running setup.sh script..."
        echo -e "\n${BLUE}=== Running Website Setup ===${NC}"
        
        # Make setup.sh executable
        chmod +x ./setup.sh
        
        # Run setup.sh
        if sudo ./setup.sh; then
            # Create setup completion marker
            touch "$SETUP_MARKER_FILE"
            log_message "SUCCESS" "setup.sh completed successfully - marker file created"
            echo -e "${GREEN}✓ Website setup completed successfully${NC}"
        else
            log_message "ERROR" "setup.sh failed to complete"
            echo -e "${RED}✗ Website setup failed${NC}"
            exit 1
        fi
    else
        log_message "ERROR" "setup.sh file not found in current directory"
        echo -e "${RED}Error: setup.sh file not found in current directory${NC}"
        echo "Please ensure setup.sh is in the same directory as run.sh"
        exit 1
    fi
}

# Function to check if PostgreSQL is installed
check_postgresql_installed() {
    if command -v psql >/dev/null 2>&1 && command -v pg_config >/dev/null 2>&1; then
        return 0  # PostgreSQL is installed
    else
        return 1  # PostgreSQL is not installed
    fi
}

# Function to install PostgreSQL
install_postgresql() {
    log_message "INFO" "Starting PostgreSQL installation"
    echo -e "\n${BLUE}=== PostgreSQL Installation ===${NC}"
    echo -e "${YELLOW}PostgreSQL is not installed. Installing now...${NC}"
    
    # Detect the operating system
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        log_message "ERROR" "Cannot detect operating system"
        echo -e "${RED}Cannot detect operating system. Please install PostgreSQL manually.${NC}"
        exit 1
    fi
    
    log_message "INFO" "Detected operating system: $OS"
    case $OS in
        ubuntu|debian)
            log_message "INFO" "Installing PostgreSQL on Ubuntu/Debian system"
            echo -e "${BLUE}Detected Ubuntu/Debian system. Installing PostgreSQL...${NC}"
            
            # Update package list
            echo -e "${BLUE}Updating package list...${NC}"
            sudo apt update
            
            # Install PostgreSQL and contrib package
            echo -e "${BLUE}Installing PostgreSQL...${NC}"
            sudo apt install -y postgresql postgresql-contrib
            
            # Start and enable PostgreSQL service
            echo -e "${BLUE}Starting PostgreSQL service...${NC}"
            sudo systemctl start postgresql
            sudo systemctl enable postgresql
            
            log_message "SUCCESS" "PostgreSQL installed successfully on Ubuntu/Debian"
            echo -e "${GREEN}✓ PostgreSQL installed successfully${NC}"
            ;;
            
        centos|rhel|fedora)
            log_message "INFO" "Installing PostgreSQL on CentOS/RHEL/Fedora system"
            echo -e "${BLUE}Detected CentOS/RHEL/Fedora system. Installing PostgreSQL...${NC}"
            
            if command -v dnf >/dev/null 2>&1; then
                # Fedora or newer CentOS/RHEL with dnf
                sudo dnf update -y
                sudo dnf install -y postgresql postgresql-server postgresql-contrib
            elif command -v yum >/dev/null 2>&1; then
                # Older CentOS/RHEL with yum
                sudo yum update -y
                sudo yum install -y postgresql postgresql-server postgresql-contrib
            else
                log_message "ERROR" "Package manager not found on CentOS/RHEL/Fedora"
                echo -e "${RED}Package manager not found. Please install PostgreSQL manually.${NC}"
                exit 1
            fi
            
            # Initialize database (required for CentOS/RHEL)
            echo -e "${BLUE}Initializing PostgreSQL database...${NC}"
            sudo postgresql-setup initdb
            
            # Start and enable PostgreSQL service
            echo -e "${BLUE}Starting PostgreSQL service...${NC}"
            sudo systemctl start postgresql
            sudo systemctl enable postgresql
            
            log_message "SUCCESS" "PostgreSQL installed successfully on CentOS/RHEL/Fedora"
            echo -e "${GREEN}✓ PostgreSQL installed successfully${NC}"
            ;;
            
        arch|manjaro)
            log_message "INFO" "Installing PostgreSQL on Arch/Manjaro system"
            echo -e "${BLUE}Detected Arch/Manjaro system. Installing PostgreSQL...${NC}"
            
            # Update package database
            sudo pacman -Sy
            
            # Install PostgreSQL
            sudo pacman -S --noconfirm postgresql
            
            # Initialize database
            echo -e "${BLUE}Initializing PostgreSQL database...${NC}"
            sudo -u postgres initdb -D /var/lib/postgres/data
            
            # Start and enable PostgreSQL service
            echo -e "${BLUE}Starting PostgreSQL service...${NC}"
            sudo systemctl start postgresql
            sudo systemctl enable postgresql
            
            log_message "SUCCESS" "PostgreSQL installed successfully on Arch/Manjaro"
            echo -e "${GREEN}✓ PostgreSQL installed successfully${NC}"
            ;;
            
        *)
            log_message "ERROR" "Unsupported operating system: $OS"
            echo -e "${RED}Unsupported operating system: $OS${NC}"
            echo -e "${YELLOW}Please install PostgreSQL manually using your system's package manager:${NC}"
            echo "  - Ubuntu/Debian: sudo apt install postgresql postgresql-contrib"
            echo "  - CentOS/RHEL: sudo yum install postgresql postgresql-server postgresql-contrib"
            echo "  - Fedora: sudo dnf install postgresql postgresql-server postgresql-contrib"
            echo "  - Arch: sudo pacman -S postgresql"
            exit 1
            ;;
    esac
    
    # Verify installation
    log_message "INFO" "Verifying PostgreSQL installation"
    echo -e "\n${BLUE}Verifying PostgreSQL installation...${NC}"
    if check_postgresql_installed; then
        log_message "SUCCESS" "PostgreSQL installation verified"
        echo -e "${GREEN}✓ PostgreSQL installation verified${NC}"
        
        # Check service status
        if sudo systemctl is-active --quiet postgresql; then
            log_message "SUCCESS" "PostgreSQL service is running"
            echo -e "${GREEN}✓ PostgreSQL service is running${NC}"
        else
            log_message "WARNING" "PostgreSQL service is not running - attempting to start"
            echo -e "${YELLOW}⚠ PostgreSQL service is not running. Attempting to start...${NC}"
            sudo systemctl start postgresql
            if sudo systemctl is-active --quiet postgresql; then
                log_message "SUCCESS" "PostgreSQL service started successfully"
                echo -e "${GREEN}✓ PostgreSQL service started successfully${NC}"
            else
                log_message "ERROR" "Failed to start PostgreSQL service"
                echo -e "${RED}✗ Failed to start PostgreSQL service${NC}"
                echo -e "${YELLOW}Please check the service status manually: sudo systemctl status postgresql${NC}"
            fi
        fi
        
        # Display PostgreSQL version
        pg_version=$(sudo -u postgres psql -c "SELECT version();" 2>/dev/null | grep PostgreSQL | head -1)
        if [[ -n "$pg_version" ]]; then
            log_message "INFO" "PostgreSQL version: $pg_version"
            echo -e "${BLUE}Installed version: ${pg_version}${NC}"
        fi
        
    else
        log_message "ERROR" "PostgreSQL installation verification failed"
        echo -e "${RED}✗ PostgreSQL installation verification failed${NC}"
        echo -e "${YELLOW}Please check the installation manually${NC}"
        exit 1
    fi
}

# Function to search for domain folders in /var/www/
search_domain_folders() {
    local www_dir="/var/www"
    local folders=()
    
    if [[ -d "$www_dir" ]]; then
        echo -e "${BLUE}Searching for domain folders in $www_dir...${NC}"
        
        # Find directories that look like domains (contain dots and are not system folders)
        while IFS= read -r -d '' folder; do
            local basename_folder=$(basename "$folder")
            # Check if folder name contains a dot and is not a system folder
            if [[ "$basename_folder" == *.* ]] && [[ "$basename_folder" != "html" ]] && [[ "$basename_folder" != "." ]] && [[ "$basename_folder" != ".." ]]; then
                # Additional check: make sure it's a directory and readable
                if [[ -d "$folder" ]] && [[ -r "$folder" ]]; then
                    folders+=("$folder")
                fi
            fi
        done < <(find "$www_dir" -maxdepth 1 -type d -print0 2>/dev/null)
        
        # Sort folders alphabetically
        IFS=$'\n' folders=($(sort <<<"${folders[*]}"))
        unset IFS
        
        if [[ ${#folders[@]} -gt 0 ]]; then
            echo -e "${GREEN}Found ${#folders[@]} domain folder(s):${NC}"
            echo
            
            # Display options
            for i in "${!folders[@]}"; do
                local folder_name=$(basename "${folders[$i]}")
                echo "  $((i+1)). ${folders[$i]} (domain: $folder_name)"
            done
            echo "  $((${#folders[@]}+1)). Enter custom path"
            echo
            
            while true; do
                read -p "Select an option (1-$((${#folders[@]}+1))): " choice
                
                if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le $((${#folders[@]}+1)) ]]; then
                    if [[ "$choice" -eq $((${#folders[@]}+1)) ]]; then
                        # Custom path option
                        read -p "Please provide the folder location (e.g., /var/www/yourwebsite.com): " folder_location
                        break
                    else
                        # Selected from list
                        folder_location="${folders[$((choice-1))]}"
                        echo -e "${GREEN}Selected: $folder_location${NC}"
                        break
                    fi
                else
                    echo -e "${RED}Invalid choice. Please select a number between 1 and $((${#folders[@]}+1)).${NC}"
                fi
            done
        else
            echo -e "${YELLOW}No domain folders found in $www_dir${NC}"
            echo "Looking for folders with domain-like names (containing dots)..."
            read -p "Please provide the folder location (e.g., /var/www/yourwebsite.com): " folder_location
        fi
    else
        echo -e "${YELLOW}Directory $www_dir does not exist.${NC}"
        read -p "Please provide the folder location (e.g., /var/www/yourwebsite.com): " folder_location
    fi
}

# Initialize log file
log_message "INFO" "=== Product Page Generator Started ==="
log_message "INFO" "Script version: $(date '+%Y%m%d')"
log_message "INFO" "Working directory: $(pwd)"

echo -e "${BLUE}=== Product Page Generator with Database Integration ===${NC}"
echo "This script will generate HTML pages and populate your search database."
echo "Features: Auto PostgreSQL installation, database setup, HTML generation, and search functionality."
echo

# Check if setup.sh was run previously
if ! check_setup_completion; then
    echo -e "\n${YELLOW}=== Website Setup Check ===${NC}"
    echo -e "${YELLOW}It appears that setup.sh has not been run previously.${NC}"
    echo "setup.sh configures Apache virtual hosts, directories, and .htaccess files."
    echo
    echo "Do you want to run setup.sh now? This will:"
    echo "  • Configure Apache virtual host for your domain"
    echo "  • Create necessary directories (/public/products, /public/images)"
    echo "  • Set up .htaccess files for URL rewriting"
    echo "  • Enable the Apache site configuration"
    echo
    
    while true; do
        read -p "Run setup.sh? (y/n): " setup_choice
        case $setup_choice in
            [Yy]* )
                log_message "INFO" "User chose to run setup.sh"
                run_setup_script
                break
                ;;
            [Nn]* )
                log_message "WARNING" "User chose to skip setup.sh"
                echo -e "${YELLOW}⚠ Skipping setup.sh - make sure your web server is configured properly${NC}"
                echo "You can run setup.sh later if needed."
                break
                ;;
            * )
                echo "Please answer yes (y) or no (n)."
                ;;
        esac
    done
else
    log_message "INFO" "Setup completion verified - proceeding with generation"
    echo -e "${GREEN}✓ Website setup was completed previously${NC}"
fi

# Search for domain folders and get user selection
log_message "INFO" "Starting domain folder search"
search_domain_folders

log_message "INFO" "Selected folder location: $folder_location"

# Validate folder location input
if [[ -z "$folder_location" ]]; then
    log_message "ERROR" "Folder location is empty"
    echo -e "${RED}Error: Folder location cannot be empty.${NC}"
    exit 1
fi

# Extract domain from folder location for database operations
domain=$(basename "$folder_location")
log_message "INFO" "Detected domain: $domain"
echo -e "${BLUE}Detected domain: $domain${NC}"

# Create the folder if it doesn't exist
if [[ ! -d "$folder_location" ]]; then
    log_message "INFO" "Creating directory: $folder_location"
    echo -e "${YELLOW}Creating directory: $folder_location${NC}"
    sudo mkdir -p "$folder_location"
    log_message "SUCCESS" "Directory created successfully: $folder_location"
    echo -e "${GREEN}Directory created successfully.${NC}"
else
    log_message "INFO" "Directory already exists: $folder_location"
    echo -e "${GREEN}Directory already exists: $folder_location${NC}"
fi
# Check and install PostgreSQL if needed
log_message "INFO" "Checking PostgreSQL installation"
echo -e "\n${BLUE}=== Checking PostgreSQL Installation ===${NC}"
if check_postgresql_installed; then
    log_message "SUCCESS" "PostgreSQL is already installed"
    echo -e "${GREEN}✓ PostgreSQL is already installed${NC}"
    
    # Check if service is running
    if sudo systemctl is-active --quiet postgresql; then
        log_message "SUCCESS" "PostgreSQL service is running"
        echo -e "${GREEN}✓ PostgreSQL service is running${NC}"
    else
        log_message "WARNING" "PostgreSQL service is not running - attempting to start"
        echo -e "${YELLOW}⚠ PostgreSQL service is not running. Starting it...${NC}"
        sudo systemctl start postgresql
        if sudo systemctl is-active --quiet postgresql; then
            log_message "SUCCESS" "PostgreSQL service started successfully"
            echo -e "${GREEN}✓ PostgreSQL service started${NC}"
        else
            log_message "ERROR" "Failed to start PostgreSQL service"
            echo -e "${RED}✗ Failed to start PostgreSQL service${NC}"
            echo -e "${YELLOW}Please check: sudo systemctl status postgresql${NC}"
        fi
    fi
else
    log_message "WARNING" "PostgreSQL is not installed - starting installation"
    install_postgresql
fi

# Function to check if PostgreSQL is installed
check_postgresql_installed() {
    if command -v psql >/dev/null 2>&1 && command -v pg_config >/dev/null 2>&1; then
        return 0  # PostgreSQL is installed
    else
        return 1  # PostgreSQL is not installed
    fi
}

# Function to install PostgreSQL
install_postgresql() {
    log_message "INFO" "Starting PostgreSQL installation"
    echo -e "\n${BLUE}=== PostgreSQL Installation ===${NC}"
    echo -e "${YELLOW}PostgreSQL is not installed. Installing now...${NC}"
    
    # Detect the operating system
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        log_message "ERROR" "Cannot detect operating system"
        echo -e "${RED}Cannot detect operating system. Please install PostgreSQL manually.${NC}"
        exit 1
    fi
    
    case $OS in
        ubuntu|debian)
            log_message "INFO" "Detected Ubuntu/Debian system - installing PostgreSQL"
            echo -e "${BLUE}Detected Ubuntu/Debian system. Installing PostgreSQL...${NC}"
            
            # Update package list
            echo -e "${BLUE}Updating package list...${NC}"
            sudo apt update
            
            # Install PostgreSQL and contrib package
            echo -e "${BLUE}Installing PostgreSQL...${NC}"
            sudo apt install -y postgresql postgresql-contrib
            
            # Start and enable PostgreSQL service
            echo -e "${BLUE}Starting PostgreSQL service...${NC}"
            sudo systemctl start postgresql
            sudo systemctl enable postgresql
            
            log_message "SUCCESS" "PostgreSQL installed successfully on Ubuntu/Debian"
            echo -e "${GREEN}✓ PostgreSQL installed successfully${NC}"
            ;;
            
        centos|rhel|fedora)
            log_message "INFO" "Detected CentOS/RHEL/Fedora system - installing PostgreSQL"
            echo -e "${BLUE}Detected CentOS/RHEL/Fedora system. Installing PostgreSQL...${NC}"
            
            if command -v dnf >/dev/null 2>&1; then
                # Fedora or newer CentOS/RHEL with dnf
                sudo dnf update -y
                sudo dnf install -y postgresql postgresql-server postgresql-contrib
            elif command -v yum >/dev/null 2>&1; then
                # Older CentOS/RHEL with yum
                sudo yum update -y
                sudo yum install -y postgresql postgresql-server postgresql-contrib
            else
                log_message "ERROR" "Package manager not found on CentOS/RHEL/Fedora"
                echo -e "${RED}Package manager not found. Please install PostgreSQL manually.${NC}"
                exit 1
            fi
            
            # Initialize database (required for CentOS/RHEL)
            echo -e "${BLUE}Initializing PostgreSQL database...${NC}"
            sudo postgresql-setup initdb
            
            # Start and enable PostgreSQL service
            echo -e "${BLUE}Starting PostgreSQL service...${NC}"
            sudo systemctl start postgresql
            sudo systemctl enable postgresql
            
            log_message "SUCCESS" "PostgreSQL installed successfully on CentOS/RHEL/Fedora"
            echo -e "${GREEN}✓ PostgreSQL installed successfully${NC}"
            ;;
            
        arch|manjaro)
            log_message "INFO" "Detected Arch/Manjaro system - installing PostgreSQL"
            echo -e "${BLUE}Detected Arch/Manjaro system. Installing PostgreSQL...${NC}"
            
            # Update package database
            sudo pacman -Sy
            
            # Install PostgreSQL
            sudo pacman -S --noconfirm postgresql
            
            # Initialize database
            echo -e "${BLUE}Initializing PostgreSQL database...${NC}"
            sudo -u postgres initdb -D /var/lib/postgres/data
            
            # Start and enable PostgreSQL service
            echo -e "${BLUE}Starting PostgreSQL service...${NC}"
            sudo systemctl start postgresql
            sudo systemctl enable postgresql
            
            log_message "SUCCESS" "PostgreSQL installed successfully on Arch/Manjaro"
            echo -e "${GREEN}✓ PostgreSQL installed successfully${NC}"
            ;;
            
        *)
            log_message "ERROR" "Unsupported operating system: $OS"
            echo -e "${RED}Unsupported operating system: $OS${NC}"
            echo -e "${YELLOW}Please install PostgreSQL manually using your system's package manager:${NC}"
            echo "  - Ubuntu/Debian: sudo apt install postgresql postgresql-contrib"
            echo "  - CentOS/RHEL: sudo yum install postgresql postgresql-server postgresql-contrib"
            echo "  - Fedora: sudo dnf install postgresql postgresql-server postgresql-contrib"
            echo "  - Arch: sudo pacman -S postgresql"
            exit 1
            ;;
    esac
    
    # Verify installation
    log_message "INFO" "Verifying PostgreSQL installation"
    echo -e "\n${BLUE}Verifying PostgreSQL installation...${NC}"
    if check_postgresql_installed; then
        log_message "SUCCESS" "PostgreSQL installation verified successfully"
        echo -e "${GREEN}✓ PostgreSQL installation verified${NC}"
        
        # Check service status
        if sudo systemctl is-active --quiet postgresql; then
            log_message "SUCCESS" "PostgreSQL service is running after installation"
            echo -e "${GREEN}✓ PostgreSQL service is running${NC}"
        else
            log_message "WARNING" "PostgreSQL service not running after installation - attempting to start"
            echo -e "${YELLOW}⚠ PostgreSQL service is not running. Attempting to start...${NC}"
            sudo systemctl start postgresql
            if sudo systemctl is-active --quiet postgresql; then
                log_message "SUCCESS" "PostgreSQL service started successfully after installation"
                echo -e "${GREEN}✓ PostgreSQL service started successfully${NC}"
            else
                log_message "ERROR" "Failed to start PostgreSQL service after installation"
                echo -e "${RED}✗ Failed to start PostgreSQL service${NC}"
                echo -e "${YELLOW}Please check the service status manually: sudo systemctl status postgresql${NC}"
            fi
        fi
        
        # Display PostgreSQL version
        pg_version=$(sudo -u postgres psql -c "SELECT version();" 2>/dev/null | grep PostgreSQL | head -1)
        if [[ -n "$pg_version" ]]; then
            log_message "INFO" "PostgreSQL version: $pg_version"
            echo -e "${BLUE}Installed version: ${pg_version}${NC}"
        fi
        
    else
        log_message "ERROR" "PostgreSQL installation verification failed"
        echo -e "${RED}✗ PostgreSQL installation verification failed${NC}"
        echo -e "${YELLOW}Please check the installation manually${NC}"
        exit 1
    fi
}
            sed -i "s/'dbname'   => 'your_db_name'/'dbname'   => '$db_name'/g" "$search_php_dest"
            sed -i "s/'user'    => 'your_user_name'/'user'    => '$db_user'/g" "$search_php_dest"
            sed -i "s/'password' => 'your_password'/'password' => '$db_password'/g" "$search_php_dest"
            
            echo -e "${GREEN}✓ search.php updated and copied to: $search_php_dest${NC}"
            echo -e "${BLUE}Database configuration updated with:${NC}"
            echo "  - Database: $db_name"
            echo "  - User: $db_user"
            echo "  - Password: [hidden]"
        else
            echo -e "${RED}✗ Could not extract database credentials for search.php update${NC}"
            # Still copy the file but without updates
            cp "$search_php_source" "$search_php_dest"
            echo -e "${YELLOW}⚠ search.php copied but database credentials need manual update${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ search.php not found in current directory${NC}"
        echo "  Please ensure search.php is in the same directory as this script"
    fi
}

# Database Setup Functions

sanitize_db_name() {
    local domain=$1
    echo "${domain//[.-]/_}" | tr '[:upper:]' '[:lower:]'
}

generate_password() {
    local domain=$1
    echo "$(sanitize_db_name $domain)_$(openssl rand -hex 8)"
}

check_database_exists() {
    local domain=$1
    local credentials_file="./database_credentials.conf"
    
    if [[ -f "$credentials_file" ]]; then
        if grep -q "Domain: $domain" "$credentials_file"; then
            return 0  # Database exists
        fi
    fi
    return 1  # Database doesn't exist
}

setup_database() {
    local domain=$1
    local db_name="$(sanitize_db_name $domain)_db"
    local db_user="$(sanitize_db_name $domain)_user"
    local db_password="$(generate_password $domain)"

    log_message "INFO" "Starting database setup for domain: $domain"
    echo -e "\n${YELLOW}=== Database Setup ===${NC}"
    echo -e "${BLUE}Setting up database for domain: $domain${NC}"
    echo "Database name: $db_name"
    echo "Username: $db_user"

    # Create credentials file if it doesn't exist
    touch ./database_credentials.conf
    chmod 600 ./database_credentials.conf

    log_message "INFO" "Storing database credentials in configuration file"
    # Store credentials in configuration file
    echo "Domain: $domain" >> ./database_credentials.conf
    echo "Database: $db_name" >> ./database_credentials.conf
    echo "Username: $db_user" >> ./database_credentials.conf
    echo "Password: $db_password" >> ./database_credentials.conf
    echo "----------------------------------------" >> ./database_credentials.conf

    log_message "INFO" "Creating PostgreSQL database and user"
    # Create database and user
    sudo -u postgres psql <<EOF
-- Create database and user
CREATE DATABASE $db_name;
CREATE USER $db_user WITH PASSWORD '$db_password';
GRANT ALL PRIVILEGES ON DATABASE $db_name TO $db_user;
\c $db_name
GRANT ALL ON SCHEMA public TO $db_user;
ALTER USER $db_user WITH SUPERUSER;

-- Create products table
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255),
    price INTEGER,
    product_link TEXT,
    category VARCHAR(100),
    image_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better search performance
CREATE INDEX IF NOT EXISTS idx_products_title ON products(title);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);
CREATE INDEX IF NOT EXISTS idx_products_title_search ON products USING gin(to_tsvector('english', title));

-- Grant permissions on the table
GRANT ALL PRIVILEGES ON TABLE products TO $db_user;
GRANT USAGE, SELECT ON SEQUENCE products_id_seq TO $db_user;
EOF

    if [ $? -eq 0 ]; then
        log_message "SUCCESS" "Database '$db_name' and user '$db_user' created successfully"
        echo -e "${GREEN}✓ Database '$db_name' and user '$db_user' created successfully${NC}"
        return 0
    else
        log_message "ERROR" "Error creating database for domain '$domain'"
        echo -e "${RED}✗ Error creating database for domain '$domain'${NC}"
        return 1
    fi
}

# 1. Database Setup Check
log_message "INFO" "Starting database setup check"
echo -e "\n${BLUE}=== Step 1: Database Setup ===${NC}"

if check_database_exists "$domain"; then
    log_message "SUCCESS" "Database already exists for domain: $domain"
    echo -e "${GREEN}✓ Database already exists for domain: $domain${NC}"
    echo "Database credentials found in ./database_credentials.conf"
else
    log_message "WARNING" "Database not found for domain: $domain"
    echo -e "${YELLOW}Database not found for domain: $domain${NC}"
    read -p "Do you want to create a database for search functionality? (y/n): " create_db
    
    if [[ $create_db =~ ^[Yy]$ ]]; then
        log_message "INFO" "User chose to create database"
        if setup_database "$domain"; then
            log_message "SUCCESS" "Database setup completed successfully"
            echo -e "${GREEN}✓ Database setup completed successfully${NC}"
        else
            log_message "ERROR" "Database setup failed"
            echo -e "${RED}✗ Database setup failed${NC}"
            read -p "Continue without database? (y/n): " continue_without_db
            if [[ ! $continue_without_db =~ ^[Yy]$ ]]; then
                log_message "INFO" "User chose to exit due to database setup failure"
                exit 1
            else
                log_message "WARNING" "User chose to continue without database"
            fi
        fi
    else
        log_message "WARNING" "User chose to skip database setup"
        echo -e "${YELLOW}Skipping database setup. HTML generation will continue without database integration.${NC}"
    fi
fi

# 2. Dependency Installation: Install all required packages.

log_message "INFO" "Starting dependency installation"
echo -e "\n${BLUE}=== Step 2: Installing Dependencies ===${NC}"

# Install root Gulp Node.js dependencies
echo "Installing Node.js dependencies..."
if [[ ! -f "package.json" ]]; then
    log_message "ERROR" "package.json not found in current directory"
    echo -e "${RED}Error: package.json not found in current directory.${NC}"
    exit 1
fi

log_message "INFO" "Running npm install"
npm install
log_message "SUCCESS" "Node.js dependencies installed successfully"
echo -e "${GREEN}✓ Node.js dependencies installed successfully${NC}"

# 3. Execution: Run the project's main scripts.

log_message "INFO" "Starting HTML generation and database population phase"
echo -e "\n${BLUE}=== Step 3: HTML Generation & Database Population ===${NC}"

# Gulp CSV to HTML conversion
echo "This will generate HTML files and populate the database in $folder_location."

# Ask user for generation mode
echo -e "\n${YELLOW}Choose generation mode:${NC}"
echo "1. Incremental generation (only process new/changed products)"
echo "2. Force complete regeneration (process all products + clear database)"
echo "3. Skip generation"
read -p "Enter your choice (1/2/3): " generation_choice

if [[ "$generation_choice" == "1" ]]; then
    log_message "INFO" "User selected incremental generation mode"
    echo -e "${GREEN}Starting incremental HTML generation and database update...${NC}"
    generation_mode="incremental"
elif [[ "$generation_choice" == "2" ]]; then
    log_message "INFO" "User selected force complete regeneration mode"
    echo -e "${GREEN}Starting force complete regeneration and database rebuild...${NC}"
    generation_mode="force"
elif [[ "$generation_choice" == "3" ]]; then
    log_message "INFO" "User selected to skip generation"
    echo -e "${YELLOW}Skipping HTML page generation and database operations.${NC}"
    generation_mode="skip"
else
    log_message "WARNING" "Invalid choice - defaulting to incremental generation"
    echo -e "${YELLOW}Invalid choice. Defaulting to incremental generation.${NC}"
    generation_mode="incremental"
fi

if [[ "$generation_mode" != "skip" ]]; then
    # Check if required files exist
    log_message "INFO" "Checking required files for generation"
    echo -e "\n${BLUE}Checking required files...${NC}"
    
    if [[ ! -f "products.csv" ]]; then
        log_message "ERROR" "products.csv not found in current directory"
        echo -e "${RED}Error: products.csv not found in current directory.${NC}"
        exit 1
    fi
    log_message "SUCCESS" "products.csv found"
    echo -e "${GREEN}✓ products.csv found${NC}"
    
    if [[ ! -f "product.ejs" ]]; then
        log_message "ERROR" "product.ejs template not found in current directory"
        echo -e "${RED}Error: product.ejs template not found in current directory.${NC}"
        exit 1
    fi
    log_message "SUCCESS" "product.ejs template found"
    echo -e "${GREEN}✓ product.ejs template found${NC}"
    
    if [[ ! -f "gulpfile.js" ]]; then
        log_message "ERROR" "gulpfile.js not found in current directory"
        echo -e "${RED}Error: gulpfile.js not found in current directory.${NC}"
        exit 1
    fi
    log_message "SUCCESS" "gulpfile.js found"
    echo -e "${GREEN}✓ gulpfile.js found${NC}"
    
    log_message "INFO" "Starting gulp generation process with mode: $generation_mode"
    echo -e "\n${BLUE}Starting generation process...${NC}"
    
    # Run gulp with appropriate flags
    if [[ "$generation_mode" == "force" ]]; then
        log_message "INFO" "Running gulp with force flag"
        npx gulp --folderLocation="$folder_location" --force
    else
        log_message "INFO" "Running gulp with incremental mode"
        npx gulp --folderLocation="$folder_location"
    fi
    
    # Check if gulp command was successful
    if [ $? -eq 0 ]; then
        log_message "SUCCESS" "Gulp generation completed successfully"
    else
        log_message "ERROR" "Gulp generation failed"
        echo -e "${RED}✗ Generation process failed${NC}"
        exit 1
    fi
    
    # Update search.php after generation
    log_message "INFO" "Updating search.php with database credentials"
    update_search_php
    
    log_message "SUCCESS" "Generation process completed successfully"
    echo -e "\n${GREEN}=== Generation Complete ===${NC}"
    echo -e "${BLUE}Generated files are located in:${NC}"
    echo "  - HTML files: $folder_location/public/products/"
    echo "  - Images: $folder_location/public/images/"
    echo "  - Search functionality: $folder_location/public/products/search.php"
    echo "  - Data files: ./data/"
    
    # Display summary of generated files
    if [[ -d "$folder_location/public/products" ]]; then
        html_count=$(find "$folder_location/public/products" -name "*.html" | wc -l)
        log_message "INFO" "Total HTML files generated: $html_count"
        echo -e "${GREEN}✓ Total HTML files generated: $html_count${NC}"
    fi
    
    if [[ -d "$folder_location/public/images" ]]; then
        image_count=$(find "$folder_location/public/images" -type f | wc -l)
        log_message "INFO" "Total images downloaded: $image_count"
        echo -e "${GREEN}✓ Total images downloaded: $image_count${NC}"
    fi
    
    if [[ -f "./data/sitemap.xml" ]] || [[ -f "./data/"*"_sitemap.xml" ]]; then
        log_message "SUCCESS" "Sitemap generated successfully"
        echo -e "${GREEN}✓ Sitemap generated in ./data/${NC}"
    fi
    
    if [[ -f "./data/products_database.csv" ]] || [[ -f "./data/"*"_database.csv" ]]; then
        log_message "SUCCESS" "Products database CSV generated successfully"
        echo -e "${GREEN}✓ Products database CSV generated in ./data/${NC}"
    fi
    
    # Check for database summary
    if [[ -f "./data/"*"_database_summary.txt" ]]; then
        log_message "SUCCESS" "Database operations completed - summary available"
        echo -e "${GREEN}✓ Database operations completed - check ./data/ for summary${NC}"
        # Display database summary if available
        summary_file=$(ls ./data/*_database_summary.txt 2>/dev/null | head -1)
        if [[ -f "$summary_file" ]]; then
            echo -e "\n${BLUE}=== Database Summary ===${NC}"
            cat "$summary_file"
        fi
    fi
    
else
    log_message "INFO" "User chose to skip generation process"
    echo -e "${YELLOW}Skipping HTML page generation and database operations.${NC}"
fi

log_message "SUCCESS" "=== Product Page Generator Completed Successfully ==="
echo -e "\n${GREEN}=== Project Setup and Execution Completed Successfully! ===${NC}"

if check_database_exists "$domain"; then
    echo -e "\n${BLUE}=== Database Information ===${NC}"
    echo -e "${GREEN}✓ Database is set up and ready for search functionality${NC}"
    echo "Database credentials are stored in: ./database_credentials.conf"
    echo -e "\n${YELLOW}Next Steps:${NC}"
    echo "1. Your products are now available in the database for search functionality"
    echo "2. Use the database connection details to implement your search feature"
    echo "3. Products table contains: id, title, price, product_link, category, image_url"
fi

echo -e "\n${BLUE}=== Quick Access Commands ===${NC}"
echo "• View database credentials: cat ./database_credentials.conf"

# Extract database name for PostgreSQL connection instructions
if [[ -f "./database_credentials.conf" ]] && check_database_exists "$domain"; then
    # Parse credentials file for the current domain
    db_name=""
    current_domain=""
    
    while IFS= read -r line; do
        if [[ $line == "Domain: "* ]]; then
            current_domain=$(echo "$line" | cut -d' ' -f2-)
        elif [[ $current_domain == "$domain" ]]; then
            if [[ $line == "Database: "* ]]; then
                db_name=$(echo "$line" | cut -d' ' -f2-)
            fi
        fi
    done < "./database_credentials.conf"
    
    if [[ -n "$db_name" ]]; then
        echo -e "\n${BLUE}=== Database Access Instructions ===${NC}"
        echo "1. Switch to postgres user and open psql:"
        echo "   sudo -i -u postgres"
        echo "   psql"
        echo ""
        echo "2. List all databases:"
        echo "   postgres=# \\l"
        echo ""
        echo "3. Connect to your database:"
        echo "   postgres=# \\c $db_name"
        echo ""
        echo "4. Check table names:"
        echo "   $db_name=# \\dt;"
        echo ""
        echo "5. Query the products data:"
        echo "   $db_name=# SELECT COUNT(*) FROM products;"
        echo "   $db_name=# SELECT * FROM products LIMIT 10;"
        echo "   $db_name=# SELECT * FROM products;"
        echo ""
        echo "6. Exit PostgreSQL:"
        echo "   $db_name=# \\q"
    else
        echo -e "\n${BLUE}=== Database Access Instructions ===${NC}"
        echo "1. Switch to postgres user and open psql:"
        echo "   sudo -i -u postgres"
        echo "   psql"
        echo ""
        echo "2. List all databases:"
        echo "   postgres=# \\l"
        echo ""
        echo "3. Connect to your database:"
        echo "   postgres=# \\c [your_database_name]"
        echo ""
        echo "4. Check table names:"
        echo "   [database]=# \\dt;"
        echo ""
        echo "5. Query the products data:"
        echo "   [database]=# SELECT COUNT(*) FROM products;"
        echo "   [database]=# SELECT * FROM products LIMIT 10;"
        echo ""
        echo "6. Exit PostgreSQL:"
        echo "   [database]=# \\q"
    fi
else
    echo -e "\n${BLUE}=== Database Access Instructions ===${NC}"
    echo "1. Switch to postgres user and open psql:"
    echo "   sudo -i -u postgres"
    echo "   psql"
    echo ""
    echo "2. List all databases:"
    echo "   postgres=# \\l"
    echo ""
    echo "3. Connect to your database:"
    echo "   postgres=# \\c [your_database_name]"
    echo ""
    echo "4. Check table names:"
    echo "   [database]=# \\dt;"
    echo ""
    echo "5. Query the products data:"
    echo "   [database]=# SELECT COUNT(*) FROM products;"
    echo "   [database]=# SELECT * FROM products LIMIT 10;"
    echo ""
    echo "6. Exit PostgreSQL:"
    echo "   [database]=# \\q"
fi

echo -e "\n${BLUE}=== Other Commands ===${NC}"
echo "• Re-run generation: ./run.sh"
echo "• Force regeneration: Choose option 2 when running ./run.sh"

# 4. Cleanup (Optional): Add a commented-out section for deactivating the virtual environment or cleaning up if necessary.
: '
# To stop the running processes (if they are still active):
# pkill -f "npx gulp"

# To clean up generated files (use with caution):
# rm -rf "$folder_location/public"
# rm -rf "./data"

# To reinstall dependencies:
# rm -rf node_modules package-lock.json
# npm install
'