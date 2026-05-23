#!/bin/bash
# shellcheck disable=SC2034,SC2059
set -euo pipefail

# ==============================================================================
# GZ302 Display Fix Library
# Version: 6.8.0
#
# This library provides display-specific fixes for OLED panels on GZ302.
# Focuses on all eDP power-saving features that can cause display artifacts.
#
# Key Issues Addressed:
# - PSR/PSR-SU causes scrolling artifacts on OLED panels
# - Panel Replay (PR) causes flicker on OLED eDP panels
# - Scatter-gather display causes flicker under memory pressure on APUs
#
# Fixes Applied:
# - amdgpu.dcdebugmask=0x600 for all supported kernels:
#   DC_DISABLE_PSR_SU (0x200) + DC_DISABLE_REPLAY (0x400)
#   (The broader 0xe12 mask was found to break s2idle on 6.x kernels)
# - amdgpu.sg_display=0: Scatter-gather display disabled (APU flicker)
# - amdgpu.abmlevel=0:   ABM disabled for OLED panels (DPCD capability)
#
# Usage:
#   source strix-halo-lib/display-fix.sh
#   display_fix_psr_su_enabled
#   display_apply_psr_su_fix
# ==============================================================================

readonly DISPLAY_MANAGED_DCDEBUGMASK_BITS=0xe12

display_get_target_dcdebugmask_value() {
    local param

    if declare -f kernel_get_psr_su_parameter >/dev/null 2>&1; then
        param=$(kernel_get_psr_su_parameter)
        echo "${param#amdgpu.dcdebugmask=}"
        return 0
    fi

    # Use 0x600 (DC_DISABLE_PSR_SU | DC_DISABLE_REPLAY) for all supported
    # kernels.  The broader 0xe12 mask breaks s2idle on 6.x kernels.
    echo "0x600"
}

display_get_target_dcdebugmask_param() {
    echo "amdgpu.dcdebugmask=$(display_get_target_dcdebugmask_value)"
}

display_sync_dcdebugmask_file() {
    local file="$1"
    local current
    local target
    local normalized

    current=$(grep -oE 'amdgpu\.dcdebugmask=(0x[0-9A-Fa-f]+|[0-9]+)' "$file" 2>/dev/null | head -1 || true)
    if [[ -z "$current" ]]; then
        return 1
    fi

    current="${current#amdgpu.dcdebugmask=}"
    target=$(display_get_target_dcdebugmask_value)
    printf -v normalized "0x%x" $(((current & ~DISPLAY_MANAGED_DCDEBUGMASK_BITS) | target))
    sed -i -E "s/amdgpu\.dcdebugmask=(0x[0-9A-Fa-f]+|[0-9]+)/amdgpu.dcdebugmask=${normalized}/g" "$file"
    return 0
}

display_sync_runtime_debug_mask() {
    local file="$1"
    local current="0x0"
    local target
    local normalized

    if [[ -r "$file" ]]; then
        current=$(cat "$file" 2>/dev/null || echo "0x0")
    fi

    target=$(display_get_target_dcdebugmask_value)
    printf -v normalized "0x%x" $(((current & ~DISPLAY_MANAGED_DCDEBUGMASK_BITS) | target))
    echo "$normalized" > "$file" 2>/dev/null || true
}

display_has_target_dcdebugmask() {
    local file="$1"
    local token
    local value
    local target

    target=$(display_get_target_dcdebugmask_value)

    while read -r token; do
        value="${token#amdgpu.dcdebugmask=}"
        if (( (value & DISPLAY_MANAGED_DCDEBUGMASK_BITS) == target )); then
            return 0
        fi
    done < <(grep -oE 'amdgpu\.dcdebugmask=(0x[0-9A-Fa-f]+|[0-9]+)' "$file" 2>/dev/null || true)

    return 1
}

display_ensure_limine_default_param() {
    local target_param="$1"
    local limine_conf="/etc/default/limine"

    if [[ ! -f "$limine_conf" ]]; then
        return 2
    fi

    if grep -q -- "$target_param" "$limine_conf" 2>/dev/null; then
        return 1
    fi

    if grep -qE '^KERNEL_CMDLINE\[default\]\+?="[^"]*"' "$limine_conf"; then
        sed -i -E "s/^(KERNEL_CMDLINE\[default\](\+)?=\"[^\"]*)\"/\1 ${target_param}\"/" "$limine_conf"
    elif grep -qE '^KERNEL_CMDLINE\[default\]' "$limine_conf"; then
        echo "KERNEL_CMDLINE[default]+=\"${target_param}\"" >> "$limine_conf"
    else
        echo "KERNEL_CMDLINE[default]+=\"${target_param}\"" >> "$limine_conf"
    fi

    return 0
}

