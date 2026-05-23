#!/bin/bash
# shellcheck disable=SC2034,SC2059
set -euo pipefail

# ==============================================================================
# GZ302 Audio Manager Library
# Version: 6.8.0
#
# This library manages audio configuration for the GZ302, including:
# - Sound Open Firmware (SOF) installation
# - Cirrus Logic CS35L41 smart amplifier detection and configuration
# - ALSA state management
# - Audio quirks and workarounds
#
# Key Components:
# - Realtek ALC294 codec
# - Dual Cirrus Logic CS35L41 amplifiers (I2C connected)
# - SOF DSP firmware
#
# Usage:
#   source strix-halo-lib/audio-manager.sh
#   audio_detect_hardware
#   audio_install_sof_firmware "arch"
#   audio_apply_configuration
# ==============================================================================

# --- Audio Hardware Detection ---

# Detect audio controller
# Returns: 0 if found, 1 if not found
# Output: Audio controller information
audio_detect_controller() {
    if lspci | grep -qi "audio.*amd\|audio.*advanced micro"; then
        local audio_info
        audio_info=$(lspci | grep -i "audio.*amd\|audio.*advanced micro")
        echo "$audio_info"
        return 0
    else
        return 1
    fi
}

# Detect Cirrus Logic CS35L41 amplifiers
# Returns: 0 if detected, 1 if not detected
audio_detect_cs35l41() {
    # Check /proc/asound/cards for CS35L41
    if [[ -r /proc/asound/cards ]] && grep -qi "cs35l41" /proc/asound/cards 2>/dev/null; then
        return 0
    fi
    
    # Check dmesg for CS35L41 driver messages
    if dmesg | grep -qi "cs35l41"; then
        return 0
    fi
    
    return 1
}

# Get audio subsystem ID
# Returns: Subsystem ID or "unknown"
audio_get_subsystem_id() {
    # GZ302 should have subsystem ID 1043:1fb3
    local subsystem_id
    subsystem_id=$(lspci -vnn | grep -i audio -A 10 | grep -i "subsystem" | grep -oP '[\da-f]{4}:[\da-f]{4}' | head -1)
    
    if [[ -n "$subsystem_id" ]]; then
        echo "$subsystem_id"
    else
        echo "unknown"
    fi
}

# Check if snd_hda_intel module is loaded
# Returns: 0 if loaded, 1 if not
audio_module_loaded() {
    lsmod | grep -q "^snd_hda_intel"
}

# Check if SOF is being used
# Returns: 0 if SOF active, 1 if not
audio_sof_active() {
    if lsmod | grep -q "^snd_sof"; then
        return 0
    fi
    
    if [[ -d /lib/firmware/intel/sof ]] || [[ -d /lib/firmware/amd/sof ]]; then
        # Firmware present, likely in use
        return 0
    fi
    
    return 1
}

# Get list of audio cards
# Output: Audio card list
audio_list_cards() {
    if [[ -f /proc/asound/cards ]]; then
        cat /proc/asound/cards
    else
        echo "No audio cards found"
    fi
}

# --- SOF Firmware Detection ---

# Check if SOF firmware is installed
# Returns: 0 if installed, 1 if not
audio_sof_firmware_installed() {
    # Check for SOF firmware in common locations
    if [[ -d /lib/firmware/intel/sof ]] || \
       [[ -d /lib/firmware/amd/sof ]] || \
       [[ -d /usr/lib/firmware/intel/sof ]] || \
       [[ -d /usr/lib/firmware/amd/sof ]]; then
        return 0
    fi
    
    return 1
}

# Check if ALSA UCM configuration is installed
# Returns: 0 if installed, 1 if not
audio_ucm_installed() {
    if [[ -d /usr/share/alsa/ucm ]] || [[ -d /usr/share/alsa/ucm2 ]]; then
        return 0
    fi
    return 1
}

# --- Configuration State Detection ---

