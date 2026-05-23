#!/bin/bash
# shellcheck disable=SC2034,SC2059
set -euo pipefail

# ==============================================================================
# Strix Halo Device Manager Library
# Version: 6.8.0
#
# Detects the running hardware and produces a normalized device profile for
# the Strix Halo (AMD Ryzen AI MAX / MAX+) platform.  All installer sections
# consume the profile flags produced here so only relevant fixes are offered
# to the user.
#
# Profile outputs (shell variables set by device_detect()):
#   DEVICE_VENDOR        — ASUS | HP | Framework | Other
#   DEVICE_MODEL         — human-readable model string
#   DEVICE_CLASS         — tablet | laptop | workstation-laptop | desktop |
#                          handheld | mini-pc | unknown
#   DEVICE_SUPPORT_TIER  — full | partial | experimental
#
# Capability flags (set by device_detect(), each "true" or "false"):
#   CAP_STRIX_HALO      — confirmed Strix Halo CPU/GPU signatures present
#   CAP_ASUS_WMI         — asus-wmi / asus-nb-wmi kernel interface present
#   CAP_DETACHABLE_KB    — device has a detachable keyboard (tablet mode)
#   CAP_INTERNAL_OLED    — device ships with an internal OLED panel
#   CAP_MT7925           — MediaTek MT7925 WiFi detected
#   CAP_CS35L41          — Cirrus Logic CS35L41 smart-amp detected
#   CAP_DASHBOARD        — generic Strix Halo dashboard / tray app is applicable
#   CAP_Z13CTL           — z13ctl hardware-control tool is applicable
#   CAP_COMMAND_CENTER   — GZ302 command-center tray app is applicable
#   CAP_ROCM             — ROCm GPU compute is applicable (Radeon 8050S/8060S present)
#
# Usage:
#   source strix-halo-lib/device-manager.sh
#   device_detect
#   device_print_profile
#   if [[ "$CAP_Z13CTL" == "true" ]]; then install_z13ctl; fi
# ==============================================================================

DEVICE_MANAGER_LIB_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if ! declare -F device_profile_known_record_by_dmi >/dev/null 2>&1; then
    # shellcheck source=/dev/null
    source "${DEVICE_MANAGER_LIB_DIR}/device-profile-data.sh"
fi

# --- Exported profile variables (defaults) ---
DEVICE_VENDOR="Unknown"
DEVICE_MODEL="Unknown Strix Halo device"
DEVICE_CLASS="unknown"
DEVICE_SUPPORT_TIER="experimental"

CAP_STRIX_HALO="false"
CAP_ASUS_WMI="false"
CAP_DETACHABLE_KB="false"
CAP_INTERNAL_OLED="false"
CAP_MT7925="false"
CAP_CS35L41="false"
CAP_DASHBOARD="false"
CAP_Z13CTL="false"
CAP_COMMAND_CENTER="false"
CAP_ROCM="false"

# --- Internal helpers ---

_dmi_read() {
    local field="$1"
    local path="/sys/class/dmi/id/${field}"
    if [[ -r "$path" ]]; then
        cat "$path" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

_cpu_model_read() {
    local cpu_model=""

    cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name:/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
    if [[ -n "$cpu_model" ]]; then
        printf '%s\n' "$cpu_model"
        return 0
    fi

    cpu_model=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2- | sed 's/^[[:space:]]*//')
    printf '%s\n' "$cpu_model"
}

_lspci_has() {
    lspci -nn 2>/dev/null | grep -Eiq "$1"
}

_lsusb_has() {
    lsusb 2>/dev/null | grep -Eiq "$1"
}

_kernel_module_loaded() {
    lsmod 2>/dev/null | grep -q "^${1}[[:space:]]"
}

