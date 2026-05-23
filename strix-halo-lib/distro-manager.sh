#!/bin/bash
# shellcheck disable=SC2034,SC2059
set -euo pipefail

# ==============================================================================
# GZ302 Distribution Manager Library
# Version: 6.8.0
#
# This library provides distribution-specific setup orchestration for the GZ302.
# It coordinates hardware fixes across all subsystem libraries and manages
# per-distro package installation and configuration.
#
# Library-First Design:
# - Orchestrator functions (coordinate subsystem libraries)
# - Per-distro setup functions (package installation, system config)
# - Distribution-specific optimization information
#
# Supported Distributions:
# - Arch Linux (including CachyOS, EndeavourOS, Manjaro)
# - Debian / Ubuntu
# - Fedora
# - OpenSUSE
# ==============================================================================

# --- Hardware Fixes (Orchestrator) ---
distro_apply_hardware_fixes() {
    info "Applying GZ302 hardware fixes using modular libraries..."
    
    # Use kernel-compat if available, otherwise manual check
    local kver
    if declare -f kernel_get_version_num >/dev/null; then
        kver=$(kernel_get_version_num)
    else
        kver=0
    fi
    
    # 1. WiFi Configuration
    info "Configuring WiFi (MediaTek MT7925)..."
    if declare -f wifi_detect_hardware >/dev/null && wifi_detect_hardware >/dev/null 2>&1; then
        wifi_apply_configuration || warning "WiFi configuration reported issues"
    else
        info "WiFi hardware not detected or library not loaded, skipping."
    fi

    # 2. GPU Configuration
    info "Configuring GPU (AMD Radeon 8060S)..."
    if declare -f gpu_detect_hardware >/dev/null && gpu_detect_hardware >/dev/null 2>&1; then
        gpu_apply_configuration || warning "GPU configuration reported issues"
    else
        info "GPU hardware not detected or library not loaded, skipping."
    fi

    # 3. Input Configuration
    info "Configuring Input Devices..."
    if declare -f input_detect_hid_devices >/dev/null && input_detect_hid_devices >/dev/null 2>&1; then
        input_apply_configuration "$kver" || warning "Input configuration reported issues"
    else
         info "Input devices not detected or library not loaded, skipping."
    fi

    # 4. RGB Configuration
    info "Configuring RGB Devices..."
    if declare -f rgb_install_udev_rules >/dev/null; then
        if rgb_install_udev_rules; then
            success "RGB udev rules installed"
        else
            warning "Failed to install RGB udev rules"
        fi
    fi

    # 5. Keyboard Backlight Restore
    if declare -f rgb_configure_backlight_restore >/dev/null; then
        rgb_configure_backlight_restore
    fi

    # 6. Battery Limit (Optional/Fallback)
    if declare -f power_setup_battery_limit_service >/dev/null; then
        power_setup_battery_limit_service
    fi

    # 7. AMD P-State kernel parameter
    info "Configuring AMD P-State driver..."
    distro_configure_amd_pstate

    success "Hardware fixes applied via libraries"
}