# Check if CS35L41 configuration is applied
# Returns: 0 if applied, 1 if not
audio_cs35l41_config_applied() {
    if [[ -f /etc/modprobe.d/cs35l41.conf ]]; then
        if grep -q "softdep snd_hda_intel" /etc/modprobe.d/cs35l41.conf 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Check if ALSA state service is enabled
# Returns: 0 if enabled, 1 if not
audio_alsa_state_enabled() {
    systemctl is-enabled alsa-restore.service >/dev/null 2>&1 || \
    systemctl is-enabled alsa-state.service >/dev/null 2>&1
}

# Get comprehensive audio state
# Output: JSON-like state information
audio_get_state() {
    local controller_detected="false"
    local cs35l41_detected="false"
    local subsystem_id="unknown"
    local module_loaded="false"
    local sof_active="false"
    local sof_firmware_installed="false"
    local ucm_installed="false"
    local cs35l41_config="false"
    local alsa_state_enabled="false"
    
    if audio_detect_controller >/dev/null 2>&1; then
        controller_detected="true"
    fi
    
    if audio_detect_cs35l41; then
        cs35l41_detected="true"
    fi
    
    subsystem_id=$(audio_get_subsystem_id)
    
    if audio_module_loaded; then
        module_loaded="true"
    fi
    
    if audio_sof_active; then
        sof_active="true"
    fi
    
    if audio_sof_firmware_installed; then
        sof_firmware_installed="true"
    fi
    
    if audio_ucm_installed; then
        ucm_installed="true"
    fi
    
    if audio_cs35l41_config_applied; then
        cs35l41_config="true"
    fi
    
    if audio_alsa_state_enabled; then
        alsa_state_enabled="true"
    fi
    
    cat <<EOF
{
    "controller_detected": "$controller_detected",
    "cs35l41_detected": "$cs35l41_detected",
    "subsystem_id": "$subsystem_id",
    "module_loaded": "$module_loaded",
    "sof_active": "$sof_active",
    "sof_firmware_installed": "$sof_firmware_installed",
    "ucm_installed": "$ucm_installed",
    "cs35l41_config_applied": "$cs35l41_config",
    "alsa_state_enabled": "$alsa_state_enabled"
}
EOF
}

# --- SOF Firmware Installation (Distribution-Specific) ---

# Install SOF firmware for given distribution
# Args: $1 = distribution (arch, ubuntu, fedora, opensuse)
# Returns: 0 on success, 1 on failure
# Output: Status messages
audio_install_sof_firmware() {
    local distro="$1"
    
    if [[ -z "$distro" ]]; then
        echo "ERROR: Distribution parameter required"
        return 1
    fi
    
    # Check if already installed
    if audio_sof_firmware_installed && audio_ucm_installed; then
        echo "SOF firmware and UCM already installed"
        return 0
    fi
    
    echo "Installing Sound Open Firmware (SOF) for GZ302EA audio..."
    
    case "$distro" in
        arch)
            # Install SOF firmware from official Arch repos
            if pacman -S --noconfirm --needed sof-firmware alsa-ucm-conf 2>/dev/null; then
                echo "SOF firmware installed from official repositories"
                return 0
            else
                echo "WARNING: SOF firmware installation failed - audio may not work optimally"
                return 1
            fi
            ;;
        debian|ubuntu)
            # Install SOF firmware from Ubuntu repos
            if apt-get install -y sof-firmware alsa-ucm-conf 2>/dev/null; then
                echo "SOF firmware installed"
                return 0
            else
                echo "WARNING: SOF firmware installation failed - audio may not work optimally"
                return 1
            fi
            ;;
        fedora)
            # Install SOF firmware from Fedora repos
            if dnf install -y sof-firmware alsa-sof-firmware alsa-ucm 2>/dev/null; then
                echo "SOF firmware installed"
                return 0
            else
                echo "WARNING: SOF firmware installation failed - audio may not work optimally"
                return 1
            fi
            ;;
        opensuse)
            # Install SOF firmware from OpenSUSE repos
            if zypper install -y sof-firmware alsa-ucm-conf 2>/dev/null; then
                echo "SOF firmware installed"
                return 0
            else
                echo "WARNING: SOF firmware installation failed - audio may not work optimally"
                return 1
            fi
            ;;
        *)
            echo "ERROR: Unsupported distribution: $distro"
            return 1
            ;;
    esac
}

