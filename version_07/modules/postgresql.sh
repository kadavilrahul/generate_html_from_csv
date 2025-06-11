#!/bin/bash

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

# Function to setup PostgreSQL
setup_postgresql() {
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
}