#!/bin/bash

# ==============================================================================
# Strix Halo Linux Setup — Unified Installer
# Author: th3cavalry using Copilot
# Version: 6.8.0
#
# Supported devices (Strix Halo platform — AMD Ryzen AI MAX / MAX+):
# BEGIN AUTO-GENERATED SUPPORTED DEVICES
# AUTO-GENERATED from strix-halo-lib/device-profile-data.sh via scripts/sync-device-matrix.sh.
# - ASUS ROG Flow Z13 (GZ302) — full support (Full stack)
# - HP ZBook Ultra G1a — partial support (Dashboard + core stack)
# - HP Mini Workstation (Z2 G1a) — partial support (Dashboard + core stack)
# - Framework Desktop — partial support (Dashboard + core stack)
# - ASUS TUF Gaming A14 — partial support (Dashboard + ASUS control)
# - Sixunited AXP77 — experimental (Dashboard + baseline stack)
# - GMKtec EVO-X2 — experimental (Dashboard + baseline stack)
# - Minisforum MS-S1 Max — experimental (Dashboard + baseline stack)
# - AYANEO NEXT 2 — experimental (Dashboard + baseline stack)
# - GPD Win 5 — experimental (Dashboard + baseline stack)
# - Other confirmed Strix Halo — experimental baseline (Dashboard + baseline stack)
# END AUTO-GENERATED SUPPORTED DEVICES
#
# Hardware detection automatically selects only the relevant fixes and
# sections for the running device.
#
# Hardware control backend: z13ctl (https://github.com/dahui/z13ctl)
# Protocol reference: g-helper (https://github.com/seerge/g-helper)
# GUI inspiration: Strix-Halo-Control (https://github.com/TechnoDaimon/Strix-Halo-Control)
# AI toolboxes: amd-strix-halo-toolboxes (https://github.com/kyuz0/amd-strix-halo-toolboxes)
#
# REQUIRED: Linux kernel 6.14+ minimum (6.17+ strongly recommended)
# ==============================================================================

set -euo pipefail

# --- CLI Flags ---
ASSUME_YES="${ASSUME_YES:-false}"
SKIP_FIXES=false
SKIP_Z13CTL=false
SKIP_TOOLS=false
SKIP_MODULES=false
SKIP_AI=false

print_supported_device_help() {
    # BEGIN AUTO-GENERATED SUPPORTED DEVICES HELP
    # AUTO-GENERATED from strix-halo-lib/device-profile-data.sh via scripts/sync-device-matrix.sh.
    printf '%s
' 'ASUS ROG Flow Z13 (GZ302) — Full (Full stack)'
    printf '%s
' 'HP ZBook Ultra G1a — Partial (Dashboard + core stack)'
    printf '%s
' 'HP Mini Workstation (Z2 G1a) — Partial (Dashboard + core stack)'
    printf '%s
' 'Framework Desktop — Partial (Dashboard + core stack)'
    printf '%s
' 'ASUS TUF Gaming A14 — Partial (Dashboard + ASUS control)'
    printf '%s
' 'Sixunited AXP77 — Experimental (Dashboard + baseline stack)'
    printf '%s
' 'GMKtec EVO-X2 — Experimental (Dashboard + baseline stack)'
    printf '%s
' 'Minisforum MS-S1 Max — Experimental (Dashboard + baseline stack)'
    printf '%s
' 'AYANEO NEXT 2 — Experimental (Dashboard + baseline stack)'
    printf '%s
' 'GPD Win 5 — Experimental (Dashboard + baseline stack)'
    printf '%s
' 'Other confirmed Strix Halo — Experimental baseline (Dashboard + baseline stack)'
    # END AUTO-GENERATED SUPPORTED DEVICES HELP
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--assume-yes) ASSUME_YES=true; shift ;;
        --fixes-only)    SKIP_Z13CTL=true; SKIP_TOOLS=true; SKIP_MODULES=true; shift ;;
        --tools-only)    SKIP_FIXES=true; SKIP_MODULES=true; shift ;;
        --no-fixes)      SKIP_FIXES=true; shift ;;
        --no-z13ctl)     SKIP_Z13CTL=true; shift ;;
        --no-tools)      SKIP_TOOLS=true; shift ;;
        --no-modules)    SKIP_MODULES=true; shift ;;
        -h|--help)
            cat << 'EOF'
Strix Halo Linux Setup — Unified Installer v6.8.0

Usage: sudo ./strix-halo-setup.sh [OPTIONS]

Options:
  -y, --assume-yes   Accept all defaults (non-interactive)
  --fixes-only       Apply hardware fixes only (skip z13ctl, tools, modules)
  --tools-only       Install tools only (skip hardware fixes and modules)
  --no-fixes         Skip hardware fixes
  --no-z13ctl        Skip z13ctl installation
  --no-tools         Skip display tools and tray app
  --no-modules       Skip optional modules
  -h, --help         Show this help message

Sections (each prompted with Y/n):
  1. Hardware Fixes    WiFi, GPU, Input, Audio, Display, Suspend
    2. Command Center   z13ctl on supported ASUS devices; GZ302 tray app when applicable
  3. Gaming           Steam, Lutris, MangoHUD, GameMode, Proton-GE
  4. AI / LLM         Ollama, ROCm, vLLM, ComfyUI, PyTorch
  5. Other Tools      Hypervisor (KVM/QEMU), community integrations

Hardware control powered by z13ctl: https://github.com/dahui/z13ctl
EOF
                        echo
                        echo "Supported devices:"
                        print_supported_device_help | sed 's/^/  /'
            exit 0
            ;;
        --) shift; break ;;
        -*) echo "Unknown option: $1"; exit 1 ;;
        *)  break ;;
    esac
done

# --- GitHub base URL ---
GITHUB_RAW_URL="https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main"

