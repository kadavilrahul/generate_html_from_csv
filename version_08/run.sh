#!/bin/bash

# Product Page Generator - Minimal Version
set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source configuration and logging
source "$SCRIPT_DIR/modules/config.sh"
source "$SCRIPT_DIR/modules/logging.sh"
source "$SCRIPT_DIR/modules/database.sh"

# Install Node.js and npm if missing
install_nodejs() {
    if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
        echo "Installing Node.js and npm..."
        if [[ -f /etc/debian_version ]]; then
            apt update && apt install -y nodejs npm
        elif [[ -f /etc/redhat-release ]]; then
            yum install -y nodejs npm
        fi
    fi
}

# Install PHP with extensions if missing
install_php() {
    if ! command -v php &> /dev/null || ! php -m | grep -q mysqli || ! php -m | grep -q pgsql; then
        echo "Installing PHP and extensions..."
        if [[ -f /etc/debian_version ]]; then
            apt update && apt install -y php php-mysql php-pgsql php-cli
        elif [[ -f /etc/redhat-release ]]; then
            yum install -y php php-mysql php-pgsql php-cli
        fi
    fi
}

# Install MySQL server if missing
install_mysql() {
    if ! systemctl is-active --quiet mysql 2>/dev/null && ! systemctl is-active --quiet mysqld 2>/dev/null; then
        echo "Installing MySQL server..."
        if [[ -f /etc/debian_version ]]; then
            export DEBIAN_FRONTEND=noninteractive
            apt update && apt install -y mysql-server mysql-client
            systemctl start mysql && systemctl enable mysql
            mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'root123';" 2>/dev/null || true
        elif [[ -f /etc/redhat-release ]]; then
            yum install -y mysql-server mysql
            systemctl start mysqld && systemctl enable mysqld
        fi
    fi
}

# Main execution
main() {
    # Handle arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force) export FORCE_MODE=true; shift ;;
            --skip-setup) export SKIP_SETUP=true; shift ;;
            --skip-cleanup) export SKIP_CLEANUP=true; shift ;;
            --cleanup-only)
                [[ -d "node_modules" ]] && rm -rf node_modules
                exit 0 ;;
            --help|-h)
                echo "Usage: $0 [--force] [--skip-setup] [--skip-cleanup] [--cleanup-only] [--help]"
                exit 0 ;;
            *) shift ;;
        esac
    done

    echo "=== Product Page Generator ==="
    
    # Ensure data directory exists and move legacy files if needed
    mkdir -p "$DATA_DIR"
    
    # Move legacy log file to data directory if it exists in root
    if [[ -f "product_generator.log" && ! -f "$LOG_FILE" ]]; then
        echo "Moving product_generator.log to data directory..."
        mv "product_generator.log" "$LOG_FILE"
    fi
    
    # Move legacy setup marker to data directory if it exists in root
    if [[ -f ".setup_completed" && ! -f "$SETUP_MARKER_FILE" ]]; then
        echo "Moving .setup_completed to data directory..."
        mv ".setup_completed" "$SETUP_MARKER_FILE"
    fi
    
    # Install prerequisites
    install_nodejs
    install_php
    install_mysql

    # Validate environment
    if [[ -f "$SCRIPT_DIR/modules/validate_environment.sh" ]]; then
        source "$SCRIPT_DIR/modules/validate_environment.sh"
        validate_script_environment
    fi
    
    # Handle setup check
    if [[ "$SKIP_SETUP" != "true" && -f "$SCRIPT_DIR/modules/check_setup_completion.sh" ]]; then
        source "$SCRIPT_DIR/modules/check_setup_completion.sh"
        handle_setup_check
    fi
    
    # Setup domain folder
    source "$SCRIPT_DIR/modules/domain_manager.sh"
    setup_domain_folder
    
    # Setup PostgreSQL
    source "$SCRIPT_DIR/modules/postgresql.sh"
    setup_postgresql
    
    # Setup database
    database_setup_success=false
    if handle_database_setup "$DOMAIN"; then
        database_setup_success=true
        update_search_php "$FOLDER_LOCATION"
    fi
    
    # Handle HTML generation
    source "$SCRIPT_DIR/modules/generator.sh"
    if handle_generation_workflow "$FOLDER_LOCATION"; then
        # Import data after HTML generation
        if [[ "$database_setup_success" == "true" ]]; then
            import_product_data "$DOMAIN"
        fi
        
        echo "Setup Complete!"
        echo "Domain: $DOMAIN"
        echo "Location: $FOLDER_LOCATION"
        [[ -n "$DB_NAME" ]] && echo "Database: $DB_NAME"
        
        # Cleanup
        if [[ "$SKIP_CLEANUP" != "true" ]]; then
            [[ -d "node_modules" ]] && rm -rf node_modules || true
            [[ -n "$FOLDER_LOCATION" && -d "$FOLDER_LOCATION/node_modules" ]] && rm -rf "$FOLDER_LOCATION/node_modules" || true
        fi
    else
        exit 1
    fi
}

# Error handling
trap 'echo "Error at line $LINENO"' ERR

# Execute
main "$@"
