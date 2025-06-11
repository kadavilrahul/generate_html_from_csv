#!/bin/bash

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
                        read -p "Please provide the folder location (e.g., /var/www/yourwebsite.com): " FOLDER_LOCATION
                        break
                    else
                        # Selected from list
                        FOLDER_LOCATION="${folders[$((choice-1))]}"
                        echo -e "${GREEN}Selected: $FOLDER_LOCATION${NC}"
                        break
                    fi
                else
                    echo -e "${RED}Invalid choice. Please select a number between 1 and $((${#folders[@]}+1)).${NC}"
                fi
            done
        else
            echo -e "${YELLOW}No domain folders found in $www_dir${NC}"
            echo "Looking for folders with domain-like names (containing dots)..."
            read -p "Please provide the folder location (e.g., /var/www/yourwebsite.com): " FOLDER_LOCATION
        fi
    else
        echo -e "${YELLOW}Directory $www_dir does not exist.${NC}"
        read -p "Please provide the folder location (e.g., /var/www/yourwebsite.com): " FOLDER_LOCATION
    fi
}

# Function to setup domain folder
setup_domain_folder() {
    log_message "INFO" "Starting domain folder search"
    search_domain_folders
    
    log_message "INFO" "Selected folder location: $FOLDER_LOCATION"
    
    # Validate folder location input
    if [[ -z "$FOLDER_LOCATION" ]]; then
        log_message "ERROR" "Folder location is empty"
        echo -e "${RED}Error: Folder location cannot be empty.${NC}"
        exit 1
    fi
    
    # Extract domain from folder location for database operations
    export DOMAIN=$(basename "$FOLDER_LOCATION")
    log_message "INFO" "Detected domain: $DOMAIN"
    echo -e "${BLUE}Detected domain: $DOMAIN${NC}"
    
    # Create the folder if it doesn't exist
    if [[ ! -d "$FOLDER_LOCATION" ]]; then
        log_message "INFO" "Creating directory: $FOLDER_LOCATION"
        echo -e "${YELLOW}Creating directory: $FOLDER_LOCATION${NC}"
        sudo mkdir -p "$FOLDER_LOCATION"
        log_message "SUCCESS" "Directory created successfully: $FOLDER_LOCATION"
        echo -e "${GREEN}Directory created successfully.${NC}"
    else
        log_message "INFO" "Directory already exists: $FOLDER_LOCATION"
        echo -e "${GREEN}Directory already exists: $FOLDER_LOCATION${NC}"
    fi
    
    export FOLDER_LOCATION
}