# --- Version (read once at startup) ---
SETUP_VERSION="6.8.0"

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
if [[ -f "${SCRIPT_DIR}/strix-halo-lib/utils.sh" ]]; then
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/strix-halo-lib/utils.sh"
else
    echo "strix-halo-lib/utils.sh not found. Downloading..."
    mkdir -p "${SCRIPT_DIR}/strix-halo-lib"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "${GITHUB_RAW_URL}/strix-halo-lib/utils.sh" -o "${SCRIPT_DIR}/strix-halo-lib/utils.sh"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "${GITHUB_RAW_URL}/strix-halo-lib/utils.sh" -O "${SCRIPT_DIR}/strix-halo-lib/utils.sh"
    else
        echo "Error: curl or wget not found."
        exit 1
    fi
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/strix-halo-lib/utils.sh"
fi

# --- Load Libraries ---
# Expected version for all library files (must match # Version: line)

load_library() {
    local lib_name="$1"
    local lib_path="${SCRIPT_DIR}/strix-halo-lib/${lib_name}"

    # Only use remote download if the file is missing locally
    if [[ -f "$lib_path" ]]; then
        # shellcheck source=/dev/null
        source "$lib_path"
        return 0
    fi

    warning "Library ${lib_name} missing locally. Cloning the repository is recommended."
    info "Downloading ${lib_name} from GitHub..."
    mkdir -p "${SCRIPT_DIR}/strix-halo-lib"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "${GITHUB_RAW_URL}/strix-halo-lib/${lib_name}" -o "$lib_path" || return 1
    elif command -v wget >/dev/null 2>&1; then
        wget -q "${GITHUB_RAW_URL}/strix-halo-lib/${lib_name}" -O "$lib_path" || return 1
    else
        error "curl or wget not found."
    fi

    # shellcheck source=/dev/null
    source "$lib_path"
    return 0
}

info "Loading libraries..."
load_library "kernel-compat.sh"   || warning "Failed to load kernel-compat.sh"
load_library "state-manager.sh"   || warning "Failed to load state-manager.sh"
load_library "distro-manager.sh"  || warning "Failed to load distro-manager.sh"
load_library "device-profile-data.sh" || warning "Failed to load device-profile-data.sh"
load_library "device-manager.sh"  || warning "Failed to load device-manager.sh"
load_library "wifi-manager.sh"    || warning "Failed to load wifi-manager.sh"
load_library "gpu-manager.sh"     || warning "Failed to load gpu-manager.sh"
load_library "input-manager.sh"   || warning "Failed to load input-manager.sh"
load_library "audio-manager.sh"   || warning "Failed to load audio-manager.sh"
load_library "display-fix.sh"     || warning "Failed to load display-fix.sh"
load_library "display-manager.sh" || warning "Failed to load display-manager.sh"

state_init >/dev/null 2>&1 || true

# ==============================================================================
# Helper Functions
# ==============================================================================

check_root() {
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        error "This script must be run as root. Please run: sudo ./strix-halo-setup.sh"
    fi
}

check_network() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsSIL --max-time 5 "https://github.com" >/dev/null 2>&1 && return 0
    fi
    if command -v ping >/dev/null 2>&1; then
        ping -c1 -W2 1.1.1.1 >/dev/null 2>&1 && return 0
    fi
    return 1
}

check_kernel_version() {
    if declare -f kernel_get_version_num >/dev/null 2>&1; then
        local kver
        kver=$(kernel_get_version_num)
        info "Detected kernel version: $(uname -r)"
        if ! kernel_meets_minimum 2>/dev/null; then
            error "Kernel 6.14+ is required. Please upgrade."
        fi
        if [[ $kver -ge 619 ]]; then
            success "Kernel 6.19+ — all hardware natively supported"
        elif [[ $kver -ge 617 ]]; then
            success "Kernel 6.17+ — recommended (WiFi/Input native)"
        else
            warning "Kernel 6.14–6.16 — some workarounds will be applied"
        fi
        echo "$kver"
    else
        local major minor
        major=$(uname -r | cut -d. -f1)
        minor=$(uname -r | cut -d. -f2)
        echo $((major * 100 + minor))
    fi
}

# Prompt helper — returns 0 for yes, 1 for no
prompt_section() {
    local prompt="$1"
    local default="${2:-Y}"
    if [[ "$ASSUME_YES" == "true" ]]; then
        return 0
    fi
    ask_yes_no "$prompt" "$default"
}

# ==============================================================================
# Legacy Cleanup (v3/v4 → v5 migration)
# ==============================================================================

cleanup_legacy_install() {
    local found_legacy=false

    # Remove v3/v4 systemd services
    local svc
    for svc in gz302-rgb-restore.service pwrcfg-auto.service gz302-lightbar.service; do
        if systemctl list-unit-files "$svc" >/dev/null 2>&1 && \
           systemctl is-enabled "$svc" >/dev/null 2>&1; then
            systemctl disable --now "$svc" 2>/dev/null || true
            rm -f "/etc/systemd/system/$svc"
            found_legacy=true
        fi
    done

    # Remove old sudoers fragments
    local f
    for f in /etc/sudoers.d/strix-halo-pwrcfg /etc/sudoers.d/strix-halo-rgb; do
        if [[ -f "$f" ]]; then
            rm -f "$f"
            found_legacy=true
        fi
    done

    # Remove v2 monolithic modprobe config (pre-library architecture)
    for f in /etc/modprobe.d/gz302.conf /etc/modprobe.d/gz302-rdna.conf \
              /etc/modprobe.d/gz302-audio.conf /etc/modprobe.d/gz302-suspend.conf; do
        if [[ -f "$f" ]]; then
            rm -f "$f"
            found_legacy=true
        fi
    done

    # Remove v3/v4 modprobe configurations (replaced by strix-halo-lib modular configs)
    for f in /etc/modprobe.d/gz302-wifi.conf /etc/modprobe.d/gz302-gpu.conf /etc/modprobe.d/gz302-input.conf; do
        if [[ -f "$f" ]]; then
            rm -f "$f"
            found_legacy=true
        fi
    done

    # Remove old udev rules
    for f in /etc/udev/rules.d/99-gz302-rgb.rules /etc/udev/rules.d/99-gz302-lightbar.rules; do
        if [[ -f "$f" ]]; then
            rm -f "$f"
            found_legacy=true
        fi
    done

    # Remove old binaries replaced by z13ctl wrappers
    for f in /usr/local/bin/gz302-rgb-restore /usr/local/bin/gz302-rgb-window /usr/local/bin/gz302-rgb-wrapper; do
        if [[ -f "$f" ]]; then
            rm -f "$f"
            found_legacy=true
        fi
    done

    if [[ "$found_legacy" == "true" ]]; then
        systemctl daemon-reload 2>/dev/null || true
        udevadm control --reload 2>/dev/null || true
        info "Cleaned up legacy v3/v4 installation artifacts"
    fi
}

