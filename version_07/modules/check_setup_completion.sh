#!/bin/bash

SETUP_MARKER_FILE="./.setup_completed"

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

# Function to handle setup check
handle_setup_check() {
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
}