# --- PSR-SU Detection Functions ---

# Check if PSR-SU is currently enabled
# Returns: 0 if enabled, 1 if disabled
display_psr_su_enabled() {
    # Check if dcdebugmask matches the kernel-appropriate display fix bits.
    if [[ -f /etc/default/grub ]]; then
        if display_has_target_dcdebugmask /etc/default/grub; then
            return 1  # display fixes disabled
        fi
    fi
    
    # Check kernel cmdline (systemd-boot)
    if [[ -f /etc/kernel/cmdline ]]; then
        if display_has_target_dcdebugmask /etc/kernel/cmdline; then
            return 1  # display fixes disabled
        fi
    fi

    if [[ -f /etc/default/limine ]]; then
        if display_has_target_dcdebugmask /etc/default/limine; then
            return 1  # PSR-SU disabled
        fi
    fi

    # Check Limine bootloader configs
    local limine_cfg
    for limine_cfg in /etc/limine/limine.conf /boot/limine/limine.conf /boot/limine.cfg /boot/limine.conf; do
        if [[ -f "$limine_cfg" ]]; then
            if display_has_target_dcdebugmask "$limine_cfg"; then
                return 1  # PSR-SU disabled
            fi
        fi
    done

    # Check rEFInd per-kernel and global configs
    if [[ -f /boot/refind_linux.conf ]]; then
        if display_has_target_dcdebugmask /boot/refind_linux.conf; then
            return 1  # PSR-SU disabled
        fi
    fi
    local refind_cfg
    for refind_cfg in /boot/EFI/refind/refind.conf /boot/efi/EFI/refind/refind.conf \
                      /efi/EFI/refind/refind.conf; do
        if [[ -f "$refind_cfg" ]]; then
            if display_has_target_dcdebugmask "$refind_cfg"; then
                return 1  # PSR-SU disabled
            fi
        fi
    done

    # PSR-SU is enabled by default (no PSR-disable dcdebugmask bits)
    return 0
}

# Check if PSR-SU fix has been applied
# Returns: 0 if fix applied, 1 if not applied
display_psr_su_fix_applied() {
    if display_psr_su_enabled; then
        return 1  # PSR enabled, fix not applied
    else
        return 0  # PSR disabled, fix applied
    fi
}

# --- PSR-SU Fix Application ---