# ==============================================================================
# Section 1: Hardware Fixes
# ==============================================================================

apply_hardware_fixes() {
    print_section "Section 1: Hardware Fixes"
    info "Applying Strix Halo hardware fixes..."

    local distro
    distro=$(detect_distribution)

    # Delegate modular hardware configuration to the library orchestrator.
    # Covers: WiFi, GPU (incl. Early KMS via gpu_configure_early_kms),
    #         Input, RGB, backlight restore, battery limit, amd_pstate.
    distro_apply_hardware_fixes

    # Audio: SOF firmware + CS35L41 ASoC configuration.
    info "Configuring audio..."
    if declare -f audio_apply_configuration >/dev/null 2>&1; then
        if audio_apply_configuration "$distro"; then
            success "Audio configured"
        else
            warning "Audio configuration had issues"
        fi
    fi

    # Display: PSR-SU OLED scrolling artifact fix.
    info "Checking OLED display PSR-SU configuration..."
    if declare -f display_psr_su_enabled >/dev/null 2>&1 && display_psr_su_enabled 2>/dev/null; then
        info "PSR-SU is enabled — applying fix for scrolling artifacts..."
        if display_apply_psr_su_fix; then
            success "PSR-SU fix applied"
        else
            warning "PSR-SU fix issues"
        fi
    else
        success "PSR-SU already disabled"
    fi

    # Suspend Fix
    install_suspend_fix

    # Show distribution-specific tuning tips.
    if declare -f distro_provide_optimization_info >/dev/null 2>&1; then
        distro_provide_optimization_info "$distro"
    fi

    success "Hardware fixes complete"
}

install_suspend_fix() {
    info "Installing suspend/resume fix..."
    local fix_script="${SCRIPT_DIR}/scripts/fix-suspend.sh"
    if [[ -f "$fix_script" ]]; then
        if bash "$fix_script"; then
            success "Suspend fix installed"
        else
            warning "Suspend fix issues"
        fi
    else
        info "Suspend fix script not found, downloading..."
        local tmp
        tmp=$(mktemp /tmp/gz302-fix-suspend.XXXXXX)
        if curl -fsSL "${GITHUB_RAW_URL}/scripts/fix-suspend.sh" -o "$tmp" 2>/dev/null; then
            if bash "$tmp"; then
                success "Suspend fix installed"
            else
                warning "Suspend fix issues"
            fi
            rm -f "$tmp"
        else
            warning "Could not download suspend fix"
        fi
    fi
}

# ==============================================================================
# Section 2: ASUS Control Backend + Strix Halo Command Center
# ==============================================================================

install_z13ctl() {
    local distro
    distro=$(detect_distribution)

    if [[ "${CAP_STRIX_HALO:-false}" != "true" ]]; then
        info "Confirmed Strix Halo signatures were not detected — skipping z13ctl install."
        return 0
    fi

    # Only install z13ctl on ASUS Strix Halo devices (uses ASUS HID interface)
    if [[ "${CAP_Z13CTL:-false}" != "true" ]]; then
        info "z13ctl is not applicable for ${DEVICE_VENDOR:-this} devices — skipping z13ctl install."
        info "See docs/technical/external-integrations-catalog.md for device-specific control tools."
        return 0
    fi

    info "Installing z13ctl for ASUS hardware control..."

    # Check if already installed
    if command -v z13ctl >/dev/null 2>&1; then
        local installed_ver
        installed_ver=$(z13ctl --version 2>/dev/null || echo "unknown")
        success "z13ctl already installed (${installed_ver})"
        info "Ensuring setup and daemon are configured..."
        z13ctl_setup_permissions
        z13ctl_enable_daemon
        z13ctl_generate_wrappers
        return 0
    fi

    # Install per distribution
    case "$distro" in
        arch)
            info "Installing z13ctl from AUR..."
            local real_user
            real_user=$(get_real_user)
            if command -v yay >/dev/null 2>&1; then
                sudo -u "$real_user" yay -S --noconfirm z13ctl-bin
            elif command -v paru >/dev/null 2>&1; then
                sudo -u "$real_user" paru -S --noconfirm z13ctl-bin
            else
                warning "No AUR helper found. Installing from release tarball..."
                z13ctl_install_from_release
            fi
            ;;
        debian|ubuntu)
            info "Installing z13ctl from .deb package..."
            local deb_url
            deb_url=$(z13ctl_get_release_url ".deb")
            if [[ -n "$deb_url" ]]; then
                local tmp_deb
                tmp_deb=$(mktemp /tmp/z13ctl-XXXXXX.deb)
                curl -fsSL "$deb_url" -o "$tmp_deb"
                apt install -y "$tmp_deb"
                rm -f "$tmp_deb"
            else
                z13ctl_install_from_release
            fi
            ;;
        fedora)
            info "Installing z13ctl from .rpm package..."
            local rpm_url
            rpm_url=$(z13ctl_get_release_url ".rpm")
            if [[ -n "$rpm_url" ]]; then
                dnf install -y "$rpm_url"
            else
                z13ctl_install_from_release
            fi
            ;;
        *)
            z13ctl_install_from_release
            ;;
    esac

    if ! command -v z13ctl >/dev/null 2>&1; then
        warning "z13ctl installation failed. RGB and power control will not be available."
        return 1
    fi

    success "z13ctl installed successfully"

    z13ctl_setup_permissions
    z13ctl_enable_daemon
    z13ctl_generate_wrappers

    success "z13ctl setup complete — RGB, power, TDP, fan curves ready"
}

