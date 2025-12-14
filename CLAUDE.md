
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This project automates the setup and configuration of V2ray service on Linux systems. The main script orchestrates:

1. V2ray installation via the official installer script
2. Systemd service configuration (setting V2RAY_VMESS_AEAD_FORCED=false)
3. System daemon reload and service restart
4. Service enablement on boot
5. BBR (TCP congestion control) configuration
6. UFW firewall rules for port 52821
7. Interactive V2ray configuration

## Architecture

The project consists of a single bash script that handles the complete V2ray setup workflow:

- **v2ray-auto-setup.sh**: Main automation script that orchestrates all installation and configuration steps sequentially. The script:
  - Uses colored logging output for user feedback
  - Creates timestamped log files in /tmp
  - Performs prerequisite checks (root privilege verification)
  - Includes error handling with trap on line errors
  - Provides rollback functionality by backing up the systemd service file before modifications
  - Exits immediately on any error (set -e)

### Key Design Patterns

1. **Modular Functions**: Each setup step is a separate function (install_v2ray, configure_systemd_service, etc.) for clarity
2. **Logging**: Utility functions (log_info, log_success, log_warning, log_error) provide consistent colored output
3. **Idempotency**: Functions check if steps are already completed before executing (e.g., checking if v2ray is installed)
4. **Error Handling**: trap on line 238 catches errors and offers rollback options
5. **User Feedback**: Each major step is clearly delineated with separators and status messages

## Common Commands

**Run the setup script:**
```bash
sudo bash v2ray-auto-setup.sh
```

**Check V2ray service status:**
```bash
systemctl status v2ray
```

**View service logs:**
```bash
journalctl -u v2ray -f
```

**Restart V2ray:**
```bash
service v2ray restart
```

**Edit V2ray configuration:**
```bash
nano /etc/v2ray/config.json
```

## Important Implementation Details

- Script requires **root privileges** (enforced on line 53-56)
- Log files are created in `/tmp/v2ray-setup-TIMESTAMP.log` (line 23)
- Service file backup is created at `/lib/systemd/system/v2ray.service.backup` before modifications
- The V2RAY_VMESS_AEAD_FORCED environment variable is inserted directly after the [Service] section header using sed
- BBR and firewall configuration commands (v2ray bbr, ufw allow) may require additional packages
- The interactive configuration step (line 173) is blocking and requires user input

## Testing Considerations

When making changes:
- The script should be tested in a clean Linux environment with root access
- Changes to systemd service file modifications should verify the sed command produces valid systemd syntax
- The interactive_v2ray_config function may need adjustment if v2ray's CLI interface changes
- Verify the official V2ray installer script location (https://git.io/v2ray.sh) is still valid