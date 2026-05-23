#!/bin/bash

# ==============================================================================
# Strix Halo Hypervisor Module
# Version: 6.8.0
#
# This module installs hypervisor software for the ASUS ROG Flow Z13 (GZ302)
# Includes: Full KVM/QEMU stack, VirtualBox
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
install_kvm_stack() {
    print_section "Installing Hypervisor Software (KVM/QEMU)"
    
    local distro
    distro=$(detect_distribution)
    
    case "$distro" in
        arch)
            info "Installing KVM packages for Arch Linux..."
            pacman -S --noconfirm --needed \
                qemu-full \
                virt-manager \
                virt-viewer \
                dnsmasq \
                vde2 \
                openbsd-netcat \
                libguestfs
            ;;
            
        debian|ubuntu)
            info "Installing KVM packages for Debian/Ubuntu..."
            apt-get install -y \
                qemu-system \
                libvirt-daemon-system \
                libvirt-clients \
                bridge-utils \
                virt-manager
            ;;
            
        fedora)
            info "Installing KVM packages for Fedora..."
            dnf groupinstall -y "Virtualization"
            ;;
            
        opensuse)
            info "Installing KVM packages for OpenSUSE..."
            zypper install -y -t pattern kvm_server kvm_tools
            ;;
            
        *)
            warning "Unsupported distribution: $distro"
            return 1
            ;;
    esac
    
    # --- Configuration ---
    print_subsection "Configuring Libvirt"
    
    # Enable libvirtd service
    systemctl enable --now libvirtd || warning "Failed to enable libvirtd"
    
    # Add user to libvirt group
    local real_user="${SUDO_USER:-$USER}"
    if [[ -n "$real_user" && "$real_user" != "root" ]]; then
        info "Adding user $real_user to libvirt group..."
        usermod -aG libvirt "$real_user" 2>/dev/null || true
        # Also kvm group just in case
        usermod -aG kvm "$real_user" 2>/dev/null || true
    fi
    
    # Set URI default
    if [[ -n "$real_user" ]]; then
        local user_home
        user_home=$(getent passwd "$real_user" | cut -d: -f6)
        if [[ -d "$user_home" ]]; then
             # Default to system connection for KVM
             if ! grep -q "LIBVIRT_DEFAULT_URI" "$user_home/.bashrc"; then
                 echo "export LIBVIRT_DEFAULT_URI='qemu:///system'" >> "$user_home/.bashrc"
             fi
        fi
    fi
    
    success "Hypervisor stack installed!"
}

main() {
    # Check root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi
    
    print_banner "Strix Halo Hypervisor Module"
    install_kvm_stack
}

main "$@"
