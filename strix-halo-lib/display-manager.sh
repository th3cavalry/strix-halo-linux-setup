#!/bin/bash
# shellcheck disable=SC2034,SC2059
set -euo pipefail

# ==============================================================================
# GZ302 Display Manager Library
# Version: 6.8.0
#
# This library provides refresh rate management and display control for the
# ASUS ROG Flow Z13 (GZ302) with its 180Hz display.
#
# Library-First Design:
# - Detection functions (read-only, no system changes)
# - Configuration functions (idempotent, check before apply)
# - VRR (Variable Refresh Rate) control
# - Status functions (display current state)
#
# Supported Environments:
# - X11 (xrandr)
# - Wayland (wlr-randr for wlroots, kscreen for KDE)
# - DRM fallback
#
# Usage:
#   source strix-halo-lib/display-manager.sh
#   display_detect_outputs
#   display_apply_profile "balanced"
#   display_print_status
# ==============================================================================

# --- Refresh Rate Profile Definitions ---
declare -gA DISPLAY_REFRESH_PROFILES
DISPLAY_REFRESH_PROFILES[emergency]="30"         # Emergency battery extension
DISPLAY_REFRESH_PROFILES[battery]="30"           # Maximum battery life
DISPLAY_REFRESH_PROFILES[efficient]="60"         # Efficient with good performance
DISPLAY_REFRESH_PROFILES[balanced]="90"          # Balanced performance/power
DISPLAY_REFRESH_PROFILES[performance]="120"      # High performance applications
DISPLAY_REFRESH_PROFILES[gaming]="180"           # Gaming optimized
DISPLAY_REFRESH_PROFILES[maximum]="180"          # Absolute maximum

# Frame rate limiting profiles (for MangoHUD/Gamescope)
declare -gA DISPLAY_FRAME_LIMITS
DISPLAY_FRAME_LIMITS[emergency]="30"             # Cap at 30fps
DISPLAY_FRAME_LIMITS[battery]="30"               # Cap at 30fps
DISPLAY_FRAME_LIMITS[efficient]="60"             # Cap at 60fps
DISPLAY_FRAME_LIMITS[balanced]="90"              # Cap at 90fps
DISPLAY_FRAME_LIMITS[performance]="120"          # Cap at 120fps
DISPLAY_FRAME_LIMITS[gaming]="0"                 # No frame limiting
DISPLAY_FRAME_LIMITS[maximum]="0"                # No frame limiting

# VRR min/max refresh ranges by profile
declare -gA DISPLAY_VRR_MIN
declare -gA DISPLAY_VRR_MAX
DISPLAY_VRR_MIN[emergency]="20";  DISPLAY_VRR_MAX[emergency]="30"
DISPLAY_VRR_MIN[battery]="20";    DISPLAY_VRR_MAX[battery]="30"
DISPLAY_VRR_MIN[efficient]="30";  DISPLAY_VRR_MAX[efficient]="60"
DISPLAY_VRR_MIN[balanced]="30";   DISPLAY_VRR_MAX[balanced]="90"
DISPLAY_VRR_MIN[performance]="48"; DISPLAY_VRR_MAX[performance]="120"
DISPLAY_VRR_MIN[gaming]="48";     DISPLAY_VRR_MAX[gaming]="180"
DISPLAY_VRR_MIN[maximum]="48";    DISPLAY_VRR_MAX[maximum]="180"

# Profile order for iteration
DISPLAY_PROFILE_ORDER="emergency battery efficient balanced performance gaming maximum"

# Configuration paths
DISPLAY_CONFIG_DIR="/etc/strix-halo/rrcfg"
DISPLAY_CURRENT_PROFILE_FILE="$DISPLAY_CONFIG_DIR/current-profile"
DISPLAY_VRR_ENABLED_FILE="$DISPLAY_CONFIG_DIR/vrr-enabled"
DISPLAY_VRR_RANGES_FILE="$DISPLAY_CONFIG_DIR/vrr-ranges"

# GZ302 built-in display info
GZ302_INTERNAL_DISPLAY="eDP-1"
GZ302_MAX_REFRESH="180"
GZ302_RESOLUTION="2560x1600"

# --- Display Detection (Read-Only) ---

# Check if running in X11
# Returns: 0 if X11, 1 otherwise
display_is_x11() {
    [[ -n "${DISPLAY:-}" ]] && command -v xrandr >/dev/null 2>&1
}

# Check if running in Wayland
# Returns: 0 if Wayland, 1 otherwise
display_is_wayland() {
    [[ -n "${WAYLAND_DISPLAY:-}" ]] || [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]]
}

