#!/bin/bash

#Jopseh1Hwk 11-09-2024

# Path to the file
file="mono-6.12.0.122-aarch64.squashfs"

# Destination directory where the file will be copied
destination="/roms/ports/PortMaster/libs"

# Create or recreate the log file
LOG_FILE="./log.txt"
echo "Execution log - $(date)" > "$LOG_FILE"

# Redirect stdout and stderr to the log file
exec > "$LOG_FILE" 2>&1

# Check if the destination directory exists
if [ ! -d "$destination" ]; then
    echo "Destination directory $destination does not exist. Exiting script."
    exit 1
else
    echo "Destination directory exists."
fi

# Copying the file to the destination
cp -r "$file" "$destination" 2>&1

# Checking if the copy was successful
if [ $? -eq 0 ]; then
    echo "Copy successful!"
else
    echo "An error occurred during the copy process."
fi
