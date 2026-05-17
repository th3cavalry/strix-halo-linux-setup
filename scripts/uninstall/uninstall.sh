#!/bin/bash

# ==============================================================================
# Uninstall Script for ASUS ROG Flow Z13 (GZ302) Setup
#
# Author: th3cavalry using Copilot
# Version: 6.0.0
#
# This script completely removes:
# - z13ctl daemon, binary, and systemd units
# - Hardware fixes (kernel parameters, modprobe configs)
# - Power/Display management tools (pwrcfg, rrcfg wrappers)
# - RGB control wrappers (gz302-rgb)
# - Command Center (Tray Icon)
# - Systemd services and udev rules
# - Configuration files and logs
#
# USAGE:
# 1. Make executable: chmod +x uninstall.sh
# 2. Run with sudo: sudo ./uninstall.sh
# ==============================================================================

set -euo pipefail

# --- Color codes for output ---
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_CYAN='\033[0;36m'
C_BOLD='\033[1m'
C_NC='\033[0m'

# --- Logging functions ---
info() { echo -e "${C_CYAN}INFO:${C_NC} $1"; }
success() { echo -e "${C_GREEN}SUCCESS:${C_NC} $1"; }
warning() { echo -e "${C_YELLOW}WARNING:${C_NC} $1"; }
error() { echo -e "${C_RED}ERROR:${C_NC} $1" >&2; exit 1; }

check_root() {
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        error "This script must be run as root."
    fi
}

remove_file() {
    if [[ -f "$1" ]]; then
        rm -f "$1"
        echo -e "  Removed file: $1"
    fi
}

remove_dir() {
    if [[ -d "$1" ]]; then
        rm -rf "$1"
        echo -e "  Removed directory: $1"
    fi
}

disable_service() {
    if systemctl list-unit-files "$1" &>/dev/null; then
        systemctl stop "$1" 2>/dev/null || true
        systemctl disable "$1" 2>/dev/null || true
        echo -e "  Disabled service: $1"
    fi
    remove_file "/etc/systemd/system/$1"
}

# --- Main Uninstall Logic ---

