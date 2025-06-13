#!/bin/bash

# Configuration file for Product Page Generator

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Data directory for storing logs and credentials
DATA_DIR="./data"

# File paths (now in data directory)
LOG_FILE="$DATA_DIR/product_generator.log"
SETUP_MARKER_FILE="$DATA_DIR/.setup_completed"
CREDENTIALS_FILE="$DATA_DIR/database_credentials.conf"

# Global variables
DOMAIN=""
FOLDER_LOCATION=""
DB_NAME=""
DB_USER=""
DB_PASSWORD=""
FORCE_MODE=${FORCE_MODE:-false}
SKIP_SETUP=${SKIP_SETUP:-false}

# Create data directory if it doesn't exist
mkdir -p "$DATA_DIR"

# Cleanup function for node_modules
cleanup_node_modules() {
    if [[ -d "node_modules" ]]; then
        echo -e "${YELLOW}Cleaning up node_modules directory...${NC}"
        rm -rf node_modules
        echo -e "${GREEN}✓ node_modules cleaned up${NC}"
    fi
}