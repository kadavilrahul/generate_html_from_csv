#!/bin/bash

# HTML generation and workflow management

# Function to handle generation workflow
handle_generation_workflow() {
    local folder_location=$1
    
    log_message "INFO" "Starting HTML generation and database population phase"
    echo -e "\n${BLUE}=== HTML Generation & Database Population ===${NC}"
    
    # Install dependencies first
    install_dependencies
    
    # Gulp CSV to HTML conversion
    echo "This will generate HTML files and populate the database in $folder_location."
    
    # Ask user for generation mode
    echo -e "\n${YELLOW}Choose generation mode:${NC}"
    echo "1. Incremental generation (only process new/changed products)"
    echo "2. Force complete regeneration (process all products + clear database)"
    echo "3. Skip generation"
    read -p "Enter your choice (1/2/3): " generation_choice
    
    local generation_mode
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
        validate_generation_files
        
        log_message "INFO" "Starting gulp generation process with mode: $generation_mode"
        echo -e "\n${BLUE}Starting generation process...${NC}"
        
        # Run gulp with appropriate flags
        if [[ "$generation_mode" == "force" ]]; then
            log_message "INFO" "Running gulp with force flag"
            if ! npx gulp --folderLocation="$folder_location" --force; then
                log_message "ERROR" "Gulp generation with force flag failed"
                echo -e "${RED}✗ Generation process failed${NC}"
                echo -e "${YELLOW}Check if gulpfile.js is properly configured and all dependencies are installed${NC}"
                return 1
            fi
        else
            log_message "INFO" "Running gulp with incremental mode"
            if ! npx gulp --folderLocation="$folder_location"; then
                log_message "ERROR" "Gulp generation in incremental mode failed"
                echo -e "${RED}✗ Generation process failed${NC}"
                echo -e "${YELLOW}Check if gulpfile.js is properly configured and all dependencies are installed${NC}"
                return 1
            fi
        fi
        
        # If we reach here, gulp was successful
        log_message "SUCCESS" "Gulp generation completed successfully"
        display_generation_summary "$folder_location"
        return 0
    else
        log_message "INFO" "User chose to skip generation process"
        echo -e "${YELLOW}Skipping HTML page generation and database operations.${NC}"
        return 0
    fi
}

# Function to check if Node.js and npm are installed
check_nodejs_installation() {
    if ! command -v node &> /dev/null; then
        log_message "ERROR" "Node.js is not installed"
        echo -e "${RED}Error: Node.js is not installed${NC}"
        echo -e "${YELLOW}Please install Node.js first:${NC}"
        echo "  Ubuntu/Debian: sudo apt update && sudo apt install -y nodejs npm"
        echo "  CentOS/RHEL: sudo yum install -y nodejs npm"
        echo "  Or visit: https://nodejs.org/"
        return 1
    fi
    
    if ! command -v npm &> /dev/null; then
        log_message "ERROR" "npm is not installed"
        echo -e "${RED}Error: npm is not installed${NC}"
        echo -e "${YELLOW}Please install npm first:${NC}"
        echo "  Ubuntu/Debian: sudo apt install -y npm"
        echo "  CentOS/RHEL: sudo yum install -y npm"
        return 1
    fi
    
    # Check Node.js version
    local node_version=$(node --version 2>/dev/null)
    local npm_version=$(npm --version 2>/dev/null)
    
    log_message "INFO" "Node.js version: $node_version"
    log_message "INFO" "npm version: $npm_version"
    echo -e "${GREEN}✓ Node.js $node_version detected${NC}"
    echo -e "${GREEN}✓ npm $npm_version detected${NC}"
    
    return 0
}

# Function to install dependencies
install_dependencies() {
    log_message "INFO" "Starting dependency installation"
    echo -e "\n${BLUE}=== Installing Dependencies ===${NC}"
    
    # Check if Node.js and npm are installed
    if ! check_nodejs_installation; then
        log_message "ERROR" "Node.js/npm installation check failed"
        echo -e "${RED}Cannot proceed without Node.js and npm${NC}"
        echo -e "${YELLOW}Please install Node.js and npm, then run the script again${NC}"
        exit 1
    fi
    
    # Install root Gulp Node.js dependencies
    echo "Installing Node.js dependencies..."
    if [[ ! -f "package.json" ]]; then
        log_message "ERROR" "package.json not found in current directory"
        echo -e "${RED}Error: package.json not found in current directory.${NC}"
        exit 1
    fi
    
    log_message "INFO" "Running npm install"
    if npm install; then
        log_message "SUCCESS" "Node.js dependencies installed successfully"
        echo -e "${GREEN}✓ Node.js dependencies installed successfully${NC}"
    else
        log_message "ERROR" "npm install failed"
        echo -e "${RED}✗ npm install failed${NC}"
        echo -e "${YELLOW}Please check your npm configuration and try again${NC}"
        exit 1
    fi
}

# Function to validate generation files
validate_generation_files() {
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
}

# Function to display generation summary
display_generation_summary() {
    local folder_location=$1
    
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
}