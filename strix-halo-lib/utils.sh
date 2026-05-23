#!/bin/bash
# shellcheck disable=SC2034,SC2059,SC2086,SC2329,SC2030,SC2031
# SC2034: Variables are exported for use in other scripts
# SC2059: Printf format strings use color variables intentionally
# SC2086: Word splitting used intentionally in seq commands
set -euo pipefail
# SC2329: Functions are invoked indirectly from main script
# SC2030/SC2031: Subshell variable modification is handled

# ==============================================================================
# Strix Halo Shared Utilities Library
# Version: 6.8.0
#
# This library contains shared functions for the Strix Halo Linux Setup scripts.
# It is sourced by strix-halo-setup.sh and all optional modules.
# ==============================================================================

# --- System Paths (Single Source of Truth) ---
export CONFIG_DIR="/etc/strix-halo"
export BIN_DIR="/usr/local/bin"
export STATE_DIR="/var/lib/gz302"
export LOG_DIR="/var/log/gz302"
export BACKUP_DIR="/var/backups/gz302"
export UDEV_RULES_DIR="/etc/udev/rules.d"
export SUDOERS_DIR="/etc/sudoers.d"
export SYSTEMD_DIR="/etc/systemd/system"

# Ensure directories exist (when running as root)
if [[ $EUID -eq 0 ]]; then
    mkdir -p "$CONFIG_DIR" "$STATE_DIR" "$LOG_DIR" "$BACKUP_DIR"
fi

# --- Color codes and formatting for beautiful output ---
# Text colors (foreground)
C_BLACK=$'\033[0;30m'
C_RED=$'\033[0;31m'
C_GREEN=$'\033[0;32m'
C_YELLOW=$'\033[0;33m'
C_BLUE=$'\033[0;34m'
C_MAGENTA=$'\033[0;35m'
C_CYAN=$'\033[0;36m'
C_WHITE=$'\033[0;37m'

# Bold/bright colors
C_BOLD=$'\033[1m'
C_BOLD_RED=$'\033[1;31m'
C_BOLD_GREEN=$'\033[1;32m'
C_BOLD_YELLOW=$'\033[1;33m'
C_BOLD_BLUE=$'\033[1;34m'
C_BOLD_CYAN=$'\033[1;36m'
C_BOLD_WHITE=$'\033[1;37m'

# Text formatting
C_DIM=$'\033[2m'
C_ITALIC=$'\033[3m'
C_UNDERLINE=$'\033[4m'
C_BLINK=$'\033[5m'
C_REVERSE=$'\033[7m'

# Reset
C_NC=$'\033[0m' # No Color

# Unicode symbols for beautiful output
SYMBOL_CHECK="✓"
SYMBOL_CROSS="✗"
SYMBOL_ARROW="→"
SYMBOL_BULLET="•"
SYMBOL_STAR="★"
SYMBOL_INFO="ℹ"
SYMBOL_WARNING="⚠"
SYMBOL_ERROR="✖"
SYMBOL_PACKAGE="📦"
SYMBOL_GEAR="⚙"
SYMBOL_ROCKET="🚀"
SYMBOL_WRENCH="🔧"
SYMBOL_SHIELD="🛡"
SYMBOL_LIGHTNING="⚡"

# Spinner frames for progress indication (braille pattern - smooth animation)
SPINNER_FRAMES=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')

# Track current step for progress display
CURRENT_STEP=0
TOTAL_STEPS=0

# --- Logging and error functions with beautiful formatting ---

