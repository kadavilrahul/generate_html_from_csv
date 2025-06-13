#!/bin/bash

# Function to validate script environment
validate_script_environment() {
    log_message "INFO" "Validating script environment"
    
    # Check if required files exist
    local required_files=("products.csv" "product.ejs" "gulpfile.js" "package.json")
    local missing_files=()
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        log_message "ERROR" "Missing required files: ${missing_files[*]}"
        echo -e "${RED}Error: Missing required files: ${missing_files[*]}${NC}"
        exit 1
    fi
    
    log_message "SUCCESS" "Environment validation completed"
    echo -e "${GREEN}✓ Environment validation completed${NC}"
}