# --- Configuration Application (Idempotent) ---

# Apply CS35L41 configuration (idempotent)
# Returns: 0 if applied or already applied
audio_apply_cs35l41_config() {
    # Check if CS35L41 is detected
    if ! audio_detect_cs35l41; then
        # Not detected, don't apply config
        return 0
    fi
    
    # Check if already configured
    if audio_cs35l41_config_applied; then
        return 0  # Already configured
    fi
    
    # Apply configuration
    cat > /etc/modprobe.d/cs35l41.conf <<'EOF'
# Cirrus Logic CS35L41 amplifiers - ASUS ROG Flow Z13 GZ302
# Subsystem ID: 1043:1fb3
# The cs35l41_hda ASoC bridge driver manages these amps via ACPI/I2C.
# Load cs35l41_hda after snd_hda_intel so the HDA bus is ready.
softdep snd_hda_intel post: cs35l41_hda
EOF
    
    return 0
}

# Enable ALSA state services (idempotent)
# Returns: 0 if enabled or already enabled
audio_enable_alsa_state() {
    if audio_alsa_state_enabled; then
        return 0  # Already enabled
    fi
    
    # Enable state save/restore services
    systemctl enable --now alsa-restore.service 2>/dev/null || true
    systemctl enable --now alsa-state.service 2>/dev/null || true
    
    return 0
}

# Apply audio configuration (idempotent)
# Args: $1 = distribution (for SOF firmware installation)
# Returns: 0 on success
# Output: Status messages
audio_apply_configuration() {
    local distro="${1:-}"
    
    echo "Configuring audio for GZ302..."
    
    # Install SOF firmware if distribution provided
    if [[ -n "$distro" ]]; then
        if ! audio_install_sof_firmware "$distro"; then
            echo "WARNING: SOF firmware installation had issues"
        fi
    fi
    
    # Check kernel version for CS35L41 native support
    local kver=0
    if declare -f kernel_get_version_num >/dev/null; then
        kver=$(kernel_get_version_num)
    fi

    if [[ $kver -ge 619 ]]; then
        echo "Kernel 6.19+ detected: Using native CS35L41 support"
        if [[ -f /etc/modprobe.d/cs35l41.conf ]]; then
            rm -f /etc/modprobe.d/cs35l41.conf
            echo "Removed obsolete CS35L41 quirk configuration"
        fi
    elif audio_detect_cs35l41; then
        echo "Cirrus Logic CS35L41 amplifier detected"
        if ! audio_apply_cs35l41_config; then
            echo "ERROR: Failed to apply CS35L41 configuration"
            return 1
        fi
        echo "CS35L41 configuration applied"
    else
        echo "CS35L41 amplifier not detected (may appear after reboot)"
    fi
    
    # Enable ALSA state services
    if ! audio_enable_alsa_state; then
        echo "WARNING: Failed to enable ALSA state services"
    fi
    
    echo "Audio configuration complete"
    return 0
}

# --- Verification Functions ---

# Verify audio is working
# Returns: 0 if working, 1 if issues detected
# Output: Status information
audio_verify_working() {
    local status=0
    
    # Check if audio controller detected
    if ! audio_detect_controller >/dev/null 2>&1; then
        echo "ERROR: Audio controller not detected"
        return 1
    fi
    
    # Check if audio module loaded
    if ! audio_module_loaded; then
        echo "WARNING: snd_hda_intel module not loaded"
        status=1
    fi
    
    # Check for audio cards
    if [[ ! -f /proc/asound/cards ]] || ! grep -q "[0-9]" /proc/asound/cards; then
        echo "WARNING: No audio cards detected"
        status=1
    fi
    
    # Check for kernel errors
    if dmesg | tail -200 | grep -qi "snd.*error\|audio.*fail\|cs35l41.*error"; then
        echo "WARNING: Recent audio errors in kernel log"
        status=1
    fi
    
    if [[ $status -eq 0 ]]; then
        echo "Audio verification passed"
    fi
    
    return $status
}

# --- Status Functions ---

