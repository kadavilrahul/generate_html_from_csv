#!/bin/bash

# Configuration file for Product Page Generator

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# File paths
LOG_FILE="./product_generator.log"
SETUP_MARKER_FILE="./.setup_completed"
CREDENTIALS_FILE="./database_credentials.conf"

# Global variables
DOMAIN=""
FOLDER_LOCATION=""
DB_NAME=""
DB_USER=""
DB_PASSWORD=""
FORCE_MODE=${FORCE_MODE:-false}
SKIP_SETUP=${SKIP_SETUP:-false}