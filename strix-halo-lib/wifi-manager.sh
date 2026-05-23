#!/bin/bash
# shellcheck disable=SC2034,SC2059
set -euo pipefail

# ==============================================================================
# GZ302 WiFi Manager Library
# Version: 6.8.0
#
# This library provides hardware detection, configuration, and management
# functions for the MediaTek MT7925e WiFi controller in the GZ302.
#
# Library-First Design:
# - Detection functions (read-only, no system changes)
# - Configuration functions (idempotent, check before apply)
# - Verification functions (validate fixes are working)
# - Cleanup functions (remove obsolete workarounds)
#
# Usage:
#   source strix-halo-lib/wifi-manager.sh
#   wifi_detect_hardware
#   wifi_check_state
#   wifi_apply_fix
#   wifi_verify_fix
# ==============================================================================

# --- WiFi Hardware Detection (Read-Only) ---

# Detect if MT7925e WiFi controller is present
# Returns: 0 if found, 1 if not found
# Output: PCI device information if found
wifi_detect_hardware() {
    local pci_id="14c3:0616"  # MediaTek MT7925e PCI ID
    
    # Get device info once to avoid duplicate lspci calls
    local device_info
    device_info=$(lspci -nn 2>/dev/null | grep "$pci_id")
    
    if [[ -n "$device_info" ]]; then
        echo "$device_info"
        return 0
    else
        return 1
    fi
}

# Check if mt7925e kernel module is loaded
# Returns: 0 if loaded, 1 if not loaded
wifi_module_loaded() {
    lsmod | grep -q "^mt7925e"
}

# Get current WiFi firmware version
# Returns: Firmware version string or "unknown"
wifi_get_firmware_version() {
    local fw_path="/lib/firmware/mediatek"
    if [[ -f "$fw_path/mt7925e.bin" ]]; then
        # Try to extract version from dmesg (driver loads firmware)
        local fw_ver
        fw_ver=$(dmesg | grep -i "mt7925e.*firmware" | tail -1 | grep -oP 'version.*' || echo "present")
        echo "$fw_ver"
        return 0
    else
        echo "unknown"
        return 1
    fi
}

# --- Kernel Version Compatibility Checks ---

# Check if current kernel requires ASPM workaround
# Returns: 0 if workaround needed, 1 if not needed
wifi_requires_aspm_workaround() {
    # Use kernel-compat library if available, otherwise fallback to local logic
    if declare -f kernel_get_version_num >/dev/null 2>&1; then
        local version_num
        version_num=$(kernel_get_version_num)
        [[ $version_num -lt 617 ]]
    else
        # Fallback: local implementation
        local kernel_version
        kernel_version=$(uname -r | cut -d. -f1,2)
        local major minor
        major=$(echo "$kernel_version" | cut -d. -f1)
        minor=$(echo "$kernel_version" | cut -d. -f2)
        local version_num=$((major * 100 + minor))
        [[ $version_num -lt 617 ]]
    fi
}

# --- State Detection (What's Currently Applied) ---

# Check if ASPM workaround is currently applied
# Returns: 0 if applied, 1 if not applied
# Output: Status message
wifi_aspm_workaround_applied() {
    if [[ -f /etc/modprobe.d/mt7925.conf ]]; then
        if grep -q "disable_aspm=1" /etc/modprobe.d/mt7925.conf 2>/dev/null; then
            echo "applied"
            return 0
        else
            echo "not_applied"
            return 1
        fi
    else
        echo "not_applied"
        return 1
    fi
}

