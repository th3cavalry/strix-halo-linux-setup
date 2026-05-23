#!/bin/bash
# shellcheck disable=SC2034,SC2059
set -euo pipefail

# ==============================================================================
# GZ302 State Manager Library
# Version: 6.8.0
#
# This library provides persistent state tracking for the GZ302 toolkit.
# It tracks what fixes have been applied, when they were applied, and provides
# rollback capabilities.
#
# State is stored in: /var/lib/gz302/state/
# Backups stored in: /var/backups/gz302/
# Logs stored in: /var/log/gz302/
#
# Usage:
#   source strix-halo-lib/state-manager.sh
#   state_init
#   state_mark_applied "wifi" "aspm_workaround" "6.16"
#   state_is_applied "wifi" "aspm_workaround"
#   state_rollback "wifi" "aspm_workaround"
# ==============================================================================

# --- State Directory Paths ---
readonly STATE_STORE_DIR="/var/lib/gz302/state"
readonly BACKUP_DIR="/var/backups/gz302"
readonly LOG_DIR="/var/log/gz302"
readonly STATE_VERSION="1.0"

# --- Initialization ---

# Initialize state management directories
# Returns: 0 on success, 1 on failure
state_init() {
    # Create state directory
    if [[ ! -d "$STATE_STORE_DIR" ]]; then
        mkdir -p "$STATE_STORE_DIR" 2>/dev/null || {
            echo "ERROR: Failed to create state directory: $STATE_STORE_DIR"
            return 1
        }
    fi
    
    # Create backup directory
    if [[ ! -d "$BACKUP_DIR" ]]; then
        mkdir -p "$BACKUP_DIR" 2>/dev/null || {
            echo "WARNING: Failed to create backup directory: $BACKUP_DIR"
        }
    fi
    
    # Create log directory
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR" 2>/dev/null || {
            echo "WARNING: Failed to create log directory: $LOG_DIR"
        }
    fi
    
    # Create version file if it doesn't exist
    if [[ ! -f "$STATE_STORE_DIR/version" ]]; then
        local tmp_ver
        tmp_ver=$(mktemp "${STATE_STORE_DIR}/version.XXXXXX")
        echo "$STATE_VERSION" > "$tmp_ver"
        mv "$tmp_ver" "${STATE_STORE_DIR}/version"
    fi
    
    return 0
}

# Check if state management is initialized
# Returns: 0 if initialized, 1 if not
state_is_initialized() {
    [[ -d "$STATE_STORE_DIR" ]] && [[ -f "$STATE_STORE_DIR/version" ]]
}

# --- Component State Management ---

# Get state file path for component
# Args: $1 = component name (wifi, gpu, input, audio, etc.)
# Returns: Path to state file
state_get_component_file() {
    local component="$1"
    echo "$STATE_STORE_DIR/${component}.state"
}

# Mark a fix as applied for a component
# Args: $1 = component, $2 = fix_name, $3 = metadata (optional)
# Returns: 0 on success, 1 on failure
state_mark_applied() {
    local component="$1"
    local fix_name="$2"
    local metadata="${3:-}"
    
    if [[ -z "$component" ]] || [[ -z "$fix_name" ]]; then
        echo "ERROR: Component and fix_name required"
        return 1
    fi
    
    # Ensure state is initialized
    if ! state_is_initialized; then
        state_init || return 1
    fi
    
    local state_file
    state_file=$(state_get_component_file "$component")
    
    local timestamp
    timestamp=$(date +%Y-%m-%d_%H:%M:%S)
    
    # Create or update state file
    # Format: fix_name|timestamp|metadata
    local entry="${fix_name}|${timestamp}|${metadata}"
    
    # Write atomically via mktemp + mv
    local tmp_file
    tmp_file=$(mktemp "${state_file}.XXXXXX")
    if [[ -f "$state_file" ]]; then
        grep -v "^${fix_name}|" "$state_file" > "$tmp_file" 2>/dev/null || true
    fi
    echo "$entry" >> "$tmp_file"
    mv "$tmp_file" "$state_file"
    
    return 0
}

