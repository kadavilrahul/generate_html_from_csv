#!/bin/bash

# Product Page Generator - Optimized Version
set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source configuration and logging
source "$SCRIPT_DIR/modules/config.sh"
source "$SCRIPT_DIR/modules/logging.sh"
source "$SCRIPT_DIR/modules/database.sh"

# Display header
display_header() {
    echo -e "${BLUE}=== Product Page Generator ===${NC}"
    echo "Features: PostgreSQL setup, HTML generation, search functionality"
    echo
}

# Main execution function
main() {
    handle_arguments "$@"
    display_header
    log_message "INFO" "Product Page Generator started"
    
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
        update_search_php "$FOLDER_LOCATION"
    fi
    
    # Handle HTML generation
    source "$SCRIPT_DIR/modules/generator.sh"
    if handle_generation_workflow "$FOLDER_LOCATION"; then
        echo -e "\n${GREEN}=== Setup Complete! ===${NC}"
        echo -e "${BLUE}Domain: $DOMAIN${NC}"
        echo -e "${BLUE}Location: $FOLDER_LOCATION${NC}"
        [[ -n "$DB_NAME" ]] && echo -e "${BLUE}Database: $DB_NAME${NC}"
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
            --help|-h) display_help; exit 0 ;;
            *) echo -e "${YELLOW}Unknown option: $1${NC}"; shift ;;
        esac
    done
}

# Display help
display_help() {
    echo "Product Page Generator"
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --force         Force complete regeneration"
    echo "  --skip-setup    Skip setup completion check"
    echo "  --help, -h      Display this help"
}

# Error handling
trap 'log_message "ERROR" "Script failed at line $LINENO"' ERR

# Execute main function
main "$@"