z13ctl_get_release_url() {
    local suffix="$1"
    local api_url="https://api.github.com/repos/dahui/z13ctl/releases/latest"
    curl -fsSL "$api_url" 2>/dev/null \
        | grep -o "\"browser_download_url\": *\"[^\"]*${suffix}\"" \
        | head -1 \
        | sed 's/"browser_download_url": *"//' \
        | tr -d '"'
}

z13ctl_install_from_release() {
    info "Installing z13ctl from release tarball..."
    local tar_url
    tar_url=$(z13ctl_get_release_url "_linux_amd64.tar.gz")
    if [[ -z "$tar_url" ]]; then
        warning "Could not find z13ctl release URL"
        return 1
    fi
    local tmp_dir
    tmp_dir=$(mktemp -d /tmp/z13ctl-install.XXXXXX)
    curl -fsSL "$tar_url" -o "$tmp_dir/z13ctl.tar.gz"
    tar xzf "$tmp_dir/z13ctl.tar.gz" -C "$tmp_dir"
    install -Dm755 "$tmp_dir/z13ctl" /usr/local/bin/z13ctl
    rm -rf "$tmp_dir"
}

z13ctl_get_binary() {
    command -v z13ctl 2>/dev/null || true
}

z13ctl_ensure_group_membership() {
    local real_user
    real_user=$(get_real_user)

    if [[ -z "$real_user" || "$real_user" == "root" ]]; then
        warning "Could not determine a non-root user for z13ctl group membership"
        return 1
    fi

    if ! getent group users >/dev/null 2>&1; then
        if command -v groupadd >/dev/null 2>&1; then
            groupadd -f users
        else
            warning "System has no 'users' group and groupadd is unavailable"
            return 1
        fi
    fi

    if id -nG "$real_user" | tr ' ' '\n' | grep -qx users; then
        info "User '$real_user' already belongs to the 'users' group"
        return 0
    fi

    if usermod -aG users "$real_user" >/dev/null 2>&1; then
        success "Added '$real_user' to the 'users' group for direct z13ctl access"
        warning "Log out and back in (or run 'newgrp users') to use the new group in existing sessions"
        return 0
    fi

    warning "Could not add '$real_user' to the 'users' group"
    return 1
}

z13ctl_setup_permissions() {
    info "Running z13ctl setup (udev rules + permissions)..."
    z13ctl_ensure_group_membership || true
    z13ctl setup 2>/dev/null || warning "z13ctl setup reported issues"
}

z13ctl_enable_daemon() {
    info "Enabling z13ctl user daemon..."
    local real_user
    real_user=$(get_real_user)
    local real_home
    real_home=$(eval echo "~${real_user}")
    local z13ctl_bin
    z13ctl_bin=$(z13ctl_get_binary)
    [[ -n "$z13ctl_bin" ]] || z13ctl_bin="/usr/local/bin/z13ctl"

    # Install systemd user units if not present
    local user_systemd="${real_home}/.config/systemd/user"
    if [[ ! -f "${user_systemd}/z13ctl.socket" ]]; then
        mkdir -p "$user_systemd"

        # Try to find contrib files from package install
        local contrib_socket=""
        for path in /usr/share/z13ctl/systemd/user/z13ctl.socket \
                    /usr/lib/systemd/user/z13ctl.socket; do
            if [[ -f "$path" ]]; then
                contrib_socket="$(dirname "$path")"
                break
            fi
        done

        if [[ -n "$contrib_socket" ]]; then
            install -Dm644 "${contrib_socket}/z13ctl.socket" "${user_systemd}/z13ctl.socket"
            install -Dm644 "${contrib_socket}/z13ctl.service" "${user_systemd}/z13ctl.service"
        else
            # Create minimal units
            cat > "${user_systemd}/z13ctl.socket" << 'EOF'
[Unit]
Description=z13ctl socket

[Socket]
ListenStream=%t/z13ctl/z13ctl.sock
SocketMode=0660

[Install]
WantedBy=sockets.target
EOF
            cat > "${user_systemd}/z13ctl.service" <<EOF
[Unit]
Description=z13ctl daemon
Requires=z13ctl.socket
After=z13ctl.socket

[Service]
Type=notify
ExecStart=${z13ctl_bin} daemon
Restart=on-failure
RestartSec=5
ProtectHome=yes
NoNewPrivileges=yes
PrivateTmp=yes

[Install]
WantedBy=default.target
EOF
        fi
        chown -R "${real_user}:" "$user_systemd"
    fi

    # Enable and start as the real user
    sudo -u "$real_user" systemctl --user daemon-reload 2>/dev/null || true
    if sudo -u "$real_user" systemctl --user enable --now z13ctl.socket z13ctl.service 2>/dev/null; then
        success "z13ctl daemon enabled"
    else
        warning "z13ctl daemon setup may need manual enable after login"
    fi
}

z13ctl_generate_wrappers() {
    info "Generating backward-compatible CLI wrappers..."

    # pwrcfg — maps legacy profile names to z13ctl
    cat > /usr/local/bin/pwrcfg << 'PWRCFG'
#!/bin/bash
# pwrcfg — Power profile wrapper for z13ctl
# Generated by GZ302 Linux Setup

case "${1:-status}" in
    silent|quiet)     z13ctl profile --set quiet ;;
    balanced)         z13ctl profile --set balanced ;;
    performance)      z13ctl profile --set performance ;;
    gaming|turbo|max) z13ctl profile --set performance ;;
    custom)           z13ctl profile --set custom ;;
    status)           z13ctl status ;;
    auto)
        if [[ -d /sys/class/power_supply/AC0 ]] && \
           [[ "$(cat /sys/class/power_supply/AC0/online 2>/dev/null)" == "1" ]]; then
            z13ctl profile --set balanced
        else
            z13ctl profile --set quiet
        fi
        ;;
    tdp)
        shift
        z13ctl tdp "$@"
        ;;
    fan|fancurve)
        shift
        z13ctl fancurve "$@"
        ;;
    battery)
        shift
        z13ctl batterylimit "$@"
        ;;
    *)
        echo "Usage: pwrcfg [silent|balanced|performance|gaming|turbo|max|custom|status|auto|tdp|fan|battery]"
        echo ""
        echo "Advanced (via z13ctl):"
        echo "  pwrcfg tdp --set 50        Set TDP to 50W"
        echo "  pwrcfg fan --get           Show current fan curve"
        echo "  pwrcfg battery --set 80    Set battery charge limit"
        echo ""
        echo "Powered by z13ctl: https://github.com/dahui/z13ctl"
        ;;
