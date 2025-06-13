#!/bin/bash

# Product Page Generator - Optimized Version
set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source configuration and logging
source "$SCRIPT_DIR/modules/config.sh"
source "$SCRIPT_DIR/modules/logging.sh"
source "$SCRIPT_DIR/modules/database.sh"

# Check if Node.js and npm are installed
check_nodejs_prerequisites() {
    log_message "INFO" "Checking Node.js and npm prerequisites"
    echo -e "\n${BLUE}=== Checking Node.js Prerequisites ===${NC}"
    
    local nodejs_missing=false
    local npm_missing=false
    
    if ! command -v node &> /dev/null; then
        log_message "ERROR" "Node.js is not installed"
        echo -e "${RED}✗ Node.js is not installed${NC}"
        nodejs_missing=true
    else
        local node_version=$(node --version 2>/dev/null)
        log_message "INFO" "Node.js version: $node_version"
        echo -e "${GREEN}✓ Node.js $node_version detected${NC}"
    fi
    
    if ! command -v npm &> /dev/null; then
        log_message "ERROR" "npm is not installed"
        echo -e "${RED}✗ npm is not installed${NC}"
        npm_missing=true
    else
        local npm_version=$(npm --version 2>/dev/null)
        log_message "INFO" "npm version: $npm_version"
        echo -e "${GREEN}✓ npm $npm_version detected${NC}"
    fi
    
    if [[ "$nodejs_missing" == "true" || "$npm_missing" == "true" ]]; then
        echo -e "\n${YELLOW}=== Node.js Installation Required ===${NC}"
        echo -e "${YELLOW}This script requires Node.js and npm to generate HTML pages.${NC}"
        echo -e "${BLUE}Installation commands:${NC}"
        echo "  Ubuntu/Debian: sudo apt update && sudo apt install -y nodejs npm"
        echo "  CentOS/RHEL: sudo yum install -y nodejs npm"
        echo "  Or visit: https://nodejs.org/"
        echo ""
        
        while true; do
            read -p "Do you want to install Node.js and npm now? (y/n): " install_choice
            case $install_choice in
                [Yy]* )
                    log_message "INFO" "User chose to install Node.js and npm"
                    install_nodejs
                    break
                    ;;
                [Nn]* )
                    log_message "WARNING" "User chose not to install Node.js and npm"
                    echo -e "${YELLOW}⚠ Cannot proceed without Node.js and npm${NC}"
                    echo "Please install Node.js and npm manually, then run this script again."
                    exit 1
                    ;;
                * )
                    echo "Please answer yes (y) or no (n)."
                    ;;
            esac
        done
    else
        log_message "SUCCESS" "Node.js and npm prerequisites satisfied"
        echo -e "${GREEN}✓ Node.js and npm prerequisites satisfied${NC}"
    fi
}

# Install Node.js and npm
install_nodejs() {
    log_message "INFO" "Starting Node.js and npm installation"
    echo -e "\n${BLUE}=== Installing Node.js and npm ===${NC}"
    
    # Detect OS and install accordingly
    if [[ -f /etc/debian_version ]]; then
        echo "Detected Debian/Ubuntu system"
        log_message "INFO" "Installing Node.js and npm on Debian/Ubuntu"
        
        if apt update && apt install -y nodejs npm; then
            log_message "SUCCESS" "Node.js and npm installed successfully"
            echo -e "${GREEN}✓ Node.js and npm installed successfully${NC}"
            
            # Verify installation
            if command -v node &> /dev/null && command -v npm &> /dev/null; then
                local node_version=$(node --version 2>/dev/null)
                local npm_version=$(npm --version 2>/dev/null)
                echo -e "${GREEN}✓ Node.js $node_version installed${NC}"
                echo -e "${GREEN}✓ npm $npm_version installed${NC}"
            else
                log_message "ERROR" "Node.js/npm installation verification failed"
                echo -e "${RED}✗ Installation verification failed${NC}"
                exit 1
            fi
        else
            log_message "ERROR" "Failed to install Node.js and npm"
            echo -e "${RED}✗ Failed to install Node.js and npm${NC}"
            echo "Please install manually and try again."
            exit 1
        fi
    elif [[ -f /etc/redhat-release ]]; then
        echo "Detected RedHat/CentOS system"
        log_message "INFO" "Installing Node.js and npm on RedHat/CentOS"
        
        if yum install -y nodejs npm; then
            log_message "SUCCESS" "Node.js and npm installed successfully"
            echo -e "${GREEN}✓ Node.js and npm installed successfully${NC}"
        else
            log_message "ERROR" "Failed to install Node.js and npm"
            echo -e "${RED}✗ Failed to install Node.js and npm${NC}"
            exit 1
        fi
    else
        log_message "ERROR" "Unsupported operating system for automatic installation"
        echo -e "${RED}✗ Unsupported operating system for automatic installation${NC}"
        echo "Please install Node.js and npm manually from https://nodejs.org/"
        exit 1
    fi
}