# Check if NetworkManager power saving is disabled
# Returns: 0 if disabled, 1 if not disabled
wifi_powersave_disabled() {
    if [[ -f /etc/NetworkManager/conf.d/wifi-powersave.conf ]]; then
        if grep -q "wifi.powersave = 2" /etc/NetworkManager/conf.d/wifi-powersave.conf 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Get comprehensive WiFi state
# Output: JSON-like state information
wifi_get_state() {
    local hardware_present="false"
    local module_loaded="false"
    local aspm_workaround="false"
    local powersave_disabled="false"
    local firmware="unknown"
    local requires_workaround="false"
    
    if wifi_detect_hardware >/dev/null 2>&1; then
        hardware_present="true"
    fi
    
    if wifi_module_loaded; then
        module_loaded="true"
    fi
    
    if wifi_aspm_workaround_applied >/dev/null 2>&1; then
        aspm_workaround="true"
    fi
    
    if wifi_powersave_disabled; then
        powersave_disabled="true"
    fi
    
    firmware=$(wifi_get_firmware_version)
    
    if wifi_requires_aspm_workaround; then
        requires_workaround="true"
    fi
    
    cat <<EOF
{
    "hardware_present": "$hardware_present",
    "module_loaded": "$module_loaded",
    "aspm_workaround_applied": "$aspm_workaround",
    "aspm_workaround_required": "$requires_workaround",
    "powersave_disabled": "$powersave_disabled",
    "firmware_version": "$firmware"
}
EOF
}

# --- Configuration Application (Idempotent) ---

# Apply ASPM workaround (idempotent - check before applying)
# Returns: 0 if applied or already applied, 1 on error
wifi_apply_aspm_workaround() {
    # Check if already applied
    if wifi_aspm_workaround_applied >/dev/null 2>&1; then
        return 0  # Already applied, nothing to do
    fi
    
    # Create modprobe configuration
    cat > /etc/modprobe.d/mt7925.conf <<'EOF'
# MediaTek MT7925 Wi-Fi fix for GZ302
# Disable ASPM for stability (required for kernels < 6.17)
# Based on community findings from EndeavourOS forums and kernel patches
options mt7925e disable_aspm=1
EOF
    
    # Verify creation
    if [[ ! -f /etc/modprobe.d/mt7925.conf ]]; then
        return 1
    fi
    
    # Reload module if currently loaded
    if wifi_module_loaded; then
        modprobe -r mt7925e 2>/dev/null || true
        sleep 1
        modprobe mt7925e 2>/dev/null || true
    fi
    
    return 0
}

# Remove ASPM workaround and use native support
# Returns: 0 if removed or already removed, 1 on error
wifi_remove_aspm_workaround() {
    # Check if workaround is applied
    if ! wifi_aspm_workaround_applied >/dev/null 2>&1; then
        return 0  # Already removed, nothing to do
    fi
    
    # Create clean configuration noting native support
    cat > /etc/modprobe.d/mt7925.conf <<'EOF'
# MediaTek MT7925 Wi-Fi configuration for GZ302
# Kernel 6.17+ has native ASPM support - no workarounds needed
# WiFi 7 MLO support and enhanced stability included natively
EOF
    
    # Reload module if currently loaded
    if wifi_module_loaded; then
        modprobe -r mt7925e 2>/dev/null || true
        sleep 1
        modprobe mt7925e 2>/dev/null || true
    fi
    
    return 0
}

# Disable NetworkManager WiFi power saving (idempotent)
# Returns: 0 if disabled or already disabled
wifi_disable_powersave() {
    # Check if already disabled
    if wifi_powersave_disabled; then
        return 0  # Already disabled
    fi
    
    # Create NetworkManager configuration
    mkdir -p /etc/NetworkManager/conf.d/
    cat > /etc/NetworkManager/conf.d/wifi-powersave.conf <<'EOF'
[connection]
# Disable WiFi power saving for stability (2 = disabled)
wifi.powersave = 2
EOF
    
    # Restart NetworkManager if running
    if systemctl is-active NetworkManager >/dev/null 2>&1; then
        systemctl reload NetworkManager 2>/dev/null || true
    fi
    
    return 0
}

# Apply appropriate WiFi configuration based on kernel version (idempotent)
# Returns: 0 on success, 1 on error
# Output: Status messages
wifi_apply_configuration() {
    local status=0
    
    # Always disable power saving (beneficial on all kernels)
    if ! wifi_disable_powersave; then
        echo "WARNING: Failed to disable WiFi power saving"
        status=1
    fi
    
    # Apply kernel-specific configuration
    if wifi_requires_aspm_workaround; then
        echo "Kernel < 6.17 detected: Applying ASPM workaround"
        if ! wifi_apply_aspm_workaround; then
            echo "ERROR: Failed to apply ASPM workaround"
            return 1
        fi
        echo "ASPM workaround applied successfully"
    else
        echo "Kernel 6.17+ detected: Using native ASPM support"
        if wifi_aspm_workaround_applied >/dev/null 2>&1; then
            echo "Removing obsolete ASPM workaround"
            if ! wifi_remove_aspm_workaround; then
                echo "WARNING: Failed to remove ASPM workaround"
                status=1
            else
                echo "Obsolete ASPM workaround removed successfully"
            fi
        else
            echo "Native ASPM support already configured"
        fi
    fi
    
    return $status
}

# --- Verification Functions ---

# Verify WiFi is working correctly
# Returns: 0 if working, 1 if issues detected
# Output: Status information
wifi_verify_working() {
    local status=0
    
    # Check hardware present
    if ! wifi_detect_hardware >/dev/null 2>&1; then
        echo "ERROR: MT7925e WiFi hardware not detected"
        return 1
    fi
    
    # Check module loaded
    if ! wifi_module_loaded; then
        echo "WARNING: mt7925e kernel module not loaded"
        status=1
    fi
    
    # Check for kernel errors
    if dmesg | tail -100 | grep -qi "mt7925.*error\|mt7925.*fail"; then
        echo "WARNING: Recent WiFi errors in kernel log"
        status=1
    fi
    
    # Check WiFi interface exists
    if ! ip link show | grep -q "wl"; then
        echo "WARNING: No wireless interface found"
        status=1
    fi
    
    if [[ $status -eq 0 ]]; then
        echo "WiFi verification passed"
    fi
    
    return $status
}

# --- Summary/Status Functions ---

# Print comprehensive WiFi status (for user display)
# Output: Formatted status information
wifi_print_status() {
    local state
    state=$(wifi_get_state)
    
    local hardware_present
    local module_loaded
    local aspm_workaround
    local requires_workaround
    local powersave_disabled
    local firmware
    
    hardware_present=$(echo "$state" | grep "hardware_present" | cut -d'"' -f4)
    module_loaded=$(echo "$state" | grep "module_loaded" | cut -d'"' -f4)
    aspm_workaround=$(echo "$state" | grep "aspm_workaround_applied" | cut -d'"' -f4)
    requires_workaround=$(echo "$state" | grep "aspm_workaround_required" | cut -d'"' -f4)
    powersave_disabled=$(echo "$state" | grep "powersave_disabled" | cut -d'"' -f4)
    firmware=$(echo "$state" | grep "firmware_version" | cut -d'"' -f4)
    
    echo "WiFi Status (MediaTek MT7925e):"
    echo "  Hardware Present:    $hardware_present"
    echo "  Module Loaded:       $module_loaded"
    echo "  Firmware Version:    $firmware"
    echo "  ASPM Workaround:     $aspm_workaround (required: $requires_workaround)"
    echo "  Power Save Disabled: $powersave_disabled"
    
    # Check for misconfigurations
    if [[ "$aspm_workaround" == "true" && "$requires_workaround" == "false" ]]; then
        echo "  ⚠️  WARNING: ASPM workaround applied on kernel 6.17+ (harmful to battery life)"
        echo "      Run 'wifi_apply_configuration' to remove obsolete workaround"
    fi
    
    if [[ "$aspm_workaround" == "false" && "$requires_workaround" == "true" ]]; then
        echo "  ⚠️  WARNING: ASPM workaround needed but not applied (WiFi may be unstable)"
        echo "      Run 'wifi_apply_configuration' to apply workaround"
    fi
}

# --- Library Information ---

# Get library version
wifi_lib_version() {
    echo "3.0.0"
}

# Get library help
wifi_lib_help() {
    cat <<'HELP'
GZ302 WiFi Manager Library v3.0.0

Detection Functions (read-only):
  wifi_detect_hardware          - Check if MT7925e WiFi present
  wifi_module_loaded            - Check if kernel module loaded
  wifi_get_firmware_version     - Get firmware version
  wifi_requires_aspm_workaround - Check if workaround needed for kernel version
  wifi_get_state                - Get comprehensive state (JSON format)

State Check Functions:
  wifi_aspm_workaround_applied  - Check if ASPM workaround is applied
  wifi_powersave_disabled       - Check if NetworkManager power saving disabled

Configuration Functions (idempotent):
  wifi_apply_aspm_workaround    - Apply ASPM workaround (kernel < 6.17)
  wifi_remove_aspm_workaround   - Remove ASPM workaround (kernel 6.17+)
  wifi_disable_powersave        - Disable NetworkManager power saving
  wifi_apply_configuration      - Apply kernel-appropriate configuration

Verification Functions:
  wifi_verify_working           - Verify WiFi is working correctly
  wifi_print_status             - Print formatted status (for users)

Library Information:
  wifi_lib_version              - Get library version
  wifi_lib_help                 - Show this help

Example Usage:
  source strix-halo-lib/wifi-manager.sh
  wifi_detect_hardware && echo "WiFi found"
  wifi_get_state
  wifi_apply_configuration
  wifi_verify_working
  wifi_print_status

Design Principles:
  - Idempotent: Safe to run multiple times
  - Kernel-aware: Adapts to kernel version
  - State-aware: Checks before applying
  - Separation: Detection separate from configuration
HELP
}