device_detect_strix_halo_platform() {
    local vendor="$1"
    local product="$2"
    local family="$3"
    local board="$4"
    local cpu_model

    cpu_model=$(_cpu_model_read)
    if printf '%s\n' "$cpu_model" | grep -Eiq 'ryzen ai max(\+|[[:space:]]+pro|\+[[:space:]]+pro)?'; then
        CAP_STRIX_HALO="true"
        return 0
    fi

    if _lspci_has 'Strix Halo|Radeon 8050S|Radeon 8060S|1002:1586'; then
        CAP_STRIX_HALO="true"
        return 0
    fi

    if device_profile_known_record_by_dmi \
        "$(printf '%s' "$vendor" | tr '[:upper:]' '[:lower:]')" \
        "$(printf '%s %s %s\n' "$product" "$family" "$board" | tr '[:upper:]' '[:lower:]')" \
        >/dev/null; then
        CAP_STRIX_HALO="true"
        return 0
    fi

    CAP_STRIX_HALO="false"
    return 0
}

# --- Hardware Detection ---

# Detect MediaTek MT7925 WiFi (USB or PCIe)
device_detect_mt7925() {
    if _lspci_has "MT7925|14c3:0616|14c3:0617"; then
        CAP_MT7925="true"
        return 0
    fi
    if _lsusb_has "0e8d:7925|MT7925"; then
        CAP_MT7925="true"
        return 0
    fi
    CAP_MT7925="false"
}

# Detect Cirrus Logic CS35L41 smart amplifier
device_detect_cs35l41() {
    if aplay -l 2>/dev/null | grep -qi "cs35l41"; then
        CAP_CS35L41="true"
        return 0
    fi
    if find /sys/class/sound/ -name "card*" -exec cat {}/id \; 2>/dev/null | grep -qi "cs35l41"; then
        CAP_CS35L41="true"
        return 0
    fi
    if _lspci_has "Cirrus Logic" || _lspci_has "CS35L41"; then
        CAP_CS35L41="true"
        return 0
    fi
    CAP_CS35L41="false"
}

# Detect AMD Radeon 8060S / gfx1151 (Strix Halo iGPU)
device_detect_rocm() {
    if [[ "$CAP_STRIX_HALO" != "true" ]]; then
        CAP_ROCM="false"
        return 0
    fi
    if _lspci_has 'Strix Halo|Radeon 8050S|Radeon 8060S|1002:1586'; then
        CAP_ROCM="true"
        return 0
    fi
    CAP_ROCM="false"
    return 0
}

# Detect asus-wmi kernel interface availability
device_detect_asus_wmi() {
    if _kernel_module_loaded "asus_wmi" || _kernel_module_loaded "asus_nb_wmi"; then
        CAP_ASUS_WMI="true"
        return 0
    fi
    if [[ -d /sys/class/firmware-attributes/asus-armoury ]]; then
        CAP_ASUS_WMI="true"
        return 0
    fi
    CAP_ASUS_WMI="false"
}

# --- Device Profile Matching ---