# Display header
display_header() {
    echo -e "${BLUE}=== Product Page Generator ===${NC}"
    echo "Features: PostgreSQL setup, HTML generation, search functionality"
    echo
}

# Cleanup node_modules folder after page generation
cleanup_node_modules() {
    log_message "INFO" "Starting node_modules cleanup process"
    echo -e "\n${BLUE}=== Node Modules Cleanup ===${NC}"
    
    # Check if node_modules exists in current directory
    if [[ -d "node_modules" ]]; then
        echo -e "${YELLOW}Found node_modules folder in current directory${NC}"
        echo -e "${BLUE}Removing node_modules to free up space...${NC}"
        
        # Get size before removal for logging
        local size_before=$(du -sh node_modules 2>/dev/null | cut -f1 || echo "unknown")
        
        # Remove node_modules folder
        if rm -rf node_modules; then
            log_message "SUCCESS" "node_modules folder removed successfully (was $size_before)"
            echo -e "${GREEN}✓ node_modules folder removed successfully (freed: $size_before)${NC}"
        else
            log_message "ERROR" "Failed to remove node_modules folder"
            echo -e "${RED}✗ Failed to remove node_modules folder${NC}"
            return 1
        fi
    else
        log_message "INFO" "No node_modules folder found in current directory"
        echo -e "${GREEN}✓ No node_modules folder found - nothing to clean${NC}"
    fi
    
    # Also check in the domain folder if it exists
    if [[ -n "$FOLDER_LOCATION" && -d "$FOLDER_LOCATION" ]]; then
        if [[ -d "$FOLDER_LOCATION/node_modules" ]]; then
            echo -e "${YELLOW}Found node_modules folder in domain directory: $FOLDER_LOCATION${NC}"
            echo -e "${BLUE}Removing node_modules from domain directory...${NC}"
            
            # Get size before removal for logging
            local domain_size_before=$(du -sh "$FOLDER_LOCATION/node_modules" 2>/dev/null | cut -f1 || echo "unknown")
            
            # Remove node_modules folder from domain directory
            if rm -rf "$FOLDER_LOCATION/node_modules"; then
                log_message "SUCCESS" "node_modules folder removed from domain directory (was $domain_size_before)"
                echo -e "${GREEN}✓ node_modules removed from domain directory (freed: $domain_size_before)${NC}"
            else
                log_message "ERROR" "Failed to remove node_modules from domain directory"
                echo -e "${RED}✗ Failed to remove node_modules from domain directory${NC}"
                return 1
            fi
        fi
    fi
    
    return 0
}