esac
PWRCFG
    chmod 755 /usr/local/bin/pwrcfg

    # gz302-rgb — maps to z13ctl apply
    cat > /usr/local/bin/gz302-rgb << 'RGBWRAP'
#!/bin/bash
# gz302-rgb — RGB control wrapper for z13ctl
# Generated by GZ302 Linux Setup

case "${1:-help}" in
    static)
        z13ctl apply --mode static --color "${2:-white}" --brightness "${3:-high}"
        ;;
    breathe|breathing)
        z13ctl apply --mode breathe --color "${2:-cyan}" --color2 "${3:-blue}" --speed "${4:-normal}"
        ;;
    cycle)
        z13ctl apply --mode cycle --speed "${2:-normal}"
        ;;
    rainbow)
        z13ctl apply --mode rainbow --speed "${2:-normal}"
        ;;
    strobe)
        z13ctl apply --mode strobe --color "${2:-white}" --speed "${3:-normal}"
        ;;
    off)
        z13ctl off
        ;;
    brightness)
        z13ctl brightness "${2:-high}"
        ;;
    status)
        z13ctl status
        ;;
    list|colors)
        z13ctl apply --list-colors
        ;;
    *)
        echo "Usage: gz302-rgb <mode> [color] [options]"
        echo ""
        echo "Modes:"
        echo "  static <color>              Solid color (e.g., static red)"
        echo "  breathe <color1> <color2>   Pulsing between two colors"
        echo "  cycle [speed]               Cycle through spectrum"
        echo "  rainbow [speed]             Rainbow wave"
        echo "  strobe <color> [speed]      Rapid flash"
        echo "  off                         Turn off all lighting"
        echo "  brightness <level>          off|low|medium|high"
        echo "  status                      Show current status"
        echo "  colors                      List named colors"
        echo ""
        echo "Speed: slow|normal|fast"
        echo "Colors: red, blue, cyan, green, purple, hotpink, white, etc."
        echo "        Or any 6-digit hex value (e.g., FF00FF)"
        echo ""
        echo "Powered by z13ctl: https://github.com/dahui/z13ctl"
        ;;
esac
RGBWRAP
    chmod 755 /usr/local/bin/gz302-rgb

    # Sudoers for wrappers and the resolved z13ctl binary
    local real_user
    real_user=$(get_real_user)
    local z13ctl_bin
    z13ctl_bin=$(z13ctl_get_binary)
    [[ -n "$z13ctl_bin" ]] || z13ctl_bin="/usr/local/bin/z13ctl"
    # Clean up old sudoers fragments from v3/v4
    rm -f /etc/sudoers.d/strix-halo-pwrcfg /etc/sudoers.d/strix-halo-rgb 2>/dev/null || true

    # Write sudoers atomically with validation
    local sudoers_file="/etc/sudoers.d/strix-halo"
    local sudoers_tmp
    sudoers_tmp=$(mktemp /tmp/gz302-sudoers.XXXXXX)
    cat > "$sudoers_tmp" << EOF
# GZ302 Linux Setup — passwordless access for hardware control
${real_user} ALL=(ALL) NOPASSWD: /usr/local/bin/pwrcfg
${real_user} ALL=(ALL) NOPASSWD: /usr/local/bin/gz302-rgb
${real_user} ALL=(ALL) NOPASSWD: ${z13ctl_bin}
EOF
    if visudo -c -f "$sudoers_tmp" >/dev/null 2>&1; then
        mv "$sudoers_tmp" "$sudoers_file"
        chmod 440 "$sudoers_file"
    else
        rm -f "$sudoers_tmp"
        warning "Sudoers validation failed — skipping"
    fi

    success "CLI wrappers installed: pwrcfg, gz302-rgb"
}

# ==============================================================================
# Section 3: Display Tools & System Tray
# ==============================================================================

install_display_tools() {
    if [[ "${CAP_DASHBOARD:-false}" != "true" ]]; then
        info "The Strix Halo dashboard is not offered for ${DEVICE_MODEL:-this profile}."
        return 0
    fi

    print_section "Section 2: Strix Halo Dashboard"

    local distro
    distro=$(detect_distribution)

    # Refresh rate control (rrcfg)
    info "Installing refresh rate control (rrcfg)..."
    if declare -f display_get_rrcfg_script >/dev/null 2>&1; then
        local lib_dest="/usr/local/share/gz302/strix-halo-lib"
        mkdir -p "$lib_dest"
        install -Dm644 "${SCRIPT_DIR}/strix-halo-lib/display-manager.sh" "${lib_dest}/display-manager.sh"
        display_get_rrcfg_script > /usr/local/bin/rrcfg
        chmod 755 /usr/local/bin/rrcfg
        success "rrcfg installed"
    else
        warning "display-manager library not loaded — skipping rrcfg"
    fi

    # System tray application
    install_tray_app "$distro"

    success "Display tools installed"
}

