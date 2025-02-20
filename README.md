# Linux Weekly Update Script

A robust and user-friendly Bash script for automating system updates on Linux systems. This script performs comprehensive system maintenance while incorporating safety checks and user notifications.

## Features

- 🔄 **Automated Weekly Updates**: Runs system updates once per week
- 🔍 **Pre-update Safety Checks**:
  - Network connectivity verification
  - Disk space validation
- 📦 **Comprehensive Updates**:
  - APT package updates and upgrades
  - Full system upgrade (handles dependency changes)
  - Flatpak application updates (if installed)
  - System cleanup and cache management
- 📝 **Detailed Logging**:
  - Timestamps for all operations
  - Comprehensive error logging
  - Operation history tracking
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
   git clone https://github.com/yourusername/linux-weekly-update.git
   cd linux-weekly-update
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

The script will:
1. Check if an update is needed (based on last run time)
2. Perform safety checks (network, disk space)
3. Run system updates
4. Clean up unnecessary packages
5. Notify you of completion

### Update Schedule

- Updates run once every 7 days
- If run earlier, the script will show:
  - Last update date
  - Next scheduled update date
  - Option to force update (coming soon)

### Log Files

- Update logs: `~/update_log.txt`
- Last run timestamp: `~/.last_update_run`

## Configuration

The script uses several configurable variables at the top of the file:

```bash
LOG_FILE="$HOME/update_log.txt"          # Log file location
LAST_RUN_FILE="$HOME/.last_update_run"   # Update tracking file
REQUIRED_SPACE=1000000                   # Required free space (1GB in KB)
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

- [ ] Add force update option
- [ ] Configurable update schedule
- [ ] Backup creation before updates
- [ ] Custom update configurations
- [ ] Additional package manager support 