#!/bin/bash

# Set up logging
LOG_FILE="$HOME/update_log.txt"
LAST_RUN_FILE="$HOME/.last_update_run"

# Function to check if we should run the update
should_run_update() {
    # If last run file doesn't exist, we should run
    if [ ! -f "$LAST_RUN_FILE" ]; then
        return 0
    fi

    last_run=$(cat "$LAST_RUN_FILE")
    current_time=$(date +%s)
    seconds_since_last_run=$((current_time - last_run))
    
    # Run if it's been more than 6 days (518400 seconds) since last run
    if [ $seconds_since_last_run -gt 518400 ]; then
        return 0
    else
        return 1
    fi
}

# Check if we should run the update
if ! should_run_update; then
    echo "Update not needed. Last run was less than a week ago."
    exit 0
fi

# Redirect output to log file
exec > >(tee -a "$LOG_FILE") 2>&1
echo "Update started at $(date)"

# Update package lists
sudo apt update

# Upgrade installed packages
sudo apt upgrade -y

# Perform a full upgrade (dist-upgrade)
sudo apt full-upgrade -y

# Update Flatpak packages
flatpak update -y

# Clean up unnecessary packages
sudo apt autoremove -y

# Clean up the package cache
sudo apt clean

echo "System update completed successfully at $(date)!"

# Record the time of this run
date +%s > "$LAST_RUN_FILE"