# Print comprehensive audio status (for user display)
# Output: Formatted status information
audio_print_status() {
    local state
    state=$(audio_get_state)
    
    local controller_detected
    local cs35l41_detected
    local subsystem_id
    local sof_firmware
    local cs35l41_config
    
    controller_detected=$(echo "$state" | grep "controller_detected" | cut -d'"' -f4)
    cs35l41_detected=$(echo "$state" | grep "cs35l41_detected" | cut -d'"' -f4)
    subsystem_id=$(echo "$state" | grep "subsystem_id" | cut -d'"' -f4)
    sof_firmware=$(echo "$state" | grep "sof_firmware_installed" | cut -d'"' -f4)
    cs35l41_config=$(echo "$state" | grep "cs35l41_config_applied" | cut -d'"' -f4)
    
    echo "Audio Status (GZ302EA):"
    echo "  Controller:          $controller_detected"
    echo "  CS35L41 Amplifiers:  $cs35l41_detected"
    echo "  Subsystem ID:        $subsystem_id"
    echo "  SOF Firmware:        $sof_firmware"
    echo "  CS35L41 Config:      $cs35l41_config"
    
    # Check for expected subsystem ID
    if [[ "$subsystem_id" != "1043:1fb3" && "$subsystem_id" != "unknown" ]]; then
        echo "  ⚠️  WARNING: Unexpected subsystem ID (expected 1043:1fb3)"
    fi
    
    # Check for missing components
    if [[ "$sof_firmware" == "false" ]]; then
        echo "  ⚠️  WARNING: SOF firmware not installed"
        echo "      Audio may not work optimally"
    fi
    
    if [[ "$cs35l41_detected" == "true" && "$cs35l41_config" == "false" ]]; then
        echo "  ⚠️  WARNING: CS35L41 detected but not configured"
        echo "      Run 'audio_apply_configuration' to configure"
    fi
    
    # Display audio cards
    echo
    echo "Audio Cards:"
    audio_list_cards | while IFS= read -r line; do
        echo "  $line"
    done
}

# --- Library Information ---

audio_lib_version() {
    echo "3.0.0"
}

audio_lib_help() {
    cat <<'HELP'
GZ302 Audio Manager Library v3.0.0

Detection Functions (read-only):
  audio_detect_controller       - Check if audio controller present
  audio_detect_cs35l41          - Check if CS35L41 amplifiers detected
  audio_get_subsystem_id        - Get audio subsystem ID
  audio_module_loaded           - Check if snd_hda_intel loaded
  audio_sof_active              - Check if SOF is active
  audio_list_cards              - List audio cards

Firmware Functions:
  audio_sof_firmware_installed  - Check if SOF firmware installed
  audio_ucm_installed           - Check if ALSA UCM installed
  audio_install_sof_firmware <distro> - Install SOF firmware

State Check Functions:
  audio_cs35l41_config_applied  - Check if CS35L41 config applied
  audio_alsa_state_enabled      - Check if ALSA state service enabled
  audio_get_state               - Get comprehensive state (JSON)

Configuration Functions (idempotent):
  audio_apply_cs35l41_config    - Apply CS35L41 configuration
  audio_enable_alsa_state       - Enable ALSA state services
  audio_apply_configuration <distro> - Apply complete audio config

Verification Functions:
  audio_verify_working          - Verify audio is working
  audio_print_status            - Print formatted status (for users)

Library Information:
  audio_lib_version             - Get library version
  audio_lib_help                - Show this help

Example Usage:
  source strix-halo-lib/audio-manager.sh
  
  # Detect hardware
  if audio_detect_controller; then
      echo "Audio controller found"
  fi
  
  # Apply configuration
  audio_apply_configuration "arch"
  
  # Verify working
  audio_verify_working
  
  # Check status
  audio_print_status

Audio Hardware:
  Codec: Realtek ALC294
  Amplifiers: Dual Cirrus Logic CS35L41 (I2C)
  Firmware: Sound Open Firmware (SOF)
  Subsystem ID: 1043:1fb3 (ASUS ROG Flow Z13)

Design Principles:
  - Idempotent: Safe to run multiple times
  - Distribution-aware: Package management per distro
  - Hardware detection before configuration
  - Clear status reporting
HELP
}