install_tray_app() {
    local distro="$1"
    info "Installing Strix Halo Dashboard..."

    local tray_dir="${SCRIPT_DIR}/command-center"
    if [[ ! -d "$tray_dir" ]]; then
        info "Downloading tray app..."
        mkdir -p "$tray_dir"
        for f in install-tray.sh requirements.txt VERSION; do
            curl -fsSL "${GITHUB_RAW_URL}/command-center/${f}" -o "${tray_dir}/${f}" 2>/dev/null || true
        done
        mkdir -p "${tray_dir}/src/modules"
        for f in command_center.py modules/__init__.py modules/config.py modules/notifications.py \
                 modules/power_controller.py modules/rgb_controller.py; do
            curl -fsSL "${GITHUB_RAW_URL}/command-center/src/${f}" -o "${tray_dir}/src/${f}" 2>/dev/null || true
        done
    fi

    # Install Python dependencies (including SVG support for tray icons)
    case "$distro" in
        arch)
            pacman -S --noconfirm --needed python-pyqt6 python-psutil python-dbus 2>/dev/null || true
            ;;
        debian|ubuntu)
            apt install -y python3-pyqt6 python3-pyqt6.qtsvg python3-psutil python3-dbus 2>/dev/null || true
            ;;
        fedora)
            dnf install -y python3-pyqt6 python3-qt6-qtsvg python3-psutil python3-dbus 2>/dev/null || true
            ;;
        opensuse)
            zypper install -y python3-pyqt6 python3-qt6-svg python3-psutil python3-dbus-python 2>/dev/null || true
            ;;
    esac

    install -d -m 755 /etc/strix-halo
    cat > /etc/strix-halo/tray.conf << EOF
APP_NAME="Strix Halo Dashboard"
DEVICE_LABEL="${DEVICE_MODEL:-Strix Halo}"
HAS_DASHBOARD="${CAP_DASHBOARD:-false}"
HAS_Z13CTL="${CAP_Z13CTL:-false}"
HAS_COMMAND_CENTER="${CAP_COMMAND_CENTER:-false}"
EOF
    chmod 644 /etc/strix-halo/tray.conf

    # Run the tray installer
    if [[ -f "${tray_dir}/install-tray.sh" ]]; then
        bash "${tray_dir}/install-tray.sh"
    fi

    # Sync tray source files to /opt/strix-halo-control-center if that install exists
    # (handles the system-level launcher at /usr/local/bin/strix-halo-control-center)
    local opt_dir="/opt/strix-halo-control-center"
    if [[ -d "$opt_dir" ]]; then
        info "Updating system-level tray install at $opt_dir ..."
        cp -a "${tray_dir}/src/"* "$opt_dir/src/"
        cp -a "${tray_dir}/assets/"* "$opt_dir/assets/" 2>/dev/null || true
        cp "${tray_dir}/VERSION" "$opt_dir/VERSION" 2>/dev/null || true
    fi

    success "Dashboard installed"
}

# ==============================================================================
# Section 3: Gaming Module
# ==============================================================================

install_gaming_module() {
    print_section "Section 3: Gaming (Steam, Lutris, MangoHUD, GameMode)"

    local distro
    distro=$(detect_distribution)

    info "Gaming packages: Steam, Lutris, MangoHUD, GameMode, Wine, Proton-GE"
    echo

    download_and_execute_module "gz302-gaming" "$distro"
}

# ==============================================================================
# Section 4: AI / LLM Module
# ==============================================================================

install_ai_module() {
    print_section "Section 4: AI / LLM (Ollama, ROCm, vLLM, ComfyUI)"

    local distro
    distro=$(detect_distribution)

    info "AI packages: Ollama, LM Studio, ROCm, PyTorch, vLLM, ComfyUI"
    echo
    if [[ "${CAP_ROCM:-false}" == "true" ]]; then
        success "Radeon 8060S (gfx1151) detected — ROCm GPU compute is available"
    else
        warning "AMD GPU not confirmed — ROCm packages will be installed but may not be functional"
    fi
    echo

    download_and_execute_module "gz302-llm" "$distro"
}

# ==============================================================================
# Section 5: Other Tools (Hypervisor + Community Integrations)
# ==============================================================================

install_other_tools() {
    print_section "Section 5: Other Tools"

    local distro
    distro=$(detect_distribution)

    if prompt_section "Install Hypervisor? (KVM/QEMU, libvirt, virt-manager)" N; then
        download_and_execute_module "gz302-hypervisor" "$distro"
    fi

    echo
    install_community_integrations "$distro"
}

# Present the curated Strix Halo community integrations catalog and let the
# user choose which (if any) to install.
install_community_integrations() {
    local distro="${1:-unknown}"

    if [[ "${CAP_STRIX_HALO:-false}" != "true" ]]; then
        info "Skipping Strix Halo community integrations — confirmed Strix Halo hardware was not detected."
        return 0
    fi

    print_section "Community Integrations (Strix Halo Ecosystem)"
    info "The following third-party projects have been verified to work on"
    info "Strix Halo hardware. All are opt-in. Nothing is installed by default."
    echo
    info "Full catalog: docs/technical/external-integrations-catalog.md"
    echo

    # --- Strix-Halo-Control (GTK4 GUI for ASUS devices) ---------------------
    if [[ "${CAP_Z13CTL:-false}" == "true" ]]; then
        echo "  ${SYMBOL_BULLET:-•} Strix-Halo-Control — GTK4 GUI for z13ctl (RGB, fans, power)"
        echo "    URL: https://github.com/TechnoDaimon/Strix-Halo-Control"
        echo "    Trust: community-verified | Devices: ASUS ROG"
        if prompt_section "  Install Strix-Halo-Control?" N; then
            _install_strix_halo_control "$distro"
        fi
        echo
    fi

    # --- amd-strix-halo-toolboxes (AI containers) ---------------------------
    echo "  ${SYMBOL_BULLET:-•} amd-strix-halo-toolboxes — container AI workflows (Ollama, vLLM, ComfyUI)"
    echo "    URL: https://github.com/kyuz0/amd-strix-halo-toolboxes"
    echo "    Trust: community-verified | Devices: all Strix Halo"
    if prompt_section "  Install amd-strix-halo-toolboxes?" N; then
        _install_strix_halo_toolboxes "$distro"
    fi
    echo

    success "Community integrations processing complete"
}