# Configure AMD P-State kernel parameter in the bootloader (idempotent)
# Supports GRUB, systemd-boot, rEFInd, and Limine. Updates all detected
# bootloaders so that whichever is currently active picks up the parameter.
distro_configure_amd_pstate() {
    local param="amd_pstate=guided"
    local found_any=false

    # --- GRUB ---
    if [[ -f /etc/default/grub ]]; then
        found_any=true
        if grep -q "$param" /etc/default/grub 2>/dev/null; then
            info "amd_pstate=guided already present in GRUB config"
        else
            info "Adding amd_pstate=guided to GRUB configuration..."
            local grub_backup
            grub_backup="/etc/default/grub.gz302.bak.$(date +%Y%m%d%H%M%S)"
            cp /etc/default/grub "$grub_backup"
            # Append to GRUB_CMDLINE_LINUX_DEFAULT, else GRUB_CMDLINE_LINUX, else create it
            if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub; then
                sed -i 's/^\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\)"/\1 amd_pstate=guided"/' /etc/default/grub
            elif grep -q '^GRUB_CMDLINE_LINUX=' /etc/default/grub; then
                sed -i 's/^\(GRUB_CMDLINE_LINUX="[^"]*\)"/\1 amd_pstate=guided"/' /etc/default/grub
            else
                echo 'GRUB_CMDLINE_LINUX="amd_pstate=guided"' >> /etc/default/grub
            fi
            # Regenerate GRUB config (handle Fedora's grub2 path as well)
            if command -v grub-mkconfig >/dev/null 2>&1; then
                grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true
            elif command -v grub2-mkconfig >/dev/null 2>&1; then
                grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null || \
                grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg 2>/dev/null || true
            fi
            success "GRUB updated: amd_pstate=guided"
        fi
    fi

    # --- systemd-boot loader entries ---
    local loader_dir="/boot/loader/entries"
    if [[ -d "$loader_dir" ]]; then
        found_any=true
        local sd_updated=0
        local entry
        for entry in "$loader_dir"/*.conf; do
            [[ -f "$entry" ]] || continue
            if grep -q "^options" "$entry" && ! grep -q "$param" "$entry"; then
                local entry_backup
                entry_backup="${entry}.gz302.bak.$(date +%Y%m%d%H%M%S)"
                cp "$entry" "$entry_backup"
                sed -i "s/^\(options .*\)$/\1 amd_pstate=guided/" "$entry"
                sd_updated=1
            fi
        done
        if [[ $sd_updated -eq 1 ]]; then
            success "systemd-boot entries updated: amd_pstate=guided"
        else
            info "amd_pstate=guided already present in systemd-boot entries"
        fi
    fi

    # --- rEFInd ---
    # Per-kernel: /boot/refind_linux.conf — quoted pairs: "label"  "kernel params"
    # Global options: refind.conf 'options' lines (fallback for manual configs)
    if [[ -f /boot/refind_linux.conf ]]; then
        found_any=true
        if grep -q "$param" /boot/refind_linux.conf 2>/dev/null; then
            info "amd_pstate=guided already present in refind_linux.conf"
        else
            local refind_kl_backup
            refind_kl_backup="/boot/refind_linux.conf.gz302.bak.$(date +%Y%m%d%H%M%S)"
            cp /boot/refind_linux.conf "$refind_kl_backup"
            # Each line: "label"  "params ..."  — append to the last quoted string
            sed -i -E "s|\"([^\"]+)\"\s*$|\"\\1 ${param}\"|" /boot/refind_linux.conf
            success "rEFInd per-kernel options updated: amd_pstate=guided"
        fi
    fi
    local refind_conf
    for refind_conf in /boot/EFI/refind/refind.conf /boot/efi/EFI/refind/refind.conf \
                       /efi/EFI/refind/refind.conf; do
        [[ -f "$refind_conf" ]] || continue
        found_any=true
        if grep -q "$param" "$refind_conf" 2>/dev/null; then
            info "amd_pstate=guided already present in $(basename "$refind_conf")"
            continue
        fi
        local refind_backup
        refind_backup="${refind_conf}.gz302.bak.$(date +%Y%m%d%H%M%S)"
        cp "$refind_conf" "$refind_backup"
        # Append to every 'options' line (global or stanza-level)
        sed -i "s|^\(options .*\)$|\1 ${param}|" "$refind_conf"
        success "rEFInd config updated: amd_pstate=guided"
    done

    # --- Limine ---
    # Limine commonly uses /etc/default/limine plus limine-update/limine-mkinitcpio,
    # but older/manual installs may still keep kernel parameters in limine.conf.
    local limine_updated=false
    if [[ -f /etc/default/limine ]]; then
        found_any=true
        if grep -q "$param" /etc/default/limine 2>/dev/null; then
            info "amd_pstate=guided already present in /etc/default/limine"
        elif declare -f ensure_limine_kernel_param >/dev/null 2>&1 && ensure_limine_kernel_param "$param"; then
            success "Limine default configuration updated: amd_pstate=guided"
            limine_updated=true
        else
            warning "Failed to update /etc/default/limine for amd_pstate=guided"
        fi
    fi

    # Limine v5+ uses /etc/limine/limine.conf; v4 uses /boot/limine.cfg.
    # Both formats are handled: "cmdline:" (v5 TOML-style) and "CMDLINE=" (v4 uppercase).
    local limine_cfg
    for limine_cfg in /etc/limine/limine.conf /boot/limine/limine.conf /boot/limine.cfg /boot/limine.conf; do
        [[ -f "$limine_cfg" ]] || continue
        found_any=true
        if grep -q "$param" "$limine_cfg" 2>/dev/null; then
            info "amd_pstate=guided already present in $(basename "$limine_cfg")"
            continue
        fi
        local limine_backup
        limine_backup="${limine_cfg}.gz302.bak.$(date +%Y%m%d%H%M%S)"
        cp "$limine_cfg" "$limine_backup"
        # v5 TOML-style: "    cmdline: ..." or "cmdline: ..."
        if grep -qE '^\s*cmdline\s*:' "$limine_cfg"; then
            sed -i -E "s|^(\s*cmdline\s*:.*)$|\1 ${param}|" "$limine_cfg"
        # v4 uppercase: "CMDLINE=..."
        elif grep -q '^CMDLINE=' "$limine_cfg"; then
            sed -i "s|^\(CMDLINE=.*\)$|\1 ${param}|" "$limine_cfg"
        else
            warning "Limine config ${limine_cfg}: no CMDLINE/cmdline entry found — add '${param}' manually"
            continue
        fi
        success "Limine configuration updated: amd_pstate=guided"
        limine_updated=true
    done

    if [[ "$limine_updated" == "true" ]] && declare -f limine_regenerate_entries >/dev/null 2>&1; then
        info "Regenerating Limine entries..."
        if limine_regenerate_entries; then
            success "Limine entries regenerated"
        fi
    fi

    if [[ "$found_any" == false ]]; then
        warning "Unknown bootloader: cannot add amd_pstate=guided automatically"
        info "Manually add 'amd_pstate=guided' to your bootloader kernel parameters"
    fi
}

# --- Distribution-Specific Optimizations Info ---
# Provides information about distribution-specific optimizations for Strix Halo
distro_provide_optimization_info() {
    local distro="$1"

    # Detect specific distribution ID for CachyOS
    # Read ID safely without sourcing (avoids code injection from /etc/os-release)
    local distro_id=""
    if [[ -f /etc/os-release ]]; then
        distro_id=$(grep -oP '(?<=^ID=)[^\n"]+' /etc/os-release 2>/dev/null | tr -d '"' || true)
    fi
    
    # CachyOS-specific optimizations
    if [[ "$distro_id" == "cachyos" ]]; then
        info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        info "CachyOS Detected - Performance Optimizations Available"
        info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        info ""
        info "CachyOS provides excellent out-of-the-box performance for Strix Halo:"
        info ""
        info "✓ Optimized kernel with BORE scheduler (better gaming/interactive performance)"
        info "✓ Packages compiled with x86-64-v3/v4 optimizations (5-20% performance boost)"
        info "✓ LTO/PGO optimizations for better binary performance"
        info "✓ AMD P-State driver enhancements built-in"
        info ""
        info "Additional Optimizations Available:"
        info "1. Consider using 'amd_pstate=active' for better battery life:"
        info "   - Edit /etc/default/grub and change amd_pstate=guided to amd_pstate=active"
        info "   - Run: grub-mkconfig -o /boot/grub/grub.cfg"
        info "   - Active mode lets hardware autonomously choose optimal frequencies"
        info ""
        info "2. Use CachyOS kernel manager to select optimized kernel:"
        info "   - linux-cachyos-bore (recommended for gaming/desktop)"
        info "   - linux-cachyos-rt-bore (for real-time workloads)"
        info "   - linux-cachyos-lts (for stability)"
        info ""
        info "3. Performance tuning via /sys/devices/system/cpu/amd_pstate/:"
        info "   - Set performance governor: for cpu in /sys/devices/system/cpu/cpu[0-9]*; do"
        info "     echo 'performance' > \$cpu/cpufreq/scaling_governor 2>/dev/null; done"
        info "   - Or use 'powersave' governor with energy_performance_preference"
        info ""
        info "Reference: https://wiki.cachyos.org/configuration/general_system_tweaks/"
        info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        info ""
    fi
    
    # General AMD P-State information for all Arch-based distributions
    if [[ "$distro" == "arch" ]] && [[ "$distro_id" != "cachyos" ]]; then
        info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        info "Arch Linux Performance Tuning for Strix Halo"
        info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        info ""
        info "AMD P-State Mode: Currently using 'guided' (good for consistent performance)"
        info ""
        info "Alternative: Switch to 'active' mode for better battery life:"
        info "  1. Edit /etc/default/grub"
        info "  2. Change: amd_pstate=guided → amd_pstate=active"
        info "  3. Run: grub-mkconfig -o /boot/grub/grub.cfg"
        info "  4. Reboot"
        info ""
        info "Active mode pros: Better power efficiency, hardware makes smart decisions"
        info "Guided mode pros: More predictable performance, better for gaming/heavy loads"
        info ""
        info "Performance tip: Install CachyOS repositories for optimized packages:"
        info "  - 5-20% performance improvement from x86-64-v3/v4 optimized builds"
        info "  - https://wiki.cachyos.org/features/optimized_repos/"
        info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        info ""
    fi
    
    # Information for other distributions
    if [[ "$distro" != "arch" ]]; then
        info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        info "AMD P-State Driver Information"
        info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        info ""
        info "Current mode: 'guided' (balanced performance and power efficiency)"
        info ""
        info "For better battery life, consider switching to 'active' mode:"
        info "  - Hardware autonomously manages frequencies based on workload"
        info "  - Better power efficiency with good performance"
        info ""
        info "To switch modes, edit your bootloader configuration and change:"
        info "  amd_pstate=guided → amd_pstate=active"
        info ""
        info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        info ""
    fi
}

# --- Library Info ---
distro_lib_version() {
    echo "6.0.0"
}

distro_lib_help() {
    echo "GZ302 Distribution Manager Library"
    echo ""
    echo "Functions:"
    echo "  distro_apply_hardware_fixes     - Orchestrate all hardware fix libraries"
    echo "  distro_configure_amd_pstate     - Write amd_pstate=guided to all detected bootloader configs"
    echo "  distro_provide_optimization_info - Show distro-specific tuning tips"
    echo "  distro_lib_version              - Show library version"
    echo "  distro_lib_help                 - Show this help"
}