# Append/merge parameter into /etc/kernel/cmdline as a single line
display_ensure_cmdline_param() {
    local cmdline_file="$1"
    local param="$2"
    local current

    current=$(tr '\n' ' ' < "$cmdline_file" 2>/dev/null | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//' || true)
    if [[ "$current" == *"$param"* ]]; then
        return 1
    fi

    if [[ -n "$current" ]]; then
        printf '%s %s\n' "$current" "$param" > "$cmdline_file"
    else
        printf '%s\n' "$param" > "$cmdline_file"
    fi

    return 0
}

display_regenerate_boot_artifacts() {
    # On Arch/CachyOS with systemd-boot + UKI, cmdline changes require a rebuild.
    if command -v mkinitcpio >/dev/null 2>&1; then
        if [[ "${GZ302_MKINITCPIO_DONE:-false}" == "true" ]]; then
            return 0
        fi

        if mkinitcpio -P 2>/dev/null; then
            export GZ302_MKINITCPIO_DONE=true
            return 0
        fi

        warning "Failed to regenerate initramfs with mkinitcpio - manual update may be required"
        return 1
    fi

    if command -v dracut >/dev/null 2>&1; then
        if dracut --regenerate-all -f 2>/dev/null; then
            return 0
        fi

        warning "Failed to regenerate initramfs with dracut - manual update may be required"
        return 1
    fi

    warning "No initramfs regeneration tool found - manual update may be required"
    return 1
}

display_regenerate_limine_artifacts() {
    if declare -f limine_regenerate_entries >/dev/null 2>&1; then
        limine_regenerate_entries
        return $?
    fi

    if command -v limine-update >/dev/null 2>&1; then
        if limine-update 2>/dev/null; then
            return 0
        fi

        warning "limine-update failed - manual update may be required"
        return 1
    fi

    if command -v limine-mkinitcpio >/dev/null 2>&1; then
        if limine-mkinitcpio 2>/dev/null; then
            return 0
        fi

        warning "limine-mkinitcpio failed - manual update may be required"
        return 1
    fi

    warning "No Limine update command found - manual update may be required"
    return 1
}

# Apply PSR-SU disable fix (idempotent)
# Returns: 0 on success
display_apply_psr_su_fix() {
    local target_param
    target_param=$(display_get_target_dcdebugmask_param)

    info "Applying PSR-SU disable fix for OLED panel scrolling artifacts..."
    
    # Add to GRUB if present
    if [[ -f /etc/default/grub ]]; then
        if grep -q "amdgpu.dcdebugmask=" /etc/default/grub 2>/dev/null; then
            if display_has_target_dcdebugmask /etc/default/grub; then
                info "GRUB already has the kernel-appropriate display fix mask"
            else
                info "Normalizing display fix bits in GRUB..."
                display_sync_dcdebugmask_file /etc/default/grub || true
            fi
        else
            info "Adding ${target_param} to GRUB..."
            if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub; then
                sed -i "s/^\(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*\)\"/\1 ${target_param}\"/" /etc/default/grub 2>/dev/null || true
            elif grep -q '^GRUB_CMDLINE_LINUX=' /etc/default/grub; then
                sed -i "s/^\(GRUB_CMDLINE_LINUX=\"[^\"]*\)\"/\1 ${target_param}\"/" /etc/default/grub 2>/dev/null || true
            else
                echo "GRUB_CMDLINE_LINUX=\"${target_param}\"" >> /etc/default/grub
            fi
        fi

        # Regenerate GRUB config
        if command -v grub-mkconfig >/dev/null 2>&1; then
            info "Regenerating GRUB configuration..."
            if grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null; then
                success "GRUB configuration updated"
            else
                warning "Failed to regenerate GRUB - manual update may be required"
            fi
        else
            warning "grub-mkconfig not found - manual update required"
        fi
    fi
    
    # Add to systemd-boot if present
    if [[ -f /etc/kernel/cmdline ]]; then
        local cmdline_updated=false

        if grep -q "amdgpu.dcdebugmask=" /etc/kernel/cmdline 2>/dev/null; then
            if display_has_target_dcdebugmask /etc/kernel/cmdline; then
                info "systemd-boot cmdline already has the kernel-appropriate display fix mask"
            else
                info "Normalizing display fix bits in existing systemd-boot dcdebugmask..."
                if display_sync_dcdebugmask_file /etc/kernel/cmdline; then
                    cmdline_updated=true
                fi
            fi
        else
            info "Adding ${target_param} to systemd-boot..."
            if display_ensure_cmdline_param /etc/kernel/cmdline "$target_param"; then
                cmdline_updated=true
            fi
        fi

        if [[ "$cmdline_updated" == "true" ]]; then
            info "Regenerating boot artifacts for updated systemd-boot cmdline..."
            if display_regenerate_boot_artifacts; then
                success "Boot artifacts regenerated"
            fi
        fi

        success "systemd-boot configuration updated"
    fi
    
    # For systemd-boot with loader entries
    if [[ -d /boot/loader/entries ]]; then
        for entry in /boot/loader/entries/*.conf; do
            if [[ -f "$entry" ]]; then
                if grep -q "amdgpu.dcdebugmask=" "$entry" 2>/dev/null; then
                    if ! display_has_target_dcdebugmask "$entry"; then
                        display_sync_dcdebugmask_file "$entry" || true
                    fi
                else
                    info "Updating bootloader entry: $(basename "$entry")"
                    # Add to options line
                    if grep -q "^options" "$entry"; then
                        sed -i "s/\(options.*\)$/\1 ${target_param}/" "$entry"
                    else
                        echo "options ${target_param}" >> "$entry"
                    fi
                fi
            fi
        done
    fi

    # --- Limine ---
    local limine_updated=false
    if [[ -f /etc/default/limine ]]; then
        if grep -q "amdgpu.dcdebugmask=" /etc/default/limine 2>/dev/null; then
            if display_has_target_dcdebugmask /etc/default/limine; then
                info "/etc/default/limine already has the kernel-appropriate display fix mask"
            else
                info "Normalizing display fix bits in /etc/default/limine..."
                if display_sync_dcdebugmask_file /etc/default/limine; then
                    limine_updated=true
                fi
            fi
        else
            info "Adding ${target_param} to /etc/default/limine..."
            if display_ensure_limine_default_param "$target_param"; then
                limine_updated=true
            else
                warning "/etc/default/limine could not be updated automatically - add '${target_param}' manually"
            fi
        fi
    fi

    local limine_cfg
    for limine_cfg in /etc/limine/limine.conf /boot/limine/limine.conf /boot/limine.cfg /boot/limine.conf; do
        [[ -f "$limine_cfg" ]] || continue
        if grep -q "amdgpu.dcdebugmask=" "$limine_cfg" 2>/dev/null; then
            if display_has_target_dcdebugmask "$limine_cfg"; then
                info "$(basename "$limine_cfg") already has the kernel-appropriate display fix mask"
            else
                info "Normalizing display fix bits in Limine config: $(basename "$limine_cfg")"
                if display_sync_dcdebugmask_file "$limine_cfg"; then
                    limine_updated=true
                fi
            fi
        else
            info "Adding ${target_param} to Limine config: $(basename "$limine_cfg")"
            # v5 TOML-style: "    cmdline: ..."
            if grep -qE '^\s*cmdline\s*:' "$limine_cfg"; then
                sed -i -E "s|(^\s*cmdline\s*:.*)$|\1 ${target_param}|" "$limine_cfg"
            # v4 uppercase: "CMDLINE=..."
            elif grep -q '^CMDLINE=' "$limine_cfg"; then
                sed -i "s|^\(CMDLINE=.*\)$|\1 ${target_param}|" "$limine_cfg"
            else
                warning "Limine config $(basename "$limine_cfg"): no CMDLINE/cmdline entry — add '${target_param}' manually"
            fi
            limine_updated=true
        fi
    done

    if [[ "$limine_updated" == "true" ]]; then
        info "Regenerating Limine entries..."
        if display_regenerate_limine_artifacts; then
            success "Limine entries regenerated"
        fi
    fi

    # --- rEFInd ---
    if [[ -f /boot/refind_linux.conf ]]; then
        if grep -q "amdgpu.dcdebugmask=" /boot/refind_linux.conf 2>/dev/null; then
            if display_has_target_dcdebugmask /boot/refind_linux.conf; then
                info "refind_linux.conf already has the kernel-appropriate display fix mask"
            else
                info "Normalizing display fix bits in refind_linux.conf..."
                display_sync_dcdebugmask_file /boot/refind_linux.conf || true
            fi
        else
            info "Adding ${target_param} to refind_linux.conf..."
            # Each line: "label"  "params ..." — append to the last quoted string
            sed -i -E "s|\"([^\"]+)\"\s*$|\"\\1 ${target_param}\"|" /boot/refind_linux.conf
        fi
    fi
    local refind_cfg
    for refind_cfg in /boot/EFI/refind/refind.conf /boot/efi/EFI/refind/refind.conf \
                      /efi/EFI/refind/refind.conf; do
        [[ -f "$refind_cfg" ]] || continue
        if grep -q "amdgpu.dcdebugmask=" "$refind_cfg" 2>/dev/null; then
            if display_has_target_dcdebugmask "$refind_cfg"; then
                info "$(basename "$refind_cfg") already has the kernel-appropriate display fix mask"
            else
                info "Normalizing display fix bits in $(basename "$refind_cfg")..."
                display_sync_dcdebugmask_file "$refind_cfg" || true
            fi
        else
            info "Adding ${target_param} to $(basename "$refind_cfg")..."
            sed -i "s|^\(options .*\)$|\1 ${target_param}|" "$refind_cfg"
        fi
    done
    
    # Apply runtime fix (if possible)
    if [[ -d /sys/kernel/debug/dri ]]; then
        for dri_dir in /sys/kernel/debug/dri/*/; do
            if [[ -d "$dri_dir" ]]; then
                local debug_mask="${dri_dir}amdgpu_dm_debug_mask"
                if [[ -w "$debug_mask" ]]; then
                    info "Applying runtime PSR-SU disable..."
                    display_sync_runtime_debug_mask "$debug_mask"
                fi
            fi
        done
    fi
    
    success "PSR-SU fix applied successfully"
    info "Reboot required to apply changes permanently"
    
    return 0
}

# --- Verification Functions ---

# Verify PSR-SU fix is working
# Returns: 0 if working, 1 if issues detected
display_verify_psr_su_fix() {
    local status=0
    
    # Check if fix is applied
    if display_psr_su_enabled; then
        echo "  ⚠️  PSR-SU is still enabled - scrolling artifacts may occur"
        status=1
    else
        echo "  ✓ PSR-SU is disabled - scrolling artifacts should be resolved"
    fi
    
    # Check kernel version
    local kver
    kver=$(uname -r | cut -d. -f1,2)
    local major minor
    major=$(echo "$kver" | cut -d. -f1)
    minor=$(echo "$kver" | cut -d. -f2)
    local version_num=$((major * 100 + minor))
    
    if [[ $version_num -ge 612 ]]; then
        echo "  ✓ Kernel $(uname -r | cut -d. -f1,2) — using 0x600 display mask"
    else
        echo "  ⚠️  Kernel < 6.12 - manual PSR-SU disable recommended"
        status=1
    fi
    
    return $status
}

# --- Status Functions ---

# Print PSR-SU status
display_print_psr_su_status() {
    local psr_enabled
    local fix_applied
    
    if display_psr_su_enabled; then
        psr_enabled="enabled"
    else
        psr_enabled="disabled"
    fi
    
    if display_psr_su_fix_applied; then
        fix_applied="applied"
    else
        fix_applied="not applied"
    fi
    
    echo "PSR-SU Status:"
    echo "  PSR-SU Status: $psr_enabled"
    echo "  Fix Applied: $fix_applied"
    echo ""
    
    # Check current runtime status if available
    if [[ -d /sys/kernel/debug/dri ]]; then
        echo "Runtime Status:"
        for dri_dir in /sys/kernel/debug/dri/*/; do
            if [[ -d "$dri_dir" ]]; then
                local debug_mask="${dri_dir}amdgpu_dm_debug_mask"
                if [[ -f "$debug_mask" ]]; then
                    echo "  Debug mask: $(cat "$debug_mask" 2>/dev/null || echo 'N/A')"
                fi
            fi
        done
    fi
    
    echo ""
    echo "Recommended Fix:"
    echo "  $(display_get_target_dcdebugmask_param) (kernel-aware OLED/display stability mask)"
    echo "  amdgpu.sg_display=0 (disables scatter-gather display for APU)"
    echo ""
    echo "To apply fix:"
    echo "  source strix-halo-lib/display-fix.sh"
    echo "  display_apply_psr_su_fix"
    echo "  sudo reboot"
}

# --- Library Information ---

display_fix_lib_version() {
    echo "6.8.0"
}

display_fix_lib_help() {
    cat <<'HELP'
GZ302 Display Fix Library v6.8.0

PSR/Replay/IPS Detection Functions:
  display_psr_su_enabled        - Check if display fix bits are set
  display_psr_su_fix_applied    - Check if fix has been applied

Fix Application Functions:
  display_apply_psr_su_fix      - Apply display fix (idempotent, all bootloaders)

Verification Functions:
  display_verify_psr_su_fix     - Verify fix is working

Status Functions:
  display_print_psr_su_status   - Print current status

Library Information:
  display_fix_lib_version       - Get library version
  display_fix_lib_help          - Show this help

Kernel-aware Display Fix Information:
    All supported kernels -> dcdebugmask=0x600
        DC_DISABLE_PSR_SU  (0x200)  - PSR-SU disable (fixes OLED scrolling artifacts)
        DC_DISABLE_REPLAY  (0x400)  - Panel Replay off (eDP0 flicker)

    Note: The broader 0xe12 mask (which also disables DRAM stutter, PSR, and
    IPS) was previously used on kernel 6.x but was found to break s2idle
    suspend: the side LED keeps cycling and battery drains during sleep.

  Also requires in /etc/modprobe.d/amdgpu.conf:
    options amdgpu sg_display=0   (APU scatter-gather flicker)
    options amdgpu abmlevel=0     (OLED ABM disable)

Example Usage:
  source strix-halo-lib/display-fix.sh

  # Check current status
  display_print_psr_su_status

  # Apply fix
  display_apply_psr_su_fix

  # Verify fix
  display_verify_psr_su_fix
HELP
}