# Check if wlr-randr is available (wlroots compositors)
# Returns: 0 if available, 1 otherwise
display_has_wlr_randr() {
    command -v wlr-randr >/dev/null 2>&1
}

# Check if gdctl is available (GNOME >= 48, X11/Wayland)
# https://gitlab.gnome.org/GNOME/mutter/-/blob/main/doc/man/gdctl.rst
# Returns: 0 if available, 1 otherwise
display_has_gdctl() {
    command -v gdctl >/dev/null 2>&1
}

# Check if KDE kscreen tools are available
# Returns: 0 if available, 1 otherwise
display_has_kscreen() {
    command -v kscreen-doctor >/dev/null 2>&1
}

# Detect connected displays
# Returns: Space-separated list of display names
display_detect_outputs() {
    local displays=()
    
    if display_is_x11; then
        # X11 environment
        mapfile -t displays < <(xrandr --listmonitors 2>/dev/null | grep -E "^ [0-9]:" | awk '{print $4}' | cut -d'/' -f1)
    elif display_has_wlr_randr; then
        # Wayland with wlr-randr
        mapfile -t displays < <(wlr-randr 2>/dev/null | grep -E "^[A-Za-z]" | awk '{print $1}')
    elif display_has_kscreen; then
        # KDE Plasma on Wayland
        mapfile -t displays < <(kscreen-doctor -o 2>/dev/null | grep -E "^Output:" | awk '{print $2}' | cut -d: -f1)
    fi
    
    # Fallback to DRM
    if [[ ${#displays[@]} -eq 0 && -d /sys/class/drm ]]; then
        mapfile -t displays < <(find /sys/class/drm -maxdepth 1 -name "card*-*" -type l -exec basename {} \; 2>/dev/null | grep -v "Virtual" | head -5)
    fi
    
    # Default fallback
    if [[ ${#displays[@]} -eq 0 ]]; then
        displays=("eDP-1")
    fi
    
    echo "${displays[@]}"
}

# Get primary/internal display
# Returns: Display name
display_get_primary() {
    local displays
    displays=$(display_detect_outputs)
    
    # Look for internal display first (eDP)
    for disp in $displays; do
        if [[ "$disp" == eDP* || "$disp" == *-eDP-* ]]; then
            echo "$disp"
            return 0
        fi
    done
    
    # Return first display
    echo "$displays" | awk '{print $1}'
}

# --- Refresh Rate Detection ---

# Get current refresh rate for a display
# Args: $1 = display (optional, defaults to primary)
# Returns: Refresh rate in Hz
display_get_current_refresh() {
    local display="${1:-$(display_get_primary)}"
    local rate=""
    
    if display_is_x11; then
        # X11: Parse current mode from xrandr
        rate=$(xrandr 2>/dev/null | grep -A20 "^${display}" | grep -E "^\s+" | grep "\*" | head -1 | grep -oP '\d+\.\d+(?=\*?)' | cut -d. -f1)
    elif display_has_wlr_randr; then
        # Wayland with wlr-randr
        rate=$(wlr-randr 2>/dev/null | grep -A5 "^${display}" | grep -oP '\d+(?=\.\d+ Hz)' | head -1)
    elif display_has_kscreen; then
        # KDE Plasma
        rate=$(kscreen-doctor -o 2>/dev/null | grep -A5 "$display" | grep "Refresh:" | grep -oP '\d+(?=Hz)')
    fi
    
    # Fallback
    if [[ -z "$rate" ]]; then
        rate="60"
    fi
    
    echo "$rate"
}

# Get supported refresh rates for a display
# Args: $1 = display (optional)
# Returns: Newline-separated list of rates
display_get_supported_rates() {
    local display="${1:-$(display_get_primary)}"
    local rates=""
    
    if display_is_x11; then
        # X11: Extract all refresh rates from current resolution mode
        rates=$(xrandr 2>/dev/null | grep -A20 "^${display}" | grep -E "^\s+${GZ302_RESOLUTION}" | grep -oP '\d+\.\d+' | cut -d. -f1 | sort -nu)
    elif display_has_wlr_randr; then
        rates=$(wlr-randr 2>/dev/null | grep -A30 "^${display}" | grep -oP '\d+(?=\.\d+ Hz)' | sort -nu)
    fi
    
    # Fallback: Common GZ302 rates
    if [[ -z "$rates" ]]; then
        printf '%s\n' 30 48 60 90 120 180
        return
    fi
    
    echo "$rates"
}

# --- VRR (Variable Refresh Rate) ---

# Check if VRR is supported
# Returns: 0 if supported, 1 if not
display_vrr_supported() {
    # Check kernel support
    if [[ ! -d /sys/class/drm ]]; then
        return 1
    fi
    
    # Look for vrr_capable in DRM properties
    local drm_device
    for drm_device in /sys/class/drm/card*-*/; do
        if [[ -f "${drm_device}vrr_capable" ]]; then
            if [[ "$(cat "${drm_device}vrr_capable" 2>/dev/null)" == "1" ]]; then
                return 0
            fi
        fi
    done
    
    # Check for AMD GPU with VRR
    if lsmod 2>/dev/null | grep -q "^amdgpu"; then
        return 0  # Assume VRR capable if AMD GPU
    fi
    
    return 1
}

# Check if VRR is currently enabled
# Returns: 0 if enabled, 1 if disabled
display_vrr_enabled() {
    if [[ -f "$DISPLAY_VRR_ENABLED_FILE" ]]; then
        [[ "$(cat "$DISPLAY_VRR_ENABLED_FILE" 2>/dev/null)" == "true" ]]
    else
        return 1
    fi
}

# Enable VRR
# Returns: 0 on success, 1 on failure
display_vrr_enable() {
    if ! display_vrr_supported; then
        echo "VRR not supported on this system" >&2
        return 1
    fi
    
    mkdir -p "$DISPLAY_CONFIG_DIR"
    echo "true" > "$DISPLAY_VRR_ENABLED_FILE"
    
    # Try to enable at DRM level
    local drm_device
    for drm_device in /sys/class/drm/card*-*/; do
        if [[ -f "${drm_device}vrr_enabled" ]]; then
            echo "1" > "${drm_device}vrr_enabled" 2>/dev/null || true
        fi
    done
    
    echo "VRR enabled"
    return 0
}

# Disable VRR
# Returns: 0 on success
display_vrr_disable() {
    mkdir -p "$DISPLAY_CONFIG_DIR"
    echo "false" > "$DISPLAY_VRR_ENABLED_FILE"
    
    local drm_device
    for drm_device in /sys/class/drm/card*-*/; do
        if [[ -f "${drm_device}vrr_enabled" ]]; then
            echo "0" > "${drm_device}vrr_enabled" 2>/dev/null || true
        fi
    done
    
    echo "VRR disabled"
    return 0
}

# --- Profile State ---

# Get current display profile
# Returns: profile name or "unknown"
display_get_current_profile() {
    if [[ -f "$DISPLAY_CURRENT_PROFILE_FILE" ]]; then
        tr -d ' \n' < "$DISPLAY_CURRENT_PROFILE_FILE" 2>/dev/null
    else
        echo "unknown"
    fi
}

# Check if profile is valid
# Args: $1 = profile name
# Returns: 0 if valid, 1 if invalid
display_profile_valid() {
    local profile="$1"
    [[ -n "${DISPLAY_REFRESH_PROFILES[$profile]:-}" ]]
}

# --- Profile Application ---

# Set refresh rate using xrandr (X11)
# Args: $1 = display, $2 = rate
# Returns: 0 on success, 1 on failure
display_set_rate_xrandr() {
    local display="$1"
    local rate="$2"
    
    if xrandr --output "$display" --rate "$rate" 2>/dev/null; then
        return 0
    fi
    return 1
}

# Set refresh rate using wlr-randr (wlroots Wayland)
# Args: $1 = display, $2 = rate
# Returns: 0 on success, 1 on failure
display_set_rate_wlr() {
    local display="$1"
    local rate="$2"
    
    # wlr-randr requires full mode spec, try different formats
    if wlr-randr --output "$display" --custom-mode "${GZ302_RESOLUTION}@${rate}Hz" 2>/dev/null; then
        return 0
    fi
    if wlr-randr --output "$display" --mode "${GZ302_RESOLUTION}@${rate}Hz" 2>/dev/null; then
        return 0
    fi
    return 1
}

# Set refresh rate using kscreen-doctor (KDE Wayland)
# Args: $1 = display, $2 = rate  
# Returns: 0 on success, 1 on failure
display_set_rate_kscreen() {
    local display="$1"
    local rate="$2"
    
    if kscreen-doctor "output.${display}.mode.${GZ302_RESOLUTION}@${rate}" 2>/dev/null; then
        return 0
    fi
    return 1
}

# Apply a display profile (sets refresh rate)
# Args: $1 = profile name
# Returns: 0 on success, 1 on failure
display_apply_profile() {
    local profile="$1"
    
    if ! display_profile_valid "$profile"; then
        echo "Error: Unknown profile '$profile'" >&2
        return 1
    fi
    
    local target_rate="${DISPLAY_REFRESH_PROFILES[$profile]}"
    local displays
    displays=$(display_detect_outputs)
    
    echo "Setting refresh rate profile: $profile (${target_rate}Hz)"
    
    local success=false
    local display
    
    for display in $displays; do
        echo "Configuring display: $display"
        
        # Try X11 first
        if display_is_x11; then
            if display_set_rate_xrandr "$display" "$target_rate"; then
                echo "  ✓ Set ${target_rate}Hz using xrandr"
                success=true
                continue
            fi
        fi
        
        # Try wlr-randr
        if display_has_wlr_randr; then
            if display_set_rate_wlr "$display" "$target_rate"; then
                echo "  ✓ Set ${target_rate}Hz using wlr-randr"
                success=true
                continue
            fi
        fi
        
        # Try kscreen
        if display_has_kscreen; then
            if display_set_rate_kscreen "$display" "$target_rate"; then
                echo "  ✓ Set ${target_rate}Hz using kscreen-doctor"
                success=true
                continue
            fi
        fi
        
        echo "  ⚠ Could not set refresh rate for $display"
    done
    
    if [[ "$success" == true ]]; then
        # Save current profile
        mkdir -p "$DISPLAY_CONFIG_DIR"
        echo "$profile" > "$DISPLAY_CURRENT_PROFILE_FILE"
        
        # Apply VRR range if enabled
        if display_vrr_enabled; then
            local min_range="${DISPLAY_VRR_MIN[$profile]:-48}"
            local max_range="${DISPLAY_VRR_MAX[$profile]:-$target_rate}"
            echo "VRR range: ${min_range}-${max_range}Hz"
            echo "${min_range}:${max_range}" > "$DISPLAY_VRR_RANGES_FILE"
        fi
        
        # Apply frame limit if applicable
        local frame_limit="${DISPLAY_FRAME_LIMITS[$profile]:-0}"
        if [[ "$frame_limit" != "0" ]]; then
            display_set_frame_limit "$frame_limit"
        fi
        
        echo "Display profile '$profile' applied"
        return 0
    else
        echo "Error: Failed to apply display profile" >&2
        return 1
    fi
}

# Set frame rate limit via MangoHUD config
# Args: $1 = fps limit (0 = no limit)
display_set_frame_limit() {
    local limit="$1"
    
    # Find user's home directory
    local user_home
    if [[ -n "${SUDO_USER:-}" ]]; then
        user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    else
        user_home="$HOME"
    fi
    
    local mangohud_dir="$user_home/.config/MangoHud"
    local mangohud_config="$mangohud_dir/MangoHud.conf"
    
    mkdir -p "$mangohud_dir" 2>/dev/null || true
    
    if [[ "$limit" == "0" ]]; then
        # Remove FPS limit
        if [[ -f "$mangohud_config" ]]; then
            sed -i '/^fps_limit=/d' "$mangohud_config" 2>/dev/null
        fi
        echo "Frame rate limit removed"
    else
        # Set FPS limit
        if [[ -f "$mangohud_config" ]]; then
            sed -i '/^fps_limit=/d' "$mangohud_config" 2>/dev/null
        fi
        echo "fps_limit=$limit" >> "$mangohud_config"
        echo "MangoHUD frame limit set to ${limit}fps"
    fi
}

# --- Status Display ---

# Print formatted display status
display_print_status() {
    local displays
    displays=$(display_detect_outputs)
    local primary
    primary=$(display_get_primary)
    
    echo "Display Status:"
    echo "  Environments: $(display_is_x11 && echo "X11") $(display_is_wayland && echo "Wayland")"
    echo "  Primary Display: $primary"
    echo "  Current Refresh: $(display_get_current_refresh "$primary")Hz"
    echo "  Current Profile: $(display_get_current_profile)"
    
    echo ""
    echo "VRR Status:"
    display_vrr_supported && echo "  VRR: Supported" || echo "  VRR: Not supported"
    display_vrr_enabled && echo "  VRR Enabled: Yes" || echo "  VRR Enabled: No"
    if [[ -f "$DISPLAY_VRR_RANGES_FILE" ]]; then
        echo "  VRR Range: $(tr ':' '-' < "$DISPLAY_VRR_RANGES_FILE" 2>/dev/null)Hz"
    fi
    
    echo ""
    echo "Connected Displays:"
    local disp
    for disp in $displays; do
        local rate
        rate=$(display_get_current_refresh "$disp")
        echo "  $disp: ${rate}Hz"
    done
    
    echo ""
    echo "Available Tools:"
    display_is_x11 && command -v xrandr >/dev/null && echo "  ✓ xrandr (X11)"
    display_has_wlr_randr && echo "  ✓ wlr-randr (Wayland)"
    display_has_gdctl && echo "  ✓ gdctl (GNOME >= 48, X11/Wayland)"
    display_has_kscreen && echo "  ✓ kscreen-doctor (KDE)"
}

# List all profiles with details
display_list_profiles() {
    echo "Available Refresh Rate Profiles:"
    local profile
    for profile in $DISPLAY_PROFILE_ORDER; do
        if display_profile_valid "$profile"; then
            local rate="${DISPLAY_REFRESH_PROFILES[$profile]}"
            local frame="${DISPLAY_FRAME_LIMITS[$profile]}"
            local vrr_min="${DISPLAY_VRR_MIN[$profile]}"
            local vrr_max="${DISPLAY_VRR_MAX[$profile]}"
            local frame_info
            [[ "$frame" == "0" ]] && frame_info="no limit" || frame_info="${frame}fps cap"
            printf "  %-12s %3dHz (VRR: %d-%dHz, %s)\n" "${profile}:" "$rate" "$vrr_min" "$vrr_max" "$frame_info"
        fi
    done
}

# --- Installation Support ---

# Check if rrcfg command is installed
# Returns: 0 if installed, 1 if not
display_command_installed() {
    [[ -x /usr/local/bin/rrcfg ]]
}

# Get the rrcfg script content for installation
display_get_rrcfg_script() {
    cat <<'RRCFG_SCRIPT'
#!/bin/bash
# GZ302 Refresh Rate Configuration Script (rrcfg)
# This is a thin wrapper that loads the display-manager library
# and provides a CLI interface.

set -euo pipefail

# Most display operations require root for DRM access
requires_elevation() {
    case "${1:-}" in
        status|list|help|"") return 1 ;;
        *) return 0 ;;
    esac
}

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    if requires_elevation "${1:-}"; then
        if sudo -n true 2>/dev/null; then
            exec sudo -n "$0" "$@"
        fi
        echo "rrcfg requires elevated privileges." >&2
        exit 1
    fi
fi

# Load display-manager library
LIB_PATH="/usr/local/share/gz302/strix-halo-lib"
if [[ -f "$LIB_PATH/display-manager.sh" ]]; then
    source "$LIB_PATH/display-manager.sh"
else
    echo "Error: display-manager.sh not found at $LIB_PATH" >&2
    exit 1
fi

# CLI handling
case "${1:-}" in
    emergency|battery|efficient|balanced|performance|gaming|maximum)
        display_apply_profile "$1"
        ;;
    status)
        display_print_status
        ;;
    list)
        display_list_profiles
        ;;
    vrr)
        case "${2:-}" in
            on)  display_vrr_enable ;;
            off) display_vrr_disable ;;
            *)
                echo "VRR Status:"
                display_vrr_supported && echo "  Supported: Yes" || echo "  Supported: No"
                display_vrr_enabled && echo "  Enabled: Yes" || echo "  Enabled: No"
                ;;
        esac
        ;;
    help|--help|-h|"")
        echo "Usage: rrcfg [PROFILE|COMMAND]"
        echo ""
        display_list_profiles
        echo ""
        echo "Commands:"
        echo "  status      - Show current display status"
        echo "  list        - List available profiles"
        echo "  vrr [on|off] - Enable/disable VRR"
        echo "  help        - Show this help"
        ;;
    *)
        echo "Error: Unknown command '$1'" >&2
        echo "Use 'rrcfg help' for usage" >&2
        exit 1
        ;;
esac
RRCFG_SCRIPT
}

# Ensure configuration directory exists
display_init_config() {
    mkdir -p "$DISPLAY_CONFIG_DIR"
    
    # Set default VRR state if not present
    if [[ ! -f "$DISPLAY_VRR_ENABLED_FILE" ]]; then
        echo "false" > "$DISPLAY_VRR_ENABLED_FILE"
    fi
}

# --- Library Info ---
display_lib_version() {
    echo "6.0.0"
}

display_lib_help() {
    echo "GZ302 Display Manager Library"
    echo ""
    echo "Functions:"
    echo "  display_detect_outputs      - Detect connected displays"
    echo "  display_get_current_refresh  - Get current refresh rate"
    echo "  display_apply_profile        - Apply a refresh rate profile"
    echo "  display_vrr_enable/disable   - Control Variable Refresh Rate"
    echo "  display_print_status         - Show current display state"
    echo "  display_list_profiles        - List available profiles"
    echo "  display_lib_version          - Show library version"
    echo "  display_lib_help             - Show this help"
}