main() {
    check_root
    
    echo -e "${C_BOLD}ASUS GZ302 Cleanup Utility${C_NC}"
    echo "This will remove all Strix Halo tools, services, and configurations."
    echo
    read -r -p "Are you sure you want to proceed? [y/N] " response
    if [[ ! "$response" =~ ^[yY]$ ]]; then
        echo "Aborted."
        exit 0
    fi
    
    echo
    info "Stopping services..."
    # Power Management
    disable_service "pwrcfg-auto.service"
    disable_service "pwrcfg-monitor.service"
    disable_service "pwrcfg-resume.service"
    
    # Battery Management
    disable_service "battery-charge-limit.service"

    # RGB Persistence
    disable_service "gz302-rgb-restore.service"
    disable_service "gz302-kbd-backlight-save.service"
    disable_service "gz302-lightbar-reset.service"
    
    # Legacy services
    disable_service "reload-hid_asus.service"
    disable_service "reload-hid_asus-resume.service"
    disable_service "gz302-kbd-backlight-restore.service"
    
    # Reload systemd
    systemctl daemon-reload
    
    echo
    info "Removing z13ctl..."
    # Stop and disable z13ctl user daemon for all users
    for home in /home/*; do
        local user
        user=$(basename "$home")
        sudo -u "$user" systemctl --user stop z13ctl.service z13ctl.socket 2>/dev/null || true
        sudo -u "$user" systemctl --user disable z13ctl.service z13ctl.socket 2>/dev/null || true
        remove_file "$home/.config/systemd/user/z13ctl.service"
        remove_file "$home/.config/systemd/user/z13ctl.socket"
    done
    # Remove z13ctl binary (only if installed manually, not via package manager)
    if [[ -f /usr/local/bin/z13ctl ]]; then
        remove_file "/usr/local/bin/z13ctl"
    else
        info "z13ctl installed via package manager — use your package manager to remove it"
    fi
    # z13ctl system-level permissions service
    disable_service "z13ctl-perms.service"

    echo
    info "Removing binaries and scripts..."
    # Power/Display Tools
    remove_file "/usr/local/bin/pwrcfg"
    remove_file "/usr/local/bin/pwrcfg-monitor"
    remove_file "/usr/local/bin/pwrcfg-restore"
    remove_file "/usr/local/bin/rrcfg"
    remove_file "/usr/share/icons/hicolor/scalable/apps/strix-halo-control-center.svg"
    remove_file "/usr/share/icons/hicolor/scalable/apps/strix-halo-power-manager.svg"
    
    # Battery Management
    remove_file "/usr/local/bin/set-battery-limit.sh"

    # RGB Tools
    remove_file "/usr/local/bin/gz302-rgb"
    remove_file "/usr/local/bin/gz302-rgb-bin"
    remove_file "/usr/local/bin/gz302-rgb-wrapper"
    remove_file "/usr/local/bin/gz302-rgb-window"
    remove_file "/usr/local/bin/gz302-rgb-restore"
    
    # Legacy/Misc
    remove_file "/usr/local/bin/gz302-folio-resume.sh"
    remove_file "/usr/lib/systemd/system-sleep/gz302-kbd-backlight"
    remove_file "/usr/lib/systemd/system-sleep/gz302-reset.sh"
    
    echo
    info "Removing Command Center / GUI..."
    remove_dir "/usr/local/share/gz302"
    remove_file "/usr/local/bin/strix-halo-control-center"
    remove_file "/usr/share/applications/strix-halo-control-center.desktop"
    remove_file "/etc/xdg/autostart/strix-halo-control-center.desktop"
    remove_file "/usr/share/applications/strix-halo-tray.desktop"  # Legacy name
    
    # Remove from all users' autostart (best effort)
    for home in /home/*; do
        remove_file "$home/.config/autostart/strix-halo-control-center.desktop"
        remove_file "$home/.config/autostart/strix-halo-tray.desktop"
        remove_file "$home/.local/share/applications/strix-halo-tray.desktop"
    done
    
    echo
    info "Removing configuration..."
    remove_dir "/etc/strix-halo"
    remove_dir "/var/lib/gz302"
    remove_dir "/var/log/gz302"

    # Remove legacy config dirs
    remove_dir "/etc/strix-halo-tdp"
    remove_dir "/etc/strix-halo-refresh"
    remove_dir "/etc/strix-halo-rgb"

    echo
    info "Removing system integration..."
    # Sudoers
    remove_file "/etc/sudoers.d/strix-halo-pwrcfg"
    remove_file "/etc/sudoers.d/strix-halo-rgb"
    remove_file "/etc/sudoers.d/strix-halo-command-center"
    remove_file "/etc/sudoers.d/strix-halo"
    remove_file "/etc/sudoers.d/z13ctl"
    remove_file "/etc/sudoers.d/pwrcfg" # Legacy
    
    # Udev rules
    remove_file "/etc/udev/rules.d/99-gz302-rgb.rules"
    remove_file "/etc/udev/rules.d/99-gz302-keyboard.rules" # Legacy

    # NetworkManager configuration
    remove_file "/etc/NetworkManager/conf.d/wifi-powersave.conf"

    udevadm control --reload || true
    
    # Modprobe configs
    remove_file "/etc/modprobe.d/mt7925.conf"
    remove_file "/etc/modprobe.d/amdgpu.conf"
    remove_file "/etc/modprobe.d/hid-asus.conf"
    remove_file "/etc/modprobe.d/i2c-hid-acpi-gz302.conf"
    remove_file "/etc/modprobe.d/cs35l41.conf"
    
    # ASUS Daemon override
    remove_file "/etc/systemd/system/asusd.service.d/gz302-lightbar.conf"
    if [[ -d "/etc/systemd/system/asusd.service.d" ]]; then
        rmdir --ignore-fail-on-non-empty "/etc/systemd/system/asusd.service.d"
    fi
    
    echo
    success "Uninstallation complete."
    warning "A reboot is recommended to clear running kernel modules and processes."
}

main "$@"
