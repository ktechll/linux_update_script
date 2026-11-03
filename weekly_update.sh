#!/bin/bash

#####################################################################
# Script Name: weekly_update.sh
# Description: Automated system update script that runs weekly.
# This script performs a comprehensive system update including:
#   - APT package index refresh and full upgrade
#   - Flatpak application and runtime updates
#   - System cleanup (orphaned packages, unused runtimes, package cache)
# The script maintains a log file and ensures it only runs once per week
# unless forced with --force.
# It also shows a message to the user and optionally sends desktop notifications.
#
# Usage: weekly_update.sh [-f|--force] [-h|--help]
#####################################################################

# Configuration
# LOG_FILE: Stores the complete output of update operations
# LAST_RUN_FILE: Tracks the timestamp of the last successful update
# LOCK_FILE: Prevents two copies of the script running at the same time
LOG_FILE="$HOME/update_log.txt"
LAST_RUN_FILE="$HOME/.last_update_run"
LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/weekly_update.lock"
REQUIRED_SPACE=1000000          # Required free space in KB (1GB)
REQUIRED_BOOT_SPACE=150000      # Required free space on a separate /boot in KB (~150MB, one kernel + initrd)
UPDATE_INTERVAL_DAYS=6          # Run when MORE than this many days have passed
UPDATE_INTERVAL=$((UPDATE_INTERVAL_DAYS * 86400))
MAX_LOG_SIZE=5242880            # Rotate log when larger than this (5MB)

# APT options for unattended runs:
#   -y                        answer yes to prompts
#   DPkg::Lock::Timeout=300   wait up to 5 min if another apt/unattended-upgrades holds the lock
#   --force-confdef/confold   keep existing config files instead of stopping at a prompt
APT_OPTS=(
    -y
    -o DPkg::Lock::Timeout=300
    -o Dpkg::Options::=--force-confdef
    -o Dpkg::Options::=--force-confold
)

# Error handling
# -E  ERR trap is inherited by functions and subshells
# -e  exit on error
# -u  treat unset variables as errors
# -o pipefail  a pipeline fails if any command in it fails
set -Eeuo pipefail
trap 'handle_error $? $LINENO' ERR
trap 'cleanup' EXIT

FORCE=0
SUDO_KEEPALIVE_PID=""
CURRENT_STEP="Startup"

#####################################################################
# Function: usage
# Description: Prints command line help
#####################################################################
usage() {
    echo "Usage: $(basename "$0") [-f|--force] [-h|--help]"
    echo "  -f, --force   Run the update even if the last run was recent"
    echo "  -h, --help    Show this help"
}

#####################################################################
# Function: log_message
# Description: Logs a message with timestamp. Once logging is started,
# stdout is already tee'd to the log file, so a plain echo reaches both.
# Parameters: $1 - Message to log
#####################################################################
log_message() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1"
}

#####################################################################
# Function: step
# Description: Records the name of the step now running (used in error
# messages) and logs it
# Parameters: $1 - Step name
#####################################################################
step() {
    CURRENT_STEP="$1"
    log_message "$1..."
}

#####################################################################
# Function: notify
# Description: Sends a desktop notification if notify-send is available.
# A failed notification (no desktop session, e.g. cron) is ignored.
# Parameters: $1 - Title, $2 - Body
#####################################################################
notify() {
    if command -v notify-send &> /dev/null; then
        notify-send "$1" "$2" 2> /dev/null || true
    fi
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
    echo "$content"

    notify "$title" "$content"
}

#####################################################################
# Function: pause_if_interactive
# Description: Waits for Enter so a terminal launched from a desktop
# shortcut stays open. Skipped when there is no terminal (cron, systemd).
#####################################################################
pause_if_interactive() {
    if [ -t 0 ] && [ -e /dev/tty ]; then
        printf '\nPress Enter to close...' > /dev/tty
        read -r < /dev/tty || true
    fi
}

#####################################################################
# Function: get_human_readable_date
# Description: Converts Unix timestamp to human readable date
# Parameters: $1 - Unix timestamp
#####################################################################
get_human_readable_date() {
    date -d "@$1" '+%A, %B %d at %I:%M %p'
}

#####################################################################
# Function: fail
# Description: Logs an error, notifies the user and exits
# Parameters: $1 - Message, $2 - Exit code (default 1)
#####################################################################
fail() {
    local message="$1"
    local exit_code="${2:-1}"
    trap - ERR
    log_message "Error: $message"
    notify "System Update Error" "$message Check $LOG_FILE for details."
    pause_if_interactive
    exit "$exit_code"
}

