#!/bin/bash

# Logging configuration
LOG_FILE="./product_generator.log"

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