# Map DMI information to a known device profile
_apply_device_profile() {
    local vendor="$1"
    local product="$2"
    local family="$3"
    local board="$4"

    # Normalise to lower-case for matching
    local v; v=$(echo "$vendor"  | tr '[:upper:]' '[:lower:]')
    local p; p=$(echo "$product" | tr '[:upper:]' '[:lower:]')
    local f; f=$(echo "$family"  | tr '[:upper:]' '[:lower:]')
    local b; b=$(echo "$board"   | tr '[:upper:]' '[:lower:]')
    local combined; combined=$(printf '%s %s %s\n' "$p" "$f" "$b")
    local known_record

    known_record=$(device_profile_known_record_by_dmi "$v" "$combined" || true)
    if [[ -n "$known_record" ]]; then
        device_profile_apply_record "$known_record"
        return 0
    fi

    # ---- ASUS Strix Halo (generic ASUS profile) -----------------------------
    if [[ "$CAP_STRIX_HALO" == "true" ]] && [[ "$v" == *"asus"* ]]; then
        DEVICE_VENDOR="ASUS"
        DEVICE_MODEL="ASUS Strix Halo (${product})"
        DEVICE_CLASS="laptop"
        DEVICE_SUPPORT_TIER="partial"
        CAP_Z13CTL="false"
        return 0
    fi

    # ---- HP ZBook Ultra G1a / HP workstations ------------------------------
    if [[ "$CAP_STRIX_HALO" == "true" ]] && [[ "$v" == *"hp"* || "$v" == *"hewlett"* ]]; then
        DEVICE_VENDOR="HP"
        DEVICE_MODEL="HP (${product})"
        DEVICE_CLASS="laptop"
        DEVICE_SUPPORT_TIER="partial"
        return 0
    fi

    # ---- Framework Desktop --------------------------------------------------
    if [[ "$CAP_STRIX_HALO" == "true" ]] && [[ "$v" == *"framework"* ]]; then
        DEVICE_VENDOR="Framework"
        DEVICE_MODEL="Framework (${product})"
        DEVICE_CLASS="desktop"
        DEVICE_SUPPORT_TIER="partial"
        return 0
    fi

    # ---- Handheld devices (AYANEO, GPD, etc.) -------------------------------
    if [[ "$CAP_STRIX_HALO" == "true" ]] && [[ "$v" == *"ayaneo"* ]]; then
        DEVICE_VENDOR="AYANEO"
        DEVICE_MODEL="AYANEO (${product})"
        DEVICE_CLASS="handheld"
        DEVICE_SUPPORT_TIER="experimental"
        return 0
    fi
    if [[ "$CAP_STRIX_HALO" == "true" ]] && [[ "$v" == *"gpd"* ]]; then
        DEVICE_VENDOR="GPD"
        DEVICE_MODEL="GPD (${product})"
        DEVICE_CLASS="handheld"
        DEVICE_SUPPORT_TIER="experimental"
        return 0
    fi

    # ---- Mini-PC ecosystem ---------------------------------------------------
    for brand in sixunited gmktec minisforum bosgame aoostar beelink geekom; do
        if [[ "$CAP_STRIX_HALO" == "true" ]] && [[ "$v" == *"$brand"* || "$p" == *"$brand"* || "$f" == *"$brand"* || "$b" == *"$brand"* ]]; then
            DEVICE_VENDOR="${vendor}"
            DEVICE_MODEL="${product}"
            DEVICE_CLASS="mini-pc"
            DEVICE_SUPPORT_TIER="experimental"
            return 0
        fi
    done

    # ---- Fallback: generic Strix Halo ---------------------------------------
    DEVICE_VENDOR="${vendor:-Unknown}"
    DEVICE_MODEL="${product:-Unknown device}"
    DEVICE_CLASS="unknown"
    DEVICE_SUPPORT_TIER="experimental"
    CAP_Z13CTL="false"
    CAP_COMMAND_CENTER="false"
}

# --- Primary Detection Entry Point ---

# Run full hardware detection and populate all profile + capability variables.
# Call this once at installer startup; all other functions read the globals.
device_detect() {
    local sys_vendor product_name product_family board_name

    DEVICE_VENDOR="Unknown"
    DEVICE_MODEL="Unknown Strix Halo device"
    DEVICE_CLASS="unknown"
    DEVICE_SUPPORT_TIER="experimental"

    CAP_STRIX_HALO="false"
    CAP_ASUS_WMI="false"
    CAP_DETACHABLE_KB="false"
    CAP_INTERNAL_OLED="false"
    CAP_MT7925="false"
    CAP_CS35L41="false"
    CAP_DASHBOARD="false"
    CAP_Z13CTL="false"
    CAP_COMMAND_CENTER="false"
    CAP_ROCM="false"

    sys_vendor=$(_dmi_read "sys_vendor")
    product_name=$(_dmi_read "product_name")
    product_family=$(_dmi_read "product_family")
    board_name=$(_dmi_read "board_name")

    device_detect_strix_halo_platform "$sys_vendor" "$product_name" "$product_family" "$board_name"

    if [[ "$CAP_STRIX_HALO" == "true" ]]; then
        CAP_DASHBOARD="true"
    fi

    # Run component capability probes
    device_detect_asus_wmi
    device_detect_mt7925
    device_detect_cs35l41
    device_detect_rocm

    _apply_device_profile "$sys_vendor" "$product_name" "$product_family" "$board_name"

    # If asus-wmi is not loaded on an ASUS device, z13ctl still applies via
    # the HID interface — don't override the profile flag.
    # For non-ASUS devices, z13ctl is not applicable unless explicitly set.
    if [[ "$DEVICE_VENDOR" != "ASUS" ]]; then
        CAP_Z13CTL="false"
        CAP_COMMAND_CENTER="false"
    fi

    export DEVICE_VENDOR DEVICE_MODEL DEVICE_CLASS DEVICE_SUPPORT_TIER
    export CAP_STRIX_HALO CAP_ASUS_WMI CAP_DETACHABLE_KB CAP_INTERNAL_OLED
    export CAP_MT7925 CAP_CS35L41 CAP_DASHBOARD CAP_Z13CTL CAP_COMMAND_CENTER CAP_ROCM
}

