#!/bin/bash

# Define destination variables
DEST_SERVER="root@destination_ip_address"

# Automatically detect the website directory from the current path
CURRENT_DIR=$(pwd)
BASE_PATH=$(echo "$CURRENT_DIR" | grep -o "/var/www/[^/]*")

# Display detected path
echo "Detected base path: $BASE_PATH"

# Sync data directory
echo "Syncing data directory..."
rsync -av --update "${BASE_PATH}/data/" "${DEST_SERVER}:${BASE_PATH}/data/"

# Sync public directory
echo "Syncing public directory..."
rsync -av --update "${BASE_PATH}/public/" "${DEST_SERVER}:${BASE_PATH}/public/"

echo "Sync completed successfully."