_install_strix_halo_control() {
    local distro="$1"
    info "Installing Strix-Halo-Control dependencies..."

    case "$distro" in
        arch)
            pacman -S --noconfirm --needed gtk4 python python-gobject 2>/dev/null || true
            ;;
        debian|ubuntu)
            apt install -y python3-gi python3-gi-cairo gir1.2-gtk-4.0 2>/dev/null || true
            ;;
        fedora)
            dnf install -y gtk4 python3-gobject 2>/dev/null || true
            ;;
        opensuse)
            zypper install -y gtk4 python3-gobject 2>/dev/null || true
            ;;
    esac

    info "Cloning Strix-Halo-Control..."
    local install_dir="/opt/strix-halo-control"
    if [[ -d "$install_dir" ]]; then
        info "Updating existing install at ${install_dir}..."
        git -C "$install_dir" pull --ff-only 2>/dev/null || true
    else
        git clone --depth 1 https://github.com/TechnoDaimon/Strix-Halo-Control.git "$install_dir" 2>/dev/null || {
            warning "Could not clone Strix-Halo-Control — check network connectivity"
            return 1
        }
    fi

    # Create a launcher wrapper
    cat > /usr/local/bin/strix-halo-control << 'EOF'
#!/bin/bash
# Strix-Halo-Control launcher — installed by Strix Halo Linux Setup
exec python3 /opt/strix-halo-control/main.py "$@"
EOF
    chmod 755 /usr/local/bin/strix-halo-control
    success "Strix-Halo-Control installed → run: strix-halo-control"
}

_install_strix_halo_toolboxes() {
    local distro="$1"
    info "Installing Distrobox / Toolbx for container-based AI workflows..."

    case "$distro" in
        arch)
            pacman -S --noconfirm --needed distrobox 2>/dev/null || true
            ;;
        debian|ubuntu)
            apt install -y distrobox 2>/dev/null || \
                curl -s https://raw.githubusercontent.com/89luca89/distrobox/main/install | sh -s -- --prefix /usr/local 2>/dev/null || true
            ;;
        fedora)
            dnf install -y distrobox 2>/dev/null || true
            ;;
        opensuse)
            zypper install -y distrobox 2>/dev/null || true
            ;;
    esac

    if ! command -v distrobox >/dev/null 2>&1; then
        warning "distrobox not found after install — AI toolboxes require distrobox or toolbox"
        info "See: https://github.com/kyuz0/amd-strix-halo-toolboxes for manual setup"
        return 1
    fi

    info "Pulling the latest Strix Halo ROCm toolbox image..."
    info "This downloads a container image (~3-5 GB) — it may take a while."
    distrobox create --name strix-halo-ai \
        --image kyuz0/amd-strix-halo-toolboxes:rocm-7.2.3 \
        --yes 2>/dev/null || {
        warning "Could not create Strix Halo AI toolbox — see https://strix-halo-toolboxes.com for troubleshooting"
        return 1
    }

    info "Toolbox created. Enter it with: distrobox enter strix-halo-ai"
    success "amd-strix-halo-toolboxes installed"
}

download_and_execute_module() {
    local module_name="$1"
    local distro="$2"
    local local_module="${SCRIPT_DIR}/modules/${module_name}.sh"

    # Check for local module first
    if [[ -f "$local_module" ]]; then
        info "Running local module ${module_name}..."
        bash "$local_module" "$distro"
        return $?
    fi

    local tmp
    tmp=$(mktemp /tmp/gz302-module-XXXXXX.sh)
    info "Downloading ${module_name}..."
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "${GITHUB_RAW_URL}/modules/${module_name}.sh" -o "$tmp" 2>/dev/null
    elif command -v wget >/dev/null 2>&1; then
        wget -q "${GITHUB_RAW_URL}/modules/${module_name}.sh" -O "$tmp" 2>/dev/null
    fi

    if [[ -s "$tmp" ]]; then
        chmod +x "$tmp"
        bash "$tmp" "$distro"
        local rc=$?
        rm -f "$tmp"
        return $rc
    fi

    warning "Failed to download or execute ${module_name}"
    rm -f "$tmp"
    return 1
}

# ==============================================================================
# Distribution Setup (system update + base packages)
# ==============================================================================

setup_distro_base() {
    local distro="$1"
    info "Updating system and installing base packages..."

    case "$distro" in
        arch)
            pacman -Syu --noconfirm --needed
            pacman -S --noconfirm --needed git base-devel wget curl
            # Install AUR helper if missing
            if ! command -v yay >/dev/null 2>&1 && ! command -v paru >/dev/null 2>&1; then
                info "Installing yay AUR helper..."
                local real_user
                real_user=$(get_real_user)
                sudo -u "$real_user" -H bash -c '
                    cd /tmp && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm
                '
            fi
            ;;
        debian|ubuntu)
            apt update && apt upgrade -y
            apt install -y curl wget git build-essential ca-certificates gnupg
            ;;
        fedora)
            dnf upgrade -y
            dnf install -y curl wget git gcc make kernel-devel
            ;;
        opensuse)
            zypper refresh && zypper update -y
            zypper install -y curl wget git gcc make kernel-devel
            ;;
    esac
    success "System updated"
}

# ==============================================================================
# Main
# ==============================================================================

