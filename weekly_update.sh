#!/bin/bash

#####################################################################
# Script Name: weekly_update.sh
# Description: Automated system update script that runs weekly
# This script performs a comprehensive system update including:
#   - APT package updates and upgrades
#   - Flatpak package updates
#   - System cleanup
# The script maintains a log file and ensures it only runs once per week
#####################################################################

# Configuration
# LOG_FILE: Stores the complete output of update operations
# LAST_RUN_FILE: Tracks the timestamp of the last successful update
LOG_FILE="$HOME/update_log.txt"
LAST_RUN_FILE="$HOME/.last_update_run"

#####################################################################
# Function: should_run_update
# Description: Determines if enough time has passed since the last update
# Returns:
#   0 (true) - if update should run (> 6 days since last run or first run)
#   1 (false) - if update should not run yet
#####################################################################
should_run_update() {
    # First run check - if tracking file doesn't exist, run update
    if [ ! -f "$LAST_RUN_FILE" ]; then
        return 0
    fi

    # Calculate time elapsed since last update
    last_run=$(cat "$LAST_RUN_FILE")
    current_time=$(date +%s)
    seconds_since_last_run=$((current_time - last_run))
    
    # Check if more than 6 days (518400 seconds) have passed
    if [ $seconds_since_last_run -gt 518400 ]; then
        return 0
    else
        return 1
    fi
}

# Verify if update should proceed
if ! should_run_update; then
    echo "Update not needed. Last run was less than a week ago."
    exit 0
fi

# Configure output logging
# Redirect both stdout and stderr to terminal and log file using tee
exec > >(tee -a "$LOG_FILE") 2>&1
echo "Update started at $(date)"

# System Update Process:

# Step 1: Update package index
sudo apt update

# Step 2: Perform safe upgrade of installed packages
sudo apt upgrade -y

# Step 3: Perform full upgrade (may handle changed dependencies)
sudo apt full-upgrade -y

# Step 4: Update Flatpak applications and runtimes
flatpak update -y

# System Cleanup Process:

# Step 1: Remove orphaned packages and dependencies
sudo apt autoremove -y

# Step 2: Clear local repository of retrieved package files
sudo apt clean

echo "System update completed successfully at $(date)!"

# Record successful completion time for next run calculation
date +%s > "$LAST_RUN_FILE"