# Standalone cleanup function that can be called independently
cleanup_only() {
    display_header
    log_message "INFO" "Running standalone node_modules cleanup"
    
    # Set a basic folder location if not set
    if [[ -z "$FOLDER_LOCATION" ]]; then
        # Try to find domain folders in current directory
        local domain_dirs=($(find . -maxdepth 1 -type d -name "*.com" -o -name "*.org" -o -name "*.net" 2>/dev/null))
        if [[ ${#domain_dirs[@]} -gt 0 ]]; then
            echo -e "${BLUE}Found domain directories: ${domain_dirs[*]}${NC}"
            for dir in "${domain_dirs[@]}"; do
                export FOLDER_LOCATION="$dir"
                cleanup_node_modules
            done
        else
            cleanup_node_modules
        fi
    else
        cleanup_node_modules
    fi
}

# Main execution function
main() {
    handle_arguments "$@"
    display_header
    log_message "INFO" "Product Page Generator started"
    
    # Check Node.js prerequisites first
    check_nodejs_prerequisites

    # Check and install PHP prerequisites
    check_and_install_php

    # Validate environment
    if [[ -f "$SCRIPT_DIR/modules/validate_environment.sh" ]]; then
        source "$SCRIPT_DIR/modules/validate_environment.sh"
        validate_script_environment
    fi
    
    # Handle setup check (unless skipped)
    if [[ "$SKIP_SETUP" != "true" ]]; then
        if [[ -f "$SCRIPT_DIR/modules/check_setup_completion.sh" ]]; then
            source "$SCRIPT_DIR/modules/check_setup_completion.sh"
            handle_setup_check
        fi
    fi
    
    # Setup domain folder
    source "$SCRIPT_DIR/modules/domain_manager.sh"
    setup_domain_folder
    
    # Setup PostgreSQL
    source "$SCRIPT_DIR/modules/postgresql.sh"
    setup_postgresql
    
    # Setup database
    if handle_database_setup "$DOMAIN"; then
        # Import data into the database
        import_product_data "$DOMAIN"
        # Update search.php with credentials
        update_search_php "$FOLDER_LOCATION"
    fi
    
    # Handle HTML generation
    source "$SCRIPT_DIR/modules/generator.sh"
    if handle_generation_workflow "$FOLDER_LOCATION"; then
        echo -e "\n${GREEN}=== Setup Complete! ===${NC}"
        echo -e "${BLUE}Domain: $DOMAIN${NC}"
        echo -e "${BLUE}Location: $FOLDER_LOCATION${NC}"
        [[ -n "$DB_NAME" ]] && echo -e "${BLUE}Database: $DB_NAME${NC}"
        
        # Cleanup node_modules after successful page generation (unless skipped)
        if [[ "$SKIP_CLEANUP" != "true" ]]; then
            cleanup_node_modules
        else
            log_message "INFO" "node_modules cleanup skipped due to --skip-cleanup flag"
            echo -e "${YELLOW}⚠ node_modules cleanup skipped${NC}"
        fi
    else
        exit 1
    fi
}

# Handle command line arguments
handle_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force) export FORCE_MODE=true; shift ;;
            --skip-setup) export SKIP_SETUP=true; shift ;;
            --skip-cleanup) export SKIP_CLEANUP=true; shift ;;
            --cleanup-only) cleanup_only; exit 0 ;;
            --help|-h) display_help; exit 0 ;;
            *) echo -e "${YELLOW}Unknown option: $1${NC}"; shift ;;
        esac
    done
}

# Display help
display_help() {
    echo "Product Page Generator"
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "This script generates HTML product pages from CSV data and sets up a PostgreSQL database."
    echo ""
    echo "Prerequisites:"
    echo "  - Node.js and npm (will be installed automatically if missing)"
    echo "  - PostgreSQL (will be installed automatically if missing)"
    echo "  - Apache web server (configured by setup.sh)"
    echo ""
    echo "Options:"
    echo "  --force         Force complete regeneration"
    echo "  --skip-setup    Skip setup completion check"
    echo "  --skip-cleanup  Skip node_modules cleanup after generation"
    echo "  --cleanup-only  Only run node_modules cleanup (no generation)"
    echo "  --help, -h      Display this help"
    echo ""
    echo "Examples:"
    echo "  $0                    # Run with interactive prompts"
    echo "  $0 --force           # Force complete regeneration"
    echo "  $0 --skip-setup      # Skip Apache setup check"
    echo "  $0 --cleanup-only    # Only cleanup node_modules folders"
}

# Error handling
trap 'log_message "ERROR" "Script failed at line $LINENO"' ERR

# Execute main function
main "$@"