main() {
    check_root
    print_banner
    print_section "Strix Halo Linux Setup v$(cat "${SCRIPT_DIR}/VERSION" 2>/dev/null || echo "${SETUP_VERSION}")"
    echo

    # --- Step 1: Hardware & system detection ---------------------------------
    print_step 1 4 "Detecting hardware..."
    # Run device detection (populates DEVICE_* and CAP_* globals)
    if declare -f device_detect >/dev/null 2>&1; then
        device_detect
        device_print_profile
        if ! device_is_strix_halo; then
            warning "Confirmed Strix Halo CPU/GPU signatures were not detected."
            warning "Hardware fixes, ASUS control paths, and Strix Halo AI flows will be skipped."
            info "Gaming and hypervisor modules remain available if you want the generic software installs only."
            SKIP_FIXES=true
            SKIP_Z13CTL=true
            SKIP_TOOLS=true
            SKIP_AI=true
        fi
    else
        warning "device-manager library not loaded — skipping hardware profile detection"
    fi

    print_step 2 4 "Validating kernel..."
    check_kernel_version >/dev/null

    print_step 3 4 "Checking network..."
    check_network || warning "Network connectivity limited — some downloads may fail"

    print_step 4 4 "Detecting distribution..."
    local distro
    distro=$(detect_distribution)
    success "Detected: ${distro}"
    echo

    print_keyval "Distribution" "$distro"
    print_keyval "Kernel"       "$(uname -r)"
    print_keyval "z13ctl"       "$(command -v z13ctl >/dev/null 2>&1 && z13ctl --version 2>/dev/null || echo 'not installed')"
    echo

    # Pre-flight: clean legacy v3/v4 artifacts
    cleanup_legacy_install

    # Update system
    if prompt_section "Update system and install base packages? (Y/n): " Y; then
        setup_distro_base "$distro"
    fi

    # --- Step 2: Hardware fixes (kernel-level) --------------------------------
    if [[ "$SKIP_FIXES" != "true" ]]; then
        echo
        if prompt_section "Apply hardware fixes? (WiFi, GPU, Input, Audio, Display, Suspend) (Y/n): " Y; then
            apply_hardware_fixes
        else
            info "Skipping hardware fixes"
        fi
    fi

    # --- Step 3: Dashboard / device control paths ----------------------------
    if [[ "$SKIP_Z13CTL" != "true" ]] || [[ "$SKIP_TOOLS" != "true" ]]; then
        echo
        local cc_prompt=""
        if [[ "${CAP_COMMAND_CENTER:-false}" == "true" ]] && [[ "$SKIP_Z13CTL" != "true" ]] && [[ "$SKIP_TOOLS" != "true" ]]; then
            cc_prompt="Install Command Center? (z13ctl hardware control + tray app)"
        elif [[ "${CAP_DASHBOARD:-false}" == "true" ]] && [[ "${CAP_Z13CTL:-false}" == "true" ]] && [[ "$SKIP_Z13CTL" != "true" ]] && [[ "$SKIP_TOOLS" != "true" ]]; then
            cc_prompt="Install Strix Halo Dashboard? (generic dashboard + ASUS control backend)"
        elif [[ "${CAP_DASHBOARD:-false}" == "true" ]] && [[ "$SKIP_TOOLS" != "true" ]]; then
            cc_prompt="Install Strix Halo Dashboard tray app?"
        elif [[ "${CAP_Z13CTL:-false}" == "true" ]] && [[ "$SKIP_Z13CTL" != "true" ]]; then
            cc_prompt="Install ASUS control backend? (z13ctl CLI + daemon)"
            info "The generic dashboard is not offered on this device profile."
        fi

        if [[ -n "$cc_prompt" ]] && prompt_section "$cc_prompt (Y/n): " Y; then
            if [[ "$SKIP_Z13CTL" != "true" ]]; then
                install_z13ctl
            fi
            if [[ "$SKIP_TOOLS" != "true" ]]; then
                install_display_tools
            fi
        elif [[ -n "$cc_prompt" ]]; then
            info "Skipping dashboard / device control path"
        elif [[ "${CAP_STRIX_HALO:-false}" == "true" ]]; then
            info "No dashboard or vendor control path is available for ${DEVICE_MODEL:-this device} — skipping."
        fi
    fi

    # --- Step 4: Gaming -------------------------------------------------------
    if [[ "$SKIP_MODULES" != "true" ]]; then
        echo
        if prompt_section "Install Gaming packages? (Steam, Lutris, MangoHUD, GameMode) (y/N): " N; then
            install_gaming_module
        else
            info "Skipping Gaming"
        fi

        # --- Step 5: AI / LLM -------------------------------------------------
        echo
        if [[ "$SKIP_AI" != "true" ]]; then
            if prompt_section "Install AI / LLM packages? (Ollama, ROCm, vLLM, ComfyUI) (y/N): " N; then
                install_ai_module
            else
                info "Skipping AI / LLM"
            fi
        else
            info "Skipping AI / LLM — confirmed Strix Halo hardware not detected"
        fi

        # --- Step 6: Other tools ----------------------------------------------
        echo
        if prompt_section "Browse other tools? (Hypervisor, community integrations) (y/N): " N; then
            install_other_tools
        else
            info "Skipping other tools"
        fi
    fi

    # --- Done -----------------------------------------------------------------
    echo
    print_section "Setup Complete"
    echo
    completed_item "Device: ${DEVICE_MODEL:-unknown} (${DEVICE_SUPPORT_TIER:-unknown} support)"
    completed_item "Kernel $(uname -r)"
    completed_item "Distribution: ${distro}"
    [[ "$SKIP_FIXES" != "true" ]] && completed_item "Hardware fixes applied"
    command -v z13ctl >/dev/null 2>&1 && completed_item "z13ctl — RGB, power, TDP, fan curves"
    command -v pwrcfg  >/dev/null 2>&1 && completed_item "pwrcfg — power profile switching"
    command -v gz302-rgb >/dev/null 2>&1 && completed_item "gz302-rgb — RGB lighting control"
    [[ -f /usr/local/bin/rrcfg ]] && completed_item "rrcfg — refresh rate control"
    echo

    print_box "🚀 SETUP COMPLETE! 🚀" "$C_BOLD_GREEN"
    warning "A REBOOT is recommended to apply all changes"
    echo
    if [[ "${CAP_Z13CTL:-false}" == "true" ]]; then
        info "Quick start (ASUS z13ctl):"
        info "  z13ctl apply --color cyan --brightness high"
        info "  z13ctl profile --set balanced"
        info "  z13ctl status"
    elif [[ "${CAP_STRIX_HALO:-false}" == "true" ]]; then
        info "Quick start:"
        info "  cat docs/technical/external-integrations-catalog.md"
    else
        info "Quick start:"
        info "  ./strix-halo-setup.sh --help"
    fi
    echo
}

main "$@"
