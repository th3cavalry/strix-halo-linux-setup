#!/bin/bash

# ==============================================================================
# Strix Halo Gaming Module
# Version: 6.8.0
#
# This module installs gaming software for the ASUS ROG Flow Z13 (GZ302)
# Includes: Steam, Lutris, MangoHUD, GameMode, Wine, and performance tools
#
# This script is designed to be called by strix-halo-setup.sh
# ==============================================================================

set -euo pipefail

# --- Script directory detection ---
resolve_script_dir() {
    local source="${BASH_SOURCE[0]}"
    while [[ -L "$source" ]]; do
        local dir
        dir=$(cd -P "$(dirname "$source")" && pwd)
        source=$(readlink "$source")
        [[ $source != /* ]] && source="${dir}/${source}"
    done
    cd -P "$(dirname "$source")" && pwd
}

SCRIPT_DIR="${SCRIPT_DIR:-$(resolve_script_dir)}"

# --- Load Shared Utilities ---
if [[ -f "${SCRIPT_DIR}/../strix-halo-lib/utils.sh" ]]; then
    # shellcheck source=/dev/null
    source "${SCRIPT_DIR}/../strix-halo-lib/utils.sh"
elif [[ -f "${SCRIPT_DIR}/strix-halo-utils.sh" ]]; then
    # shellcheck source=/dev/null
    source "${SCRIPT_DIR}/strix-halo-utils.sh"
else
    echo "strix-halo-utils.sh not found. Downloading..."
    mkdir -p "$(dirname "${SCRIPT_DIR}/strix-halo-utils.sh")" || { echo "Error: Failed to create directory"; exit 1; }
    GITHUB_RAW_URL="${GITHUB_RAW_URL:-https://raw.githubusercontent.com/th3cavalry/strix-halo-linux-setup/main}"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "${GITHUB_RAW_URL}/strix-halo-lib/utils.sh" -o "${SCRIPT_DIR}/strix-halo-utils.sh" || { echo "Error: curl failed"; exit 1; }
    elif command -v wget >/dev/null 2>&1; then
        wget "${GITHUB_RAW_URL}/strix-halo-lib/utils.sh" -O "${SCRIPT_DIR}/strix-halo-utils.sh"
    else
        echo "Error: curl or wget not found. Cannot download utils."
        exit 1
    fi
    
    if [[ -f "${SCRIPT_DIR}/strix-halo-utils.sh" ]]; then
        chmod +x "${SCRIPT_DIR}/strix-halo-utils.sh"
        # shellcheck source=/dev/null
        source "${SCRIPT_DIR}/strix-halo-utils.sh"
    else
        echo "Error: Failed to download strix-halo-utils.sh"
        exit 1
    fi
fi

# --- Main Installation Logic ---

install_gaming_stack() {
    print_section "Installing Gaming Software Stack"
    
    local distro
    distro=$(detect_distribution)
    
    case "$distro" in
        arch)
            info "Installing Gaming packages for Arch Linux..."
            
            # Check for CachyOS
            if grep -q "CachyOS" /etc/os-release; then
                info "CachyOS detected - using optimized gaming meta-packages..."
                pacman -S --noconfirm --needed cachyos-gaming-meta cachyos-gaming-applications
            else
                # Enable multilib if not enabled
                if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
                    info "Enabling multilib repository..."
                    printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' >> /etc/pacman.conf
                    pacman -Sy
                fi
                
                # Install packages (Using standard wine as requested)
                pacman -S --noconfirm --needed \
                    steam \
                    lutris \
                    mangohud lib32-mangohud \
                    gamemode lib32-gamemode \
                    wine \
                    winetricks
            fi
            ;;
            
        debian|ubuntu)
            info "Installing Gaming packages for Debian/Ubuntu..."
            # Enable 32-bit architecture
            dpkg --add-architecture i386
            apt-get update
            
            # Install Steam
            apt-get install -y steam-installer || apt-get install -y steam
            
            # Install Lutris, MangoHUD, GameMode
            apt-get install -y lutris mangohud gamemode wine winetricks
            ;;
            
        fedora)
            info "Installing Gaming packages for Fedora..."
            # Enable RPM Fusion if possible (usually needed for Steam/Lutris)
            # We assume user might have it, or we try best effort
            dnf install -y steam lutris mangohud gamemode wine winetricks
            ;;
            
        opensuse)
            info "Installing Gaming packages for OpenSUSE..."
            zypper install -y steam lutris mangohud gamemode wine winetricks
            ;;
            
        *)
            warning "Unsupported distribution: $distro"
            return 1
            ;;
    esac
    
    # --- Optimizations ---
    print_subsection "Applying Gaming Optimizations"
    
    # Increase map count for some games (CS2, DayZ, etc)
    local sysctl_file="/etc/sysctl.d/99-gaming.conf"
    if [[ ! -f "$sysctl_file" ]]; then
        info "Setting vm.max_map_count to 2147483642..."
        echo "vm.max_map_count = 2147483642" > "$sysctl_file"
        sysctl -p "$sysctl_file" 2>/dev/null || true
    fi
    
    success "Gaming stack installed!"
}

main() {
    # Check root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi
    
    print_banner "Strix Halo Gaming Module"
    install_gaming_stack
}

main "$@"
