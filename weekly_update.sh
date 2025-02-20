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
REQUIRED_SPACE=1000000  # Required free space in KB (1GB)

# Error handling
set -e  # Exit on error
trap 'handle_error $? $LINENO' ERR

#####################################################################
# Function: log_message
# Description: Logs a message with timestamp to both console and log file
# Parameters: $1 - Message to log
#####################################################################
log_message() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

#####################################################################
# Function: show_message
# Description: Shows a message to the user and optionally sends desktop notification
# Parameters: $1 - Message title, $2 - Message content
#####################################################################
show_message() {
    local title="$1"
    local content="$2"
    
    # Terminal output with formatting
    echo -e "\n\033[1;34m=== $title ===\033[0m"
    echo -e "$content"
    
    # Desktop notification if available
    if command -v notify-send &> /dev/null; then
        notify-send "$title" "$content"
    fi
}

#####################################################################
# Function: get_human_readable_date
# Description: Converts Unix timestamp to human readable date
# Parameters: $1 - Unix timestamp
#####################################################################
get_human_readable_date() {
    local timestamp=$1
    date -d "@$timestamp" '+%A, %B %d at %I:%M %p'
}

#####################################################################
# Function: handle_error
# Description: Error handler for script failures
# Parameters: $1 - Exit code, $2 - Line number
#####################################################################
handle_error() {
    local exit_code=$1
    local line_number=$2
    log_message "Error: Command failed on line $line_number with exit code $exit_code"
    # Send desktop notification if available
    if command -v notify-send &> /dev/null; then
        notify-send "System Update Error" "Update failed. Check $LOG_FILE for details."
    fi
    exit $exit_code
}

#####################################################################
# Function: check_network
# Description: Verifies internet connectivity
# Returns: 0 if connected, 1 if not
#####################################################################
check_network() {
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        log_message "Error: No internet connection available"
        return 1
    fi
    return 0
}

#####################################################################
# Function: check_disk_space
# Description: Verifies sufficient disk space is available
# Returns: 0 if enough space, 1 if not
#####################################################################
check_disk_space() {
    local available_space=$(df /var/cache/apt/archives | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt "$REQUIRED_SPACE" ]; then
        log_message "Error: Insufficient disk space. Required: ${REQUIRED_SPACE}KB, Available: ${available_space}KB"
        return 1
    fi
    return 0
}

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
    if [ -f "$LAST_RUN_FILE" ]; then
        last_update=$(cat "$LAST_RUN_FILE")
        last_update_date=$(get_human_readable_date "$last_update")
        next_update=$(($last_update + 518400))
        next_update_date=$(get_human_readable_date "$next_update")
        
        message="System update not needed yet.\n\nLast update was on: $last_update_date\nNext update scheduled for: $next_update_date"
        show_message "Update Status" "$message"
        
        # Pause for user to read the message
        echo -e "\nPress Enter to close..."
        read -r
    fi
    exit 0
fi

# Configure output logging
exec > >(tee -a "$LOG_FILE") 2>&1
log_message "Update started"

# Perform pre-update checks
log_message "Performing pre-update checks..."
check_network || exit 1
check_disk_space || exit 1

# System Update Process:

# Step 1: Update package index
log_message "Updating package index..."
sudo apt update || handle_error $? $LINENO

# Step 2: Perform safe upgrade of installed packages
log_message "Performing safe upgrade..."
sudo apt upgrade -y || handle_error $? $LINENO

# Step 3: Perform full upgrade (may handle changed dependencies)
log_message "Performing full upgrade..."
sudo apt full-upgrade -y || handle_error $? $LINENO

# Step 4: Update Flatpak applications and runtimes
if command -v flatpak &> /dev/null; then
    log_message "Updating Flatpak applications..."
    flatpak update -y || handle_error $? $LINENO
fi

# System Cleanup Process:

# Step 1: Remove orphaned packages and dependencies
log_message "Removing orphaned packages..."
sudo apt autoremove -y || handle_error $? $LINENO

# Step 2: Clear local repository of retrieved package files
log_message "Cleaning package cache..."
sudo apt clean || handle_error $? $LINENO

log_message "System update completed successfully!"

# Send completion notification if available
if command -v notify-send &> /dev/null; then
    notify-send "System Update Complete" "Your system has been successfully updated."
fi

# Record successful completion time for next run calculation
date +%s > "$LAST_RUN_FILE"
