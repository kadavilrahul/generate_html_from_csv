#!/bin/bash

# Define destination variables
DEST_SERVER="user@destination_server"
BASE_PATH="/var/www/your_domain.com"

# Sync data directory
rsync -av --update "${BASE_PATH}/data/" "${DEST_SERVER}:${BASE_PATH}/data/"

# Sync public directory
rsync -av --update "${BASE_PATH}/public/" "${DEST_SERVER}:${BASE_PATH}/public/"