# Check if a fix is applied for a component
# Args: $1 = component, $2 = fix_name
# Returns: 0 if applied, 1 if not applied
state_is_applied() {
    local component="$1"
    local fix_name="$2"
    
    if [[ -z "$component" ]] || [[ -z "$fix_name" ]]; then
        return 1
    fi
    
    if ! state_is_initialized; then
        return 1
    fi
    
    local state_file
    state_file=$(state_get_component_file "$component")
    
    if [[ ! -f "$state_file" ]]; then
        return 1
    fi
    
    grep -q "^${fix_name}|" "$state_file" 2>/dev/null
}

# Remove a fix from state (mark as not applied)
# Args: $1 = component, $2 = fix_name
# Returns: 0 on success, 1 on failure
state_mark_removed() {
    local component="$1"
    local fix_name="$2"
    
    if [[ -z "$component" ]] || [[ -z "$fix_name" ]]; then
        echo "ERROR: Component and fix_name required"
        return 1
    fi
    
    if ! state_is_initialized; then
        return 0  # Nothing to remove
    fi
    
    local state_file
    state_file=$(state_get_component_file "$component")
    
    if [[ ! -f "$state_file" ]]; then
        return 0  # Nothing to remove
    fi
    
    # Remove entry atomically via mktemp + mv
    local tmp_file
    tmp_file=$(mktemp "${state_file}.XXXXXX")
    grep -v "^${fix_name}|" "$state_file" > "$tmp_file" 2>/dev/null || true
    mv "$tmp_file" "$state_file"
    
    return 0
}

# Get metadata for a fix
# Args: $1 = component, $2 = fix_name
# Returns: Metadata string or empty if not found
state_get_metadata() {
    local component="$1"
    local fix_name="$2"
    
    if ! state_is_applied "$component" "$fix_name"; then
        echo ""
        return 1
    fi
    
    local state_file
    state_file=$(state_get_component_file "$component")
    
    # Extract metadata (third field)
    grep "^${fix_name}|" "$state_file" 2>/dev/null | cut -d'|' -f3
}

# Get timestamp when fix was applied
# Args: $1 = component, $2 = fix_name
# Returns: Timestamp string or empty if not found
state_get_timestamp() {
    local component="$1"
    local fix_name="$2"
    
    if ! state_is_applied "$component" "$fix_name"; then
        echo ""
        return 1
    fi
    
    local state_file
    state_file=$(state_get_component_file "$component")
    
    # Extract timestamp (second field)
    grep "^${fix_name}|" "$state_file" 2>/dev/null | cut -d'|' -f2
}

# List all fixes for a component
# Args: $1 = component
# Output: List of fix names (one per line)
state_list_fixes() {
    local component="$1"
    
    if [[ -z "$component" ]]; then
        return 1
    fi
    
    local state_file
    state_file=$(state_get_component_file "$component")
    
    if [[ ! -f "$state_file" ]]; then
        return 0
    fi
    
    # Extract fix names (first field)
    cut -d'|' -f1 "$state_file"
}

# --- Component Status ---

# Get complete state for a component
# Args: $1 = component
# Output: JSON-like state information
state_get_component_state() {
    local component="$1"
    
    if [[ -z "$component" ]]; then
        echo '{"error": "component required"}'
        return 1
    fi
    
    local state_file
    state_file=$(state_get_component_file "$component")
    
    if [[ ! -f "$state_file" ]]; then
        echo "{\"component\": \"$component\", \"fixes\": []}"
        return 0
    fi
    
    echo "{\"component\": \"$component\", \"fixes\": ["
    
    local first=true
    while IFS='|' read -r fix_name timestamp metadata; do
        if [[ "$first" == true ]]; then
            first=false
        else
            echo ","
        fi
        echo "    {\"name\": \"$fix_name\", \"timestamp\": \"$timestamp\", \"metadata\": \"$metadata\"}"
    done < "$state_file"
    
    echo "  ]}"
}