#####################################################################
# Function: handle_error
# Description: ERR trap handler for unexpected command failures.
# Reports the step that was running so the message says what failed.
# Parameters: $1 - Exit code, $2 - Line number
#####################################################################
handle_error() {
    fail "Step '$CURRENT_STEP' failed (exit code $1, line $2)." "$1"
}

#####################################################################
# Function: cleanup
# Description: EXIT trap handler. Stops the sudo keep-alive loop and
# its sleep child.
#####################################################################
cleanup() {
    if [ -n "$SUDO_KEEPALIVE_PID" ]; then
        pkill -P "$SUDO_KEEPALIVE_PID" 2> /dev/null || true
        kill "$SUDO_KEEPALIVE_PID" 2> /dev/null || true
    fi
}

#####################################################################
# Function: rotate_log
# Description: Moves the log to LOG_FILE.1 when it exceeds MAX_LOG_SIZE
#####################################################################
rotate_log() {
    if [ -f "$LOG_FILE" ] && [ "$(stat -c %s "$LOG_FILE")" -gt "$MAX_LOG_SIZE" ]; then
        mv -f "$LOG_FILE" "$LOG_FILE.1"
    fi
}

#####################################################################
# Function: check_network
# Description: Verifies internet connectivity (5 second timeout per host)
# Returns: 0 if connected, 1 if not
#####################################################################
check_network() {
    ping -c 1 -W 5 8.8.8.8 &> /dev/null || ping -c 1 -W 5 1.1.1.1 &> /dev/null
}

#####################################################################
# Function: check_free_space
# Description: Verifies a filesystem has enough free space
# Parameters: $1 - Path on the filesystem, $2 - Required free space in KB
# Returns: 0 if enough space, 1 if not
#####################################################################
check_free_space() {
    local path="$1"
    local required="$2"
    local available
    # -P forces one line per filesystem so NR==2 is always the data row
    available=$(df -Pk "$path" | awk 'NR==2 {print $4}')
    if [ "$available" -lt "$required" ]; then
        log_message "Insufficient space on $path. Required: ${required}KB, Available: ${available}KB"
        return 1
    fi
    return 0
}

#####################################################################
# Function: check_boot_space
# Description: Kernel upgrades write a new kernel and initrd to /boot.
# When /boot is its own (usually small) partition, check it separately.
# Returns: 0 if enough space or /boot is not separate, 1 if not
#####################################################################
check_boot_space() {
    if mountpoint -q /boot; then
        check_free_space /boot "$REQUIRED_BOOT_SPACE"
    fi
}

#####################################################################
# Function: repair_dpkg
# Description: If a previous run was interrupted (terminal closed, power
# loss), dpkg is left with half-configured packages and apt refuses to
# run. 'dpkg --audit' lists such packages; if any exist, finish
# configuring them.
#####################################################################
repair_dpkg() {
    if [ -n "$(dpkg --audit 2> /dev/null)" ]; then
        log_message "Found interrupted package operations, running dpkg --configure -a"
        sudo env DEBIAN_FRONTEND=noninteractive dpkg \
            --force-confdef --force-confold --configure -a
    fi
}

#####################################################################
# Function: get_held_back
# Description: Lists packages that still have an upgrade available after
# full-upgrade (packages on hold, or Ubuntu phased updates not yet
# offered to this machine). Prints space separated names, or nothing.
#####################################################################
get_held_back() {
    apt list --upgradable 2> /dev/null | awk -F/ '/\// {print $1}' | paste -sd ' ' - || true
}

#####################################################################
# Function: get_last_run
# Description: Prints the last successful run timestamp
# Returns: 0 if a valid timestamp exists, 1 if missing or corrupt
#####################################################################
get_last_run() {
    local value
    if [ -f "$LAST_RUN_FILE" ]; then
        value=$(< "$LAST_RUN_FILE")
        if [[ "$value" =~ ^[0-9]+$ ]]; then
            echo "$value"
            return 0
        fi
    fi
    return 1
}

#####################################################################
# Function: should_run_update
# Description: Determines if enough time has passed since the last update
# Returns:
#   0 (true) - if update should run (forced, first run, corrupt record,
#              or more than UPDATE_INTERVAL_DAYS since last run)
#   1 (false) - if update should not run yet
#####################################################################
should_run_update() {
    local last_run
    if [ "$FORCE" -eq 1 ]; then
        return 0
    fi
    last_run=$(get_last_run) || return 0
    (( $(date +%s) - last_run > UPDATE_INTERVAL ))
}

