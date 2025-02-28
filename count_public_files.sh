#!/bin/bash

# Automatically detect the website directory from the current path
CURRENT_DIR=$(pwd)
WEBSITE_DIR=$(echo "$CURRENT_DIR" | grep -o "/var/www/[^/]*")

# Set the directory to monitor using the detected website directory
PUBLIC_DIR="$WEBSITE_DIR/public"

# Set the log file
LOG_FILE="$WEBSITE_DIR/data/public_files_count.log"

# Get the current timestamp
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# Count the number of folders
FOLDER_COUNT=$(find "$PUBLIC_DIR" -maxdepth 1 -type d | wc -l)
FOLDER_COUNT=$((FOLDER_COUNT - 1)) # Subtract 1 to exclude the public directory itself

# Initialize a string to store file counts for each folder
FILE_COUNTS=""

# Loop through each folder and count files
for folder in $(find "$PUBLIC_DIR" -maxdepth 1 -type d); do
  if [[ "$folder" != "$PUBLIC_DIR" ]]; then
    FILE_COUNT=$(find "$folder" -type f | wc -l)
    FOLDER_NAME=$(basename "$folder")
    FILE_COUNTS+=", $FOLDER_NAME: $FILE_COUNT"
  fi
done

# Remove the leading comma and space from the file counts string if it exists
if [[ -n "$FILE_COUNTS" ]]; then
  FILE_COUNTS=${FILE_COUNTS:2}
fi

# Create the log entry
LOG_ENTRY="$TIMESTAMP - Folders: $FOLDER_COUNT, Files in folders: $FILE_COUNTS"

# Append the log entry to the log file
echo "$LOG_ENTRY" >> "$LOG_FILE"

echo "Detected website directory: $WEBSITE_DIR"
echo "Logged file and folder count to $LOG_FILE"