# Get complete system state
# Output: JSON-like state information for all components
state_get_system_state() {
    if ! state_is_initialized; then
        echo '{"error": "state not initialized"}'
        return 1
    fi
    
    echo "{"
    echo "  \"version\": \"$STATE_VERSION\","
    echo "  \"components\": {"
    
    local first=true
    for state_file in "$STATE_STORE_DIR"/*.state; do
        if [[ ! -f "$state_file" ]]; then
            continue
        fi
        
        local component
        component=$(basename "$state_file" .state)
        
        if [[ "$first" == true ]]; then
            first=false
        else
            echo ","
        fi
        
        echo "    \"$component\": $(state_get_component_state "$component")"
    done
    
    echo "  }"
    echo "}"
}

# --- Config File Backup ---

# Backup a configuration file before modifying
# Args: $1 = file path
# Returns: 0 on success, 1 on failure
# Output: Backup file path
state_backup_file() {
    local file_path="$1"
    
    if [[ ! -f "$file_path" ]]; then
        echo "WARNING: File not found: $file_path"
        return 1
    fi
    
    # Ensure backup directory exists
    if [[ ! -d "$BACKUP_DIR" ]]; then
        mkdir -p "$BACKUP_DIR" 2>/dev/null || {
            echo "ERROR: Failed to create backup directory"
            return 1
        }
    fi
    
    # Create timestamped backup
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    
    local filename
    filename=$(basename "$file_path")
    
    local backup_path="${BACKUP_DIR}/${filename}.${timestamp}.bak"
    
    if cp "$file_path" "$backup_path" 2>/dev/null; then
        echo "$backup_path"
        return 0
    else
        echo "ERROR: Failed to backup file: $file_path"
        return 1
    fi
}

# Restore a configuration file from backup
# Args: $1 = backup file path
# Returns: 0 on success, 1 on failure
state_restore_file() {
    local backup_path="$1"
    
    if [[ ! -f "$backup_path" ]]; then
        echo "ERROR: Backup file not found: $backup_path"
        return 1
    fi
    
    # Extract original filename (remove timestamp and .bak)
    local filename
    filename=$(basename "$backup_path" | sed 's/\.[0-9_]*\.bak$//')
    
    # Determine original path (assume /etc/ for modprobe.d, systemd, etc.)
    # This is simplified - real implementation would store original path
    local original_path="/etc/${filename}"
    
    if cp "$backup_path" "$original_path" 2>/dev/null; then
        echo "Restored: $original_path from $backup_path"
        return 0
    else
        echo "ERROR: Failed to restore file from: $backup_path"
        return 1
    fi
}

# List all backups
# Output: List of backup files with timestamps
state_list_backups() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo "No backups directory found"
        return 0
    fi
    
    find "$BACKUP_DIR" -name "*.bak" -type f 2>/dev/null | sort
}

# --- Logging ---

# Log a message to the state log
# Args: $1 = log level (INFO, WARNING, ERROR), $2 = message
state_log() {
    local level="$1"
    local message="$2"
    
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR" 2>/dev/null || return 1
    fi
    
    local log_file="$LOG_DIR/state.log"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" >> "$log_file"
}

# Get recent log entries
# Args: $1 = number of lines (default: 50)
# Output: Recent log entries
state_get_log() {
    local lines="${1:-50}"
    local log_file="$LOG_DIR/state.log"
    
    if [[ ! -f "$log_file" ]]; then
        echo "No log file found"
        return 0
    fi
    
    tail -n "$lines" "$log_file"
}

# --- Status Display ---

# Print comprehensive state status
# Output: Formatted status information
state_print_status() {
    echo "GZ302 State Manager Status"
    echo "=========================="
    echo
    
    if ! state_is_initialized; then
        echo "Status: NOT INITIALIZED"
        echo "Run: state_init"
        return 1
    fi
    
    echo "Status: Initialized"
    echo "State Directory: $STATE_STORE_DIR"
    echo "Backup Directory: $BACKUP_DIR"
    echo "Log Directory: $LOG_DIR"
    echo "Version: $STATE_VERSION"
    echo
    
    echo "Component States:"
    for state_file in "$STATE_STORE_DIR"/*.state; do
        if [[ ! -f "$state_file" ]]; then
            echo "  No components configured yet"
            break
        fi
        
        local component
        component=$(basename "$state_file" .state)
        
        echo "  Component: $component"
        
        while IFS='|' read -r fix_name timestamp metadata; do
            echo "    ✓ $fix_name (applied: $timestamp)"
            if [[ -n "$metadata" ]]; then
                echo "      Metadata: $metadata"
            fi
        done < "$state_file"
        
        echo
    done
    
    echo "Recent Backups:"
    local backup_count
    backup_count=$(state_list_backups | wc -l)
    echo "  Total: $backup_count"
    
    if [[ $backup_count -gt 0 ]]; then
        echo "  Latest 5:"
        state_list_backups | tail -5 | while read -r backup; do
            echo "    $(basename "$backup")"
        done
    fi
    
    echo
    echo "Recent Log Entries:"
    state_get_log 10
}

# --- Cleanup ---

# Clear all state (use with caution)
# Returns: 0 on success, 1 on failure
state_clear_all() {
    echo "WARNING: This will clear all state tracking"
    echo "Backups and logs will be preserved"
    
    if [[ -d "$STATE_STORE_DIR" ]]; then
        rm -f "$STATE_STORE_DIR"/*.state 2>/dev/null || {
            echo "ERROR: Failed to clear state"
            return 1
        }
        echo "All state cleared"
    fi
    
    return 0
}

# Clear state for specific component
# Args: $1 = component
# Returns: 0 on success
state_clear_component() {
    local component="$1"
    
    if [[ -z "$component" ]]; then
        echo "ERROR: Component required"
        return 1
    fi
    
    local state_file
    state_file=$(state_get_component_file "$component")
    
    if [[ -f "$state_file" ]]; then
        rm -f "$state_file"
        echo "State cleared for component: $component"
    fi
    
    return 0
}

# --- Library Information ---

state_lib_version() {
    echo "3.0.0"
}

state_lib_help() {
    cat <<'HELP'
GZ302 State Manager Library v3.0.0

Initialization:
  state_init                    - Initialize state management
  state_is_initialized          - Check if initialized

Component State:
  state_mark_applied <component> <fix> [metadata] - Mark fix as applied
  state_is_applied <component> <fix>  - Check if fix is applied
  state_mark_removed <component> <fix> - Mark fix as removed
  state_get_metadata <component> <fix> - Get fix metadata
  state_get_timestamp <component> <fix> - Get application timestamp
  state_list_fixes <component>  - List all fixes for component

Component Status:
  state_get_component_state <component> - Get component state (JSON)
  state_get_system_state        - Get complete system state (JSON)

File Backup:
  state_backup_file <path>      - Backup file before modification
  state_restore_file <backup>   - Restore file from backup
  state_list_backups            - List all backup files

Logging:
  state_log <level> <message>   - Log a message
  state_get_log [lines]         - Get recent log entries

Status Display:
  state_print_status            - Print comprehensive status

Cleanup:
  state_clear_all               - Clear all state (caution!)
  state_clear_component <component> - Clear component state

Library Information:
  state_lib_version             - Get library version
  state_lib_help                - Show this help

Example Usage:
  # Initialize
  source strix-halo-lib/state-manager.sh
  state_init
  
  # Mark fix as applied
  state_mark_applied "wifi" "aspm_workaround" "kernel_6.16"
  
  # Check if applied
  if state_is_applied "wifi" "aspm_workaround"; then
      echo "ASPM workaround already applied"
  fi
  
  # Backup file before modification
  backup=$(state_backup_file "/etc/modprobe.d/mt7925.conf")
  
  # Log activity
  state_log "INFO" "Applied WiFi ASPM workaround"
  
  # View status
  state_print_status
  
  # Get JSON state
  state_get_system_state | jq .

State Storage:
  State files: /var/lib/gz302/state/
  Backups: /var/backups/gz302/
  Logs: /var/log/gz302/

Design Principles:
  - Persistent state tracking across reboots
  - Automatic backup before modifications
  - Comprehensive logging
  - JSON output for programmatic access
  - Human-readable status display
HELP
}