# Print a major section header with a decorative box
print_section() {
    local title="$1"
    local width=60
    local padding=$(( (width - ${#title} - 2) / 2 ))
    
    echo
    printf "${C_BOLD_CYAN}"
    printf '╔'; printf '═%.0s' $(seq 1 $width); printf '╗\n'
    printf '║'; printf ' %.0s' $(seq 1 $padding); printf " %s " "$title"; printf ' %.0s' $(seq 1 $((width - padding - ${#title} - 2))); printf '║\n'
    printf '╚'; printf '═%.0s' $(seq 1 $width); printf '╝'
    printf "${C_NC}\n"
    echo
}

# Print a subsection header
print_subsection() {
    local title="$1"
    echo
    printf "${C_BOLD_BLUE}━━━ %s ━━━${C_NC}\n" "$title"
}

# Print a step indicator (e.g., [1/5] Installing packages...)
print_step() {
    local current="$1"
    local total="$2"
    local message="$3"
    
    CURRENT_STEP=$current
    TOTAL_STEPS=$total
    
    printf "${C_BOLD_WHITE}[${C_CYAN}%d${C_WHITE}/${C_CYAN}%d${C_BOLD_WHITE}]${C_NC} ${C_WHITE}%s${C_NC}\n" "$current" "$total" "$message"
}

# Enhanced error message with prominent formatting
error() {
    echo >&2
    printf "${C_BOLD_RED}╭─ ${SYMBOL_ERROR} ERROR ────────────────────────────────────────────╮${C_NC}\n" >&2
    printf "${C_BOLD_RED}│${C_NC} ${C_RED}%s${C_NC}\n" "$1" >&2
    printf "${C_BOLD_RED}╰───────────────────────────────────────────────────────────╯${C_NC}\n" >&2
    echo >&2
    exit 1
}

# Enhanced info message
info() {
    # Write info messages to stderr so callers can capture stdout cleanly
    printf "${C_CYAN}${SYMBOL_INFO}${C_NC}  ${C_WHITE}%s${C_NC}\n" "$1" >&2
}

# Enhanced success message
success() {
    printf "${C_BOLD_GREEN}${SYMBOL_CHECK}${C_NC}  ${C_GREEN}%s${C_NC}\n" "$1" >&2
}

# Enhanced warning message
warning() {
    printf "${C_BOLD_YELLOW}${SYMBOL_WARNING}${C_NC}  ${C_YELLOW}%s${C_NC}\n" "$1" >&2
}

# Print a progress item (indented bullet point)
progress_item() {
    printf "   ${C_DIM}${SYMBOL_BULLET}${C_NC} ${C_WHITE}%s${C_NC}\n" "$1"
}

# Print a completed item with checkmark
completed_item() {
    printf "   ${C_GREEN}${SYMBOL_CHECK}${C_NC} ${C_DIM}%s${C_NC}\n" "$1"
}

# Print a failed item with cross
failed_item() {
    printf "   ${C_RED}${SYMBOL_CROSS}${C_NC} ${C_RED}%s${C_NC}\n" "$1"
}

# Start a spinner in the background
# Usage: start_spinner "Installing packages..."
# Then: stop_spinner (when done)
SPINNER_PID=""
SPINNER_MSG=""

start_spinner() {
    local msg="${1:-Working...}"
    SPINNER_MSG="$msg"
    
    # Don't start spinner if not in a terminal
    [[ ! -t 1 ]] && return
    
    (
        local i=0
        while true; do
            printf "\r${C_CYAN}${SPINNER_FRAMES[$i]}${C_NC} ${C_WHITE}%s${C_NC}  " "$msg"
            i=$(( (i + 1) % ${#SPINNER_FRAMES[@]} ))
            sleep 0.1
        done
    ) &
    SPINNER_PID=$!
    disown
}

stop_spinner() {
    local status="${1:-success}"
    local msg="${2:-$SPINNER_MSG}"
    
    # Kill the spinner if running
    if [[ -n "$SPINNER_PID" ]]; then
        kill "$SPINNER_PID" 2>/dev/null
        wait "$SPINNER_PID" 2>/dev/null
        SPINNER_PID=""
    fi
    
    # Clear the line and print final status
    [[ -t 1 ]] && printf "\r\033[K"
    
    if [[ "$status" == "success" ]]; then
        printf "${C_GREEN}${SYMBOL_CHECK}${C_NC} ${C_WHITE}%s${C_NC}\n" "$msg"
    elif [[ "$status" == "warning" ]]; then
        printf "${C_YELLOW}${SYMBOL_WARNING}${C_NC} ${C_YELLOW}%s${C_NC}\n" "$msg"
    else
        printf "${C_RED}${SYMBOL_CROSS}${C_NC} ${C_RED}%s${C_NC}\n" "$msg"
    fi
}

# Print a simple progress bar
# Usage: print_progress_bar current total [width]
print_progress_bar() {
    local current=$1
    local total=$2
    local width=${3:-40}
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "\r${C_CYAN}["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "]${C_NC} ${C_WHITE}%3d%%${C_NC}" "$percent"
}

# Print completion bar at end of progress
finish_progress_bar() {
    printf "\n"
}

# Print a key-value pair nicely formatted
print_keyval() {
    local key="$1"
    local val="$2"
    local width="${3:-20}"
    printf "   ${C_BLUE}%-${width}s${C_NC} ${C_WHITE}%s${C_NC}\n" "$key:" "$val"
}

# Print a status line (used for showing current operation)
print_status() {
    local status="$1"
    local message="$2"
    
    case "$status" in
        "ok"|"success"|"done")
            printf "${C_GREEN}[  OK  ]${C_NC} %s\n" "$message"
            ;;
        "fail"|"error")
            printf "${C_RED}[FAILED]${C_NC} %s\n" "$message"
            ;;
        "skip"|"skipped")
            printf "${C_YELLOW}[ SKIP ]${C_NC} %s\n" "$message"
            ;;
        "info")
            printf "${C_CYAN}[ INFO ]${C_NC} %s\n" "$message"
            ;;
        "wait"|"running")
            printf "${C_BLUE}[ .... ]${C_NC} %s\n" "$message"
            ;;
        *)
            printf "${C_WHITE}[      ]${C_NC} %s\n" "$message"
            ;;
    esac
}

# Print a boxed message (for important notices)
print_box() {
    local message="$1"
    local color="${2:-$C_WHITE}"
    local width=60
    local msg_len=${#message}
    local padding=$(( (width - msg_len - 2) / 2 ))
    
    echo
    printf "${color}"
    printf '┌'; printf '─%.0s' $(seq 1 $width); printf '┐\n'
    printf '│'; printf ' %.0s' $(seq 1 $padding); printf " %s " "$message"; printf ' %.0s' $(seq 1 $((width - padding - msg_len - 2))); printf '│\n'
    printf '└'; printf '─%.0s' $(seq 1 $width); printf '┘'
    printf "${C_NC}\n"
    echo
}

# Print a tip/hint message
print_tip() {
    local tip="$1"
    printf "${C_DIM}💡 ${C_ITALIC}%s${C_NC}\n" "$tip"
}

# Print the GZ302 banner (for script startup)
print_banner() {
    printf "${C_BOLD_CYAN}"
    cat << 'BANNER'
   ██████╗ ███████╗██████╗  ██████╗ ██████╗ 
  ██╔════╝ ╚══███╔╝╚════██╗██╔═████╗╚════██╗
  ██║  ███╗  ███╔╝  █████╔╝██║██╔██║ █████╔╝
  ██║   ██║ ███╔╝   ╚═══██╗████╔╝██║██╔═══╝ 
  ╚██████╔╝███████╗██████╔╝╚██████╔╝███████╗
   ╚═════╝ ╚══════╝╚═════╝  ╚═════╝ ╚══════╝
BANNER
    printf "${C_NC}"
    printf "${C_DIM}   Strix Halo Linux Setup — AMD Ryzen AI MAX Platform${C_NC}\n"
    printf "${C_DIM}   Radeon 8060S | gfx1151 | RDNA 3.5${C_NC}\n"
    echo
}

# --- User Detection ---
get_real_user() {
    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
        echo "${SUDO_USER}"
    elif command -v logname >/dev/null 2>&1; then
        logname 2>/dev/null || whoami
    else
        whoami
    fi
}

# --- Distribution Detection ---
detect_distribution() {
    local distro=""
    
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        
        # Detect Arch-based systems (including Omarchy, CachyOS, EndeavourOS, Manjaro)
        if [[ "${ID:-}" == "arch" || "${ID:-}" == "omarchy" || "${ID:-}" == "cachyos" || "${ID_LIKE:-}" == *"arch"* ]]; then
            distro="arch"
        # Detect Debian/Ubuntu-based systems
        # First, be more specific for ubuntu and its derivatives
        elif [[ "${ID:-}" == "ubuntu" || "${ID:-}" == "pop" || "${ID:-}" == "linuxmint" || "${ID_LIKE:-}" == *"ubuntu"* ]]; then
            distro="ubuntu"
        # fallback to debian based systems (including Kali)
        elif [[ "${ID:-}" == "debian" || "${ID:-}" == "kali" || "${ID_LIKE:-}" == *"debian"* ]]; then
            distro="debian"
        # Detect Fedora-based systems
        elif [[ "${ID:-}" == "fedora" || "${ID_LIKE:-}" == *"fedora"* ]]; then
            distro="fedora"
        # Detect OpenSUSE-based systems
        elif [[ "${ID:-}" == "opensuse-tumbleweed" || "${ID:-}" == "opensuse-leap" || "${ID:-}" == "opensuse" || "${ID_LIKE:-}" == *"suse"* ]]; then
            distro="opensuse"
        fi
    fi
    
    if [[ -z "$distro" ]]; then
        # Fallback for unknown distros, return unknown but don't exit
        echo "unknown"
    else
        echo "$distro"
    fi
}

# --- Bootloader Detection ---
detect_bootloader() {
    if [[ -d "/boot/loader" ]] && [[ -f "/boot/loader/loader.conf" ]]; then
        echo "systemd-boot"
    elif [[ -f "/boot/grub/grub.cfg" ]] || [[ -f "/boot/grub2/grub.cfg" ]]; then
        echo "grub"
    elif [[ -f "/etc/default/limine" ]] || [[ -f "/etc/limine/limine.conf" ]] || [[ -f "/boot/limine/limine.conf" ]] || [[ -f "/boot/limine.cfg" ]] || [[ -f "/boot/limine.conf" ]]; then
        echo "limine"
    elif [[ -f "/boot/refind_linux.conf" ]]; then
        echo "refind"
    elif [[ -f "/boot/syslinux/syslinux.cfg" ]]; then
        echo "syslinux"
    elif [[ -f "/boot/extlinux/extlinux.conf" ]]; then
        echo "extlinux"
    else
        echo "unknown"
    fi
}

# --- Kernel Parameter Helpers ---

# Appends a kernel parameter to GRUB_CMDLINE_LINUX_DEFAULT if it's missing.
# Returns 0 if a change was made, 1 if no change was needed, 2 if GRUB config not found.
ensure_grub_kernel_param() {
    local param="$1"
    local grub_file="/etc/default/grub"
    if [[ ! -f "$grub_file" ]]; then
        return 2
    fi
    # Extract the current line value
    local current
    current=$(grep -E '^GRUB_CMDLINE_LINUX_DEFAULT="' "$grub_file" || true)
    if [[ -z "$current" ]]; then
        return 2
    fi
    # If already present in the default line, no change
    if echo "$current" | grep -q -- "$param"; then
        return 1
    fi
    # Escape characters for sed (including quotes inside param)
    local escaped
    escaped=$(printf '%s' "$param" | sed -e 's/[&/]/\\&/g' -e 's/\"/\\\\\"/g')
    sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1 ${escaped}\"/" "$grub_file"
    return 0
}

# Appends a kernel parameter to /etc/kernel/cmdline if it's missing.
# Returns 0 if a change was made, 1 if no change was needed, 2 if cmdline not found.
ensure_kcmdline_param() {
    local param="$1"
    local cmdline_file="/etc/kernel/cmdline"
    if [[ ! -f "$cmdline_file" ]]; then
        return 2
    fi
    local current
    current=$(cat "$cmdline_file" 2>/dev/null || true)
    if printf '%s' "$current" | grep -q -- "$param"; then
        return 1
    fi
    # Append parameter preserving existing content; ensure trailing newline
    printf '%s %s\n' "${current}" "$param" | sed 's/^ *//' > "${cmdline_file}.tmp" && mv "${cmdline_file}.tmp" "$cmdline_file"
    return 0
}

# Patch a systemd-boot loader entry "options" line to include a param if missing
# Args: file_path, param
ensure_loader_entry_param() {
    local file="$1"
    local param="$2"
    if [[ ! -f "$file" ]]; then
        return 2
    fi
    # Read the existing options line (first occurrence)
    local opts
    opts=$(grep -m1 '^options ' "$file" || true)
    if [[ -z "$opts" ]]; then
        return 2
    fi
    if printf '%s' "$opts" | grep -q -- "$param"; then
        return 1
    fi
    # Safely append to options line
    local escaped
    escaped=$(printf '%s' "$param" | sed -e 's/[&/]/\\&/g')
    sed -i "0,/^options /s//& ${escaped} /" "$file"
    return 0
}

# ==============================================================================
# CONFIG BACKUP SYSTEM
# Creates timestamped backups of configurations before making changes
# ==============================================================================

# GZ302_BACKUP_DIR and GZ302_CHECKPOINT_FILE are now set from STATE_DIR and BACKUP_DIR
GZ302_CHECKPOINT_FILE="${STATE_DIR}/checkpoint"

# Create a backup of existing configurations before making changes
# Usage: create_config_backup "description"
create_config_backup() {
    local description="${1:-system-configs}"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_subdir="${BACKUP_DIR}/${timestamp}_${description}"
    
    # Create backup directory
    mkdir -p "$backup_subdir"
    
    print_subsection "Creating Configuration Backup"
    info "Backup location: $backup_subdir"
    
    local backed_up=0
    
    # Backup modprobe.d configurations
    if [[ -d /etc/modprobe.d ]]; then
        local modprobe_files
        modprobe_files=$(find /etc/modprobe.d -name "*gz302*" -o -name "*mt7925*" -o -name "*amdgpu*" 2>/dev/null || true)
        if [[ -n "$modprobe_files" ]]; then
            mkdir -p "$backup_subdir/modprobe.d"
            while IFS= read -r f; do
                if [[ -f "$f" ]]; then
                    cp "$f" "$backup_subdir/modprobe.d/"
                    ((backed_up++))
                fi
            done <<< "$modprobe_files"
            completed_item "Modprobe configurations"
        fi
    fi
    
    # Backup systemd services
    if [[ -d "$SYSTEMD_DIR" ]]; then
        local systemd_files
        systemd_files=$(find "$SYSTEMD_DIR" -name "*gz302*" 2>/dev/null || true)
        if [[ -n "$systemd_files" ]]; then
            mkdir -p "$backup_subdir/systemd"
            while IFS= read -r f; do
                if [[ -f "$f" ]]; then
                    cp "$f" "$backup_subdir/systemd/"
                    ((backed_up++))
                fi
            done <<< "$systemd_files"
            completed_item "Systemd services"
        fi
    fi
    
    # Backup sudoers entries
    if [[ -d "$SUDOERS_DIR" ]]; then
        local sudoers_files
        sudoers_files=$(find "$SUDOERS_DIR" -name "*gz302*" -o -name "*pwrcfg*" -o -name "*rrcfg*" 2>/dev/null || true)
        if [[ -n "$sudoers_files" ]]; then
            mkdir -p "$backup_subdir/sudoers.d"
            while IFS= read -r f; do
                if [[ -f "$f" ]]; then
                    cp "$f" "$backup_subdir/sudoers.d/"
                    ((backed_up++))
                fi
            done <<< "$sudoers_files"
            completed_item "Sudoers configurations"
        fi
    fi
    
    # Backup custom scripts
    if [[ -d "$BIN_DIR" ]]; then
        local script_files
        script_files=$(find "$BIN_DIR" -name "*gz302*" -o -name "pwrcfg" -o -name "rrcfg" 2>/dev/null || true)
        if [[ -n "$script_files" ]]; then
            mkdir -p "$backup_subdir/bin"
            while IFS= read -r f; do
                if [[ -f "$f" ]]; then
                    cp "$f" "$backup_subdir/bin/"
                    ((backed_up++))
                fi
            done <<< "$script_files"
            completed_item "Custom scripts"
        fi
    fi
    
    # Backup config directories
    for config_dir in "$CONFIG_DIR" "/etc/strix-halo-tdp" "/etc/strix-halo-refresh" "/etc/strix-halo-rgb"; do
        if [[ -d "$config_dir" ]]; then
            local dir_name
            dir_name=$(basename "$config_dir")
            cp -r "$config_dir" "$backup_subdir/${dir_name}/"
            completed_item "Config directory: $dir_name"
            ((backed_up++)) || true
        fi
    done
    
    # Create backup manifest
    cat > "$backup_subdir/MANIFEST.txt" << EOF
GZ302 Configuration Backup
==========================
Date: $(date)
Description: $description
Contents:
$(find "$backup_subdir" -type f ! -name "MANIFEST.txt" | sed "s|$backup_subdir/||")

To restore:
  sudo cp -r $backup_subdir/* /
EOF
    
    if [[ $backed_up -gt 0 ]]; then
        success "Backup created: $backup_subdir"
        print_tip "To restore: sudo cp -r $backup_subdir/* /"
    else
        info "No existing configurations to backup"
        rmdir "$backup_subdir" 2>/dev/null || true
    fi
    
    echo "$backup_subdir"
}

# List available backups
list_backups() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        info "No backups found"
        return 1
    fi
    
    print_subsection "Available Backups"
    local count=0
    for backup in "$BACKUP_DIR"/*; do
        if [[ -d "$backup" ]]; then
            local name
            name=$(basename "$backup")
            local manifest="$backup/MANIFEST.txt"
            if [[ -f "$manifest" ]]; then
                local date_line
                date_line=$(grep "^Date:" "$manifest" | head -1)
                info "$name - ${date_line#Date: }"
            else
                info "$name"
            fi
            ((count++))
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        info "No backups found"
        return 1
    fi
    
    return 0
}

# ==============================================================================
# ERROR RECOVERY / CHECKPOINT SYSTEM
# Tracks completed steps for resumable installations
# ==============================================================================

# Initialize or load checkpoint state
# Usage: init_checkpoint "install-phase"
init_checkpoint() {
    local phase="${1:-main}"
    local checkpoint_dir
    checkpoint_dir=$(dirname "$GZ302_CHECKPOINT_FILE")
    
    mkdir -p "$checkpoint_dir"
    
    # Check for existing checkpoint
    if [[ -f "$GZ302_CHECKPOINT_FILE" ]]; then
        local saved_phase
        saved_phase=$(grep "^PHASE=" "$GZ302_CHECKPOINT_FILE" | cut -d'=' -f2)
        if [[ "$saved_phase" == "$phase" ]]; then
            return 0  # Checkpoint exists for this phase
        fi
    fi
    
    # Create new checkpoint file
    cat > "$GZ302_CHECKPOINT_FILE" << EOF
PHASE=$phase
STARTED=$(date +%s)
LAST_UPDATE=$(date +%s)
COMPLETED_STEPS=
EOF
    return 0  # New checkpoint created
}

# Ask a yes/no prompt, with support for global ASSUME_YES (non-interactive)
# Usage: ask_yes_no "Prompt text" "default"    # default: Y or N
ask_yes_no() {
    local prompt="$1"
    local default="${2:-N}"
    # If ASSUME_YES is set (true), automatically return yes
    if [[ "${ASSUME_YES:-false}" == "true" ]]; then
        return 0
    fi
    local response
    read -r -p "$prompt" response
    response=${response:-$default}
    if [[ "$response" =~ ^[Yy] ]]; then
        return 0
    fi
    return 1
}

# Mark a step as completed
# Usage: complete_step "step-name"
complete_step() {
    local step="$1"
    
    if [[ ! -f "$GZ302_CHECKPOINT_FILE" ]]; then
        return 1
    fi
    
    # Add step to completed list
    local current_steps
    current_steps=$(grep "^COMPLETED_STEPS=" "$GZ302_CHECKPOINT_FILE" | cut -d'=' -f2)
    
    if [[ -z "$current_steps" ]]; then
        current_steps="$step"
    else
        current_steps="${current_steps},$step"
    fi
    
    sed -i "s/^COMPLETED_STEPS=.*/COMPLETED_STEPS=${current_steps}/" "$GZ302_CHECKPOINT_FILE"
    sed -i "s/^LAST_UPDATE=.*/LAST_UPDATE=$(date +%s)/" "$GZ302_CHECKPOINT_FILE"
}

# Check if a step was already completed
# Usage: is_step_completed "step-name"
is_step_completed() {
    local step="$1"
    
    if [[ ! -f "$GZ302_CHECKPOINT_FILE" ]]; then
        return 1
    fi
    
    local completed_steps
    completed_steps=$(grep "^COMPLETED_STEPS=" "$GZ302_CHECKPOINT_FILE" | cut -d'=' -f2)
    
    if echo ",$completed_steps," | grep -q ",$step,"; then
        return 0
    fi
    return 1
}

# Get list of completed steps
get_completed_steps() {
    if [[ ! -f "$GZ302_CHECKPOINT_FILE" ]]; then
        echo ""
        return
    fi
    
    grep "^COMPLETED_STEPS=" "$GZ302_CHECKPOINT_FILE" | cut -d'=' -f2
}

# Clear checkpoint (installation complete)
clear_checkpoint() {
    rm -f "$GZ302_CHECKPOINT_FILE"
}

# Check if we're resuming from a checkpoint
check_resume() {
    local phase="${1:-main}"
    
    if [[ ! -f "$GZ302_CHECKPOINT_FILE" ]]; then
        return 1  # No checkpoint to resume
    fi
    
    local saved_phase
    saved_phase=$(grep "^PHASE=" "$GZ302_CHECKPOINT_FILE" | cut -d'=' -f2)
    
    if [[ "$saved_phase" != "$phase" ]]; then
        return 1  # Different phase
    fi
    
    local completed_steps
    completed_steps=$(get_completed_steps)
    
    if [[ -z "$completed_steps" ]]; then
        return 1  # No steps completed
    fi
    
    # Found a valid checkpoint
    return 0
}

# Show resume prompt
prompt_resume() {
    local phase="${1:-main}"
    
    if ! check_resume "$phase"; then
        return 1
    fi
    
    local completed_steps
    completed_steps=$(get_completed_steps)
    local step_count
    step_count=$(echo "$completed_steps" | tr ',' '\n' | wc -l)
    
    local last_update
    last_update=$(grep "^LAST_UPDATE=" "$GZ302_CHECKPOINT_FILE" | cut -d'=' -f2)
    local last_date
    last_date=$(date -d "@$last_update" 2>/dev/null || date -r "$last_update" 2>/dev/null || echo "unknown")
    
    echo
    print_box "Resume Previous Installation?"
    info "Found incomplete installation from: $last_date"
    info "Completed steps: $step_count"
    echo
    
    # Use helper to ask prompt but honor ASSUME_YES
    if ask_yes_no "Resume from last checkpoint? [Y/n] " Y; then
        return 0
    else
        clear_checkpoint
        return 1
    fi
}

# Configure kernel parameters for rEFInd
ensure_refind_kernel_param() {
    local param="$1"
    local refind_conf="/boot/refind_linux.conf"

    if [[ -f "$refind_conf" ]]; then
        # Check if parameters already exist
        if ! grep -q "$param" "$refind_conf"; then
            # Add parameters to the options line
            # Escaping for sed
            local escaped
            escaped=$(printf '%s' "$param" | sed -e 's/[&/]/\\&/g')
            sed -i "/^\"Boot with standard options\"/ s/\"$/ ${escaped}\"/" "$refind_conf"
            return 0
        else
            return 1
        fi
    else
        return 2
    fi
}

# Configure kernel parameters for syslinux/extlinux
ensure_syslinux_kernel_param() {
    local param="$1"
    local syslinux_cfg=""

    if [[ -f "/boot/syslinux/syslinux.cfg" ]]; then
        syslinux_cfg="/boot/syslinux/syslinux.cfg"
    elif [[ -f "/boot/extlinux/extlinux.conf" ]]; then
        syslinux_cfg="/boot/extlinux/extlinux.conf"
    fi

    if [[ -n "$syslinux_cfg" ]]; then
        # Check if parameters already exist
        if ! grep -q "$param" "$syslinux_cfg"; then
            # Add parameters to APPEND line
            local escaped
            escaped=$(printf '%s' "$param" | sed -e 's/[&/]/\\&/g')
            sed -i "/^APPEND/ s/$/ ${escaped}/" "$syslinux_cfg"
            return 0
        else
            return 1
        fi
    else
        return 2
    fi
}

# Configure kernel parameters for Limine bootloader
# Limine commonly uses /etc/default/limine with KERNEL_CMDLINE[default]+="params"
# Changes require running 'limine-update' (preferred) or 'limine-mkinitcpio'
# Returns 0 if a change was made, 1 if no change was needed, 2 if config not found.
ensure_limine_kernel_param() {
    local param="$1"
    local limine_conf="/etc/default/limine"

    if [[ ! -f "$limine_conf" ]]; then
        return 2
    fi

    # Check if parameter already exists in any KERNEL_CMDLINE line
    if grep -q -- "$param" "$limine_conf"; then
        return 1
    fi

    # Escape special characters for sed (& / and also escape for shell)
    local escaped
    escaped=$(printf '%s' "$param" | sed -e 's/[&/\]/\\&/g')

    # Check if KERNEL_CMDLINE[default] line exists with quotes
    if grep -qE '^KERNEL_CMDLINE\[default\]\+?="[^"]*"' "$limine_conf"; then
        # Append to existing KERNEL_CMDLINE[default] line (handles both = and +=)
        sed -i -E "s/^(KERNEL_CMDLINE\[default\](\+)?=\"[^\"]*)\"/\1 ${escaped}\"/" "$limine_conf"
        return 0
    elif grep -qE '^KERNEL_CMDLINE\[default\]' "$limine_conf"; then
        # Line exists but in different format - append new line instead
        echo "KERNEL_CMDLINE[default]+=\"$param\"" >> "$limine_conf"
        return 0
    else
        # Add new KERNEL_CMDLINE[default] line at the end
        echo "KERNEL_CMDLINE[default]+=\"$param\"" >> "$limine_conf"
        return 0
    fi
}

limine_regenerate_entries() {
    if command -v limine-update >/dev/null 2>&1; then
        if limine-update 2>/dev/null; then
            return 0
        fi

        warning "limine-update failed - manual Limine regeneration may be required"
        return 1
    fi

    if command -v limine-mkinitcpio >/dev/null 2>&1; then
        if limine-mkinitcpio 2>/dev/null; then
            return 0
        fi

        warning "limine-mkinitcpio failed - manual Limine regeneration may be required"
        return 1
    fi

    warning "No Limine update command found - manual Limine regeneration may be required"
    return 1
}