#####################################################################
# Function: start_sudo
# Description: Asks for the sudo password once up front, then refreshes
# the sudo timestamp in the background so a long upgrade does not stop
# halfway to ask again. The loop closes the lock descriptor (9) and
# detaches from the log pipe so it cannot hold either open after exit.
#####################################################################
start_sudo() {
    sudo -v || fail "Could not obtain sudo privileges."
    (
        trap - ERR
        while kill -0 "$$" 2> /dev/null && sudo -n true 2> /dev/null; do
            sleep 60
        done
    ) 9>&- < /dev/null > /dev/null 2>&1 &
    SUDO_KEEPALIVE_PID=$!
}

#####################################################################
# Function: apt_run
# Description: Runs apt-get as root non-interactively with APT_OPTS
# Parameters: apt-get subcommand and arguments
#####################################################################
apt_run() {
    sudo env DEBIAN_FRONTEND=noninteractive apt-get "${APT_OPTS[@]}" "$@"
}

# Parse command line arguments
for arg in "$@"; do
    case "$arg" in
        -f|--force) FORCE=1 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; usage >&2; exit 2 ;;
    esac
done

# Only one copy may run at a time
exec 9> "$LOCK_FILE"
if ! flock -n 9; then
    show_message "Update Status" "Another system update is already running."
    pause_if_interactive
    exit 0
fi

# Verify if update should proceed
if ! should_run_update; then
    last_update=$(get_last_run)
    last_update_date=$(get_human_readable_date "$last_update")
    next_update_date=$(get_human_readable_date "$((last_update + UPDATE_INTERVAL))")

    message="System update not needed yet.

Last update was on: $last_update_date
Next update scheduled for: $next_update_date

Run with --force to update now."
    show_message "Update Status" "$message"
    pause_if_interactive
    exit 0
fi

# Configure output logging
rotate_log
exec > >(tee -a "$LOG_FILE" 9>&-) 2>&1
log_message "Update started"

# Perform pre-update checks
step "Performing pre-update checks"
check_network || fail "No internet connection available."
check_free_space /var/cache/apt/archives "$REQUIRED_SPACE" \
    || fail "Insufficient disk space for downloading packages."
check_boot_space \
    || fail "Not enough free space on /boot for a kernel update. Run 'sudo apt-get autoremove' to remove old kernels."
start_sudo

# System Update Process:

# Step 1: Finish any package operations left half done by an interrupted run
step "Checking for interrupted package operations"
repair_dpkg

# Step 2: Update package index
step "Updating package index"
apt_run update

# Step 3: Upgrade installed packages, including ones whose dependencies changed
# (full-upgrade does everything 'upgrade' does, so a separate 'upgrade' is not needed)
step "Performing full upgrade"
apt_run full-upgrade

# Step 4: Note any packages that were not upgraded (held or phased)
held_back=$(get_held_back)
if [ -n "$held_back" ]; then
    log_message "Not upgraded (held or phased rollout): $held_back"
fi

# Step 5: Update Flatpak applications and runtimes
if command -v flatpak &> /dev/null; then
    step "Updating Flatpak applications"
    flatpak update -y --noninteractive
fi

# System Cleanup Process:

# Step 1: Remove orphaned packages and dependencies
step "Removing orphaned packages"
apt_run autoremove

# Step 2: Remove Flatpak runtimes no longer used by any application
if command -v flatpak &> /dev/null; then
    step "Removing unused Flatpak runtimes"
    flatpak uninstall --unused -y --noninteractive
fi

# Step 3: Clear local repository of retrieved package files
step "Cleaning package cache"
apt_run clean

# Record successful completion time for next run calculation.
# Done before the final message so closing the terminal at the prompt
# cannot lose the record.
date +%s > "$LAST_RUN_FILE"
log_message "System update completed successfully!"

completion_message="Your system has been successfully updated."
if [ -n "$held_back" ]; then
    completion_message="$completion_message

Not upgraded (held or phased rollout): $held_back"
fi
if [ -f /run/reboot-required ]; then
    completion_message="$completion_message

A reboot is required to finish applying updates."
    log_message "Reboot required."
fi

show_message "System Update Complete" "$completion_message"
pause_if_interactive
