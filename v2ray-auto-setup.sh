#!/bin/bash

################################################################################
# V2ray Auto Setup Script
#
# This script automates the installation and configuration of V2ray service
# with all necessary system-level configurations.
################################################################################

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
V2RAY_SERVICE_FILE="/lib/systemd/system/v2ray.service"
V2RAY_CONFIG_MARKER="V2RAY_VMESS_AEAD_FORCED"
SCRIPT_NAME=$(basename "$0")
LOG_FILE="/tmp/v2ray-setup-$(date +%Y%m%d-%H%M%S).log"

################################################################################
# Utility Functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

print_separator() {
    echo -e "${BLUE}=================================================================================${NC}"
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
    log_success "Running as root"

    print_separator
}

install_v2ray() {
    log_info "Step 1: Installing V2ray..."

    if command -v v2ray &> /dev/null; then
        log_warning "V2ray is already installed. Skipping installation"
        return 0
    fi

    log_info "Running V2ray official installer script..."
    # bash <(wget -qO- -o- https://git.io/v2ray.sh) 2>&1 | tee -a "$LOG_FILE"
    bash <(wget -qO- -o- https://raw.githubusercontent.com/woshihuo12/v2ray/master/install.sh) 2>&1 | tee -a "$LOG_FILE"

    if command -v v2ray &> /dev/null; then
        log_success "V2ray installed successfully"
    else
        log_error "V2ray installation failed"
        exit 1
    fi

    print_separator
}

configure_systemd_service() {
    log_info "Step 2: Configuring systemd service..."

    if [[ ! -f "$V2RAY_SERVICE_FILE" ]]; then
        log_error "V2ray service file not found at $V2RAY_SERVICE_FILE"
        exit 1
    fi

    # Check if configuration already exists
    if grep -q "$V2RAY_CONFIG_MARKER" "$V2RAY_SERVICE_FILE"; then
        log_warning "V2RAY_VMESS_AEAD_FORCED is already configured"
        return 0
    fi

    # Create backup
    log_info "Creating backup of service file..."
    cp "$V2RAY_SERVICE_FILE" "${V2RAY_SERVICE_FILE}.backup"
    log_success "Backup created at ${V2RAY_SERVICE_FILE}.backup"

    # Find the [Service] section and add the environment variable
    log_info "Adding V2RAY_VMESS_AEAD_FORCED=false to service file..."

    if grep -q "^\[Service\]" "$V2RAY_SERVICE_FILE"; then
        # Add environment variable after [Service] section
        sed -i '/^\[Service\]/a Environment="V2RAY_VMESS_AEAD_FORCED=false"' "$V2RAY_SERVICE_FILE"
        log_success "Environment variable added to service file"
    else
        log_error "Could not find [Service] section in $V2RAY_SERVICE_FILE"
        exit 1
    fi

    print_separator
}

reload_and_restart_service() {
    log_info "Step 3: Reloading systemd and restarting V2ray service..."

    log_info "Running systemctl daemon-reload..."
    systemctl daemon-reload
    log_success "Daemon reloaded"

    log_info "Restarting V2ray service..."
    service v2ray restart
    log_success "V2ray service restarted"

    # Verify service is running
    if systemctl is-active --quiet v2ray; then
        log_success "V2ray service is running"
    else
        log_error "V2ray service failed to start"
        exit 1
    fi

    print_separator
}

enable_service_on_boot() {
    log_info "Step 4: Enabling V2ray service on boot..."

    systemctl enable v2ray
    log_success "V2ray enabled on boot"

    print_separator
}

configure_bbr() {
    log_info "Step 5: Configuring BBR"

    v2ray bbr

    print_separator
}

configure_firewall() {
    log_info "Step 6: Configuring firewall rules..."
    log_info "Adding firewall rule for V2ray port 52821..."
    ufw allow 52821/tcp
    log_success "Firewall rule added"

    print_separator
}

interactive_v2ray_config() {
    log_info "Step 7: Interactive V2ray Configuration..."
    log_info "The V2ray service is now running. You need to configure it with your settings."

    echo -e "\n${YELLOW}Starting V2ray interactive configuration...${NC}\n"

    # Run v2ray in interactive mode for configuration
    # This will prompt user for protocol, port, and other settings
    # v2ray 2>&1 | tee -a "$LOG_FILE"
    v2ray port vmess 52821 | tee -a "$LOG_FILE"

    print_separator
}

show_summary() {
    print_separator
    echo -e "\n${GREEN}V2ray Auto Setup Complete!${NC}\n"

    echo "Summary of completed tasks:"
    echo "  ✓ V2ray installed"
    echo "  ✓ Systemd service configured with V2RAY_VMESS_AEAD_FORCED=false"
    echo "  ✓ Service restarted and verified"
    echo "  ✓ Service enabled on boot"
    echo "  ✓ BBR configure"
    echo "  ✓ Firewall rules configured"
    echo "  ✓ Interactive configuration completed"

    echo -e "\n${BLUE}Useful commands:${NC}"
    echo "  Check service status:  systemctl status v2ray"
    echo "  View service logs:     journalctl -u v2ray -f"
    echo "  Edit config:           nano /etc/v2ray/config.json"
    echo "  Restart service:       service v2ray restart"

    echo -e "\n${BLUE}Log file: $LOG_FILE${NC}\n"
}

error_handler() {
    local line_number=$1
    log_error "Setup failed at line $line_number"

    # Offer rollback option
    echo -e "\n${YELLOW}Rollback option:${NC}"
    if [[ -f "${V2RAY_SERVICE_FILE}.backup" ]]; then
        echo "Service file backup is available at: ${V2RAY_SERVICE_FILE}.backup"
        read -p "Do you want to restore the backup? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cp "${V2RAY_SERVICE_FILE}.backup" "$V2RAY_SERVICE_FILE"
            systemctl daemon-reload
            log_info "Service file restored from backup"
        fi
    fi

    exit 1
}

################################################################################
# Main Execution
################################################################################

main() {
    clear
    print_separator
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}                     V2ray Automatic Setup Script                            ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    print_separator
    echo ""

    log_info "Setup started at $(date)"
    log_info "Log file: $LOG_FILE"
    echo ""

    # Set error handler
    trap 'error_handler ${LINENO}' ERR

    check_prerequisites
    install_v2ray
    configure_systemd_service
    reload_and_restart_service
    enable_service_on_boot
    configure_bbr
    configure_firewall
    interactive_v2ray_config
}

# Run main function
main "$@"