# --- Profile Display ---

# Print a human-readable device profile summary.
device_print_profile() {
    local tier_color
    case "$DEVICE_SUPPORT_TIER" in
        full)         tier_color="${C_BOLD_GREEN:-\033[1;32m}" ;;
        partial)      tier_color="${C_BOLD_YELLOW:-\033[1;33m}" ;;
        experimental) tier_color="${C_BOLD_RED:-\033[1;31m}" ;;
        *)            tier_color="${C_WHITE:-\033[0;37m}" ;;
    esac
    local nc="${C_NC:-\033[0m}"
    local blue="${C_BLUE:-\033[0;34m}"
    local white="${C_WHITE:-\033[0;37m}"

    printf "\n"
    printf "   ${blue}%-22s${nc} ${white}%s${nc}\n" "Device:" "$DEVICE_MODEL"
    printf "   ${blue}%-22s${nc} ${white}%s${nc}\n" "Vendor:" "$DEVICE_VENDOR"
    printf "   ${blue}%-22s${nc} ${white}%s${nc}\n" "Class:" "$DEVICE_CLASS"
    printf "   ${blue}%-22s${nc} ${tier_color}%s${nc}\n" "Support tier:" "$DEVICE_SUPPORT_TIER"
    printf "\n"
    printf "   ${blue}%-22s${nc} " "Capabilities:"
    local caps=()
    [[ "$CAP_STRIX_HALO"     == "true" ]] && caps+=("strix-halo")
    [[ "$CAP_ASUS_WMI"      == "true" ]] && caps+=("asus-wmi")
    [[ "$CAP_DETACHABLE_KB" == "true" ]] && caps+=("detachable-kb")
    [[ "$CAP_INTERNAL_OLED" == "true" ]] && caps+=("internal-oled")
    [[ "$CAP_MT7925"        == "true" ]] && caps+=("MT7925-wifi")
    [[ "$CAP_CS35L41"       == "true" ]] && caps+=("CS35L41-audio")
    [[ "$CAP_DASHBOARD"     == "true" ]] && caps+=("dashboard")
    [[ "$CAP_Z13CTL"        == "true" ]] && caps+=("z13ctl")
    [[ "$CAP_COMMAND_CENTER" == "true" ]] && caps+=("command-center")
    [[ "$CAP_ROCM"          == "true" ]] && caps+=("ROCm")
    if [[ ${#caps[@]} -gt 0 ]]; then
        printf "${white}%s${nc}\n" "$(IFS=', '; echo "${caps[*]}")"
    else
        printf "${white}%s${nc}\n" "none detected"
    fi
    printf "\n"
}

# Return 0 if the device is a known Strix Halo device (has AMD Radeon 8060S /
# gfx1151 iGPU).  Callers can use this as a gating check before continuing.
device_is_strix_halo() {
    [[ "$CAP_STRIX_HALO" == "true" ]]
}

# Return support tier string
device_get_support_tier() {
    echo "$DEVICE_SUPPORT_TIER"
}

# Check a single capability flag by name (portable uppercase conversion)
# Usage: device_has_capability "Z13CTL" && install_z13ctl
device_has_capability() {
    local cap_name
    cap_name=$(echo "CAP_${1}" | tr '[:lower:]' '[:upper:]')
    [[ "${!cap_name:-false}" == "true" ]]
}
