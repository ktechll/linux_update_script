# Linux Weekly Update Script

A robust and user-friendly Bash script for automating system updates on Linux systems. This script performs comprehensive system maintenance while incorporating safety checks and user notifications.

## Features

- 🔄 **Automated Weekly Updates**: Runs system updates once per week
- 🔍 **Pre-update Safety Checks**:
  - Network connectivity verification
  - Disk space validation (including a separate `/boot` partition, where kernel upgrades usually run out of room)
  - Automatic repair of package operations left half done by an interrupted run (`dpkg --configure -a`)
  - Single-instance lock (a second copy exits instead of fighting over apt)
- 📦 **Comprehensive Updates**:
  - APT package index refresh and full upgrade (handles dependency changes)
  - Non-interactive apt runs that keep existing config files and wait for the apt lock
  - Flatpak application updates and unused runtime cleanup (if installed)
  - System cleanup and cache management
  - Reboot-required notice after updates
  - Report of packages that were not upgraded (held, or Ubuntu phased rollout)
- 📝 **Detailed Logging**:
  - Timestamps for all operations
  - Error messages name the step that failed
  - Operation history tracking
  - Automatic log rotation at 5MB
- 🔔 **User Notifications**:
  - Desktop notifications (if `notify-send` is available)
  - Clear terminal output with status messages
  - Update schedule information
- ⚠️ **Error Handling**:
  - Graceful error management
  - Detailed error reporting
  - Safe exit on critical failures

## Prerequisites

- Ubuntu/Debian-based Linux system
- `sudo` privileges
- Optional: `notify-send` for desktop notifications
- Optional: `flatpak` for Flatpak package updates

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/ktechll/linux_update_script.git
   cd linux_update_script
   ```

2. Make the script executable:
   ```bash
   chmod +x weekly_update.sh
   ```

3. Optional: Create a desktop shortcut
   ```bash
   # Create a .desktop file in your applications directory
   cat > ~/.local/share/applications/weekly-update.desktop << EOL
   [Desktop Entry]
   Name=System Weekly Update
   Comment=Run system updates and maintenance
   Exec=/path/to/weekly_update.sh
   Terminal=true
   Type=Application
   Categories=System;
   Icon=system-software-update
   EOL
   ```

## Usage

### Running the Script

Simply execute the script:
```bash
./weekly_update.sh
```

Force an update regardless of when it last ran:
```bash
./weekly_update.sh --force
```

The script will:
1. Check that no other copy is running
2. Check if an update is needed (based on last run time)
3. Perform safety checks (network, disk space, `/boot` space)
4. Ask for the sudo password once and keep it active for the whole run
5. Repair any interrupted package operations from a previous run
6. Run system updates
7. Clean up unnecessary packages and unused Flatpak runtimes
8. Record the run time and notify you of completion (including any packages not upgraded and whether a reboot is needed)

When run from a terminal, the script waits for Enter before closing so the result can be read. When run without a terminal (cron, systemd), it does not wait.

### Update Schedule

- Updates run when more than 6 days have passed since the last successful run, so running it on the same weekday each week always qualifies even if started earlier in the day
- If run earlier, the script will show:
  - Last update date
  - Next scheduled update date
  - A reminder that `--force` runs it anyway

### Log Files

- Update logs: `~/update_log.txt` (previous log kept as `~/update_log.txt.1` after rotation)
- Last run timestamp: `~/.last_update_run`

## Configuration

The script uses several configurable variables at the top of the file:

```bash
LOG_FILE="$HOME/update_log.txt"                        # Log file location
LAST_RUN_FILE="$HOME/.last_update_run"                 # Update tracking file
LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/weekly_update.lock" # Single-instance lock
REQUIRED_SPACE=1000000                                 # Required free space (1GB in KB)
REQUIRED_BOOT_SPACE=150000                             # Required free space on a separate /boot (~150MB in KB)
UPDATE_INTERVAL_DAYS=6                                 # Run when more than this many days have passed
MAX_LOG_SIZE=5242880                                   # Rotate log above this size (5MB)
```

## Error Handling

The script includes comprehensive error handling:
- Network connectivity checks
- Disk space verification
- Command execution validation
- Detailed error logging
- User notifications for failures

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Inspired by the need for automated system maintenance
- Built with user experience and system safety in mind
- Thanks to the Linux community for testing and feedback

## Future Enhancements

- [x] Add force update option
- [x] Configurable update schedule
- [ ] Backup creation before updates
- [ ] Custom update configurations
- [ ] Additional package manager support 