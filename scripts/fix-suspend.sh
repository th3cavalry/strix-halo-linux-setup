#!/bin/bash
# GZ302 Suspend Fix Installer
# Fixes:
#   - s2idle hang on Strix Halo (Thunderbolt/xHCI wakeup, ASUS HID ENOMEM)
#   - "mmc0: error -110 writing Power Off Notify bit" blocking suspend
#   - Touchpad/RGB not working after resume
# v3.0 - Comprehensive s2idle fix for AMD Strix Halo

set -euo pipefail

HOOK_PATH="/usr/lib/systemd/system-sleep/gz302-reset.sh"

get_display_mask_param() {
    echo "amdgpu.dcdebugmask=0x600"
}

echo "========================================="
echo " GZ302 Suspend Fix Installer (v3.0)"
echo "========================================="
echo ""
echo "This fixes intermittent s2idle hangs that require a hard power-off."
echo ""
echo "Root causes addressed:"
echo "  1. Thunderbolt (NHI) controllers blocking s2idle resume"
echo "  2. xHCI USB controllers with problematic wakeup sources"
echo "  3. ASUS HID devices failing with ENOMEM (-12) on re-probe"
echo "  4. MMC 'Power Off Notify' timeout blocking suspend entry"
echo "  5. Touchpad/RGB not working after successful resume"
echo ""
echo "Will install: $HOOK_PATH"
echo ""

# --- Install the systemd sleep hook ---
sudo tee "$HOOK_PATH" > /dev/null << 'HOOKEOF'
#!/bin/bash
# GZ302 Suspend/Resume Hook
# v3.0 - Comprehensive s2idle fix for Strix Halo
#
# Pre-suspend:
#   - Disable Thunderbolt (NHI) wakeup to prevent s2idle hang
#   - Disable non-essential xHCI wakeup sources
#   - Unbind ASUS HID devices to prevent ENOMEM on resume re-probe
#   - Unbind MMC to prevent "Power Off Notify" timeout
#
# Post-resume:
#   - Rebind MMC devices
#   - Rebind ASUS HID devices
#   - Reset USB keyboard/touchpad/lightbar
#   - Restore RGB settings

set -euo pipefail

LOG_TAG="gz302-reset"
MMC_DRIVER_PATH="/sys/bus/mmc/drivers/mmcblk"
STATE_DIR="/run/gz302-suspend"

log() { logger -t "$LOG_TAG" "$*"; }

case "$1" in
    pre)
        log "=== Pre-suspend hook starting ==="
        mkdir -p "$STATE_DIR"

        # ---------------------------------------------------------------
        # 1. Disable Thunderbolt/NHI wakeup (primary cause of s2idle hang)
        # ---------------------------------------------------------------
        # NHI controllers can send spurious wakeup signals that cause the
        # SoC to exit s2idle but fail to fully resume, resulting in a hang.
        log "Disabling Thunderbolt/NHI wakeup sources..."
        : > "$STATE_DIR/nhi-wakeup"
        for dev in /sys/bus/pci/devices/*; do
            [[ -f "$dev/class" ]] || continue
            local_class=$(<"$dev/class")
            # 0x0c0340 = Thunderbolt NHI (USB4 host)
            if [[ "$local_class" == "0x0c0340" ]]; then
                dev_name=$(basename "$dev")
                if [[ -f "$dev/power/wakeup" ]]; then
                    current=$(<"$dev/power/wakeup")
                    if [[ "$current" == "enabled" ]]; then
                        log "Disabling wakeup on NHI $dev_name"
                        echo "$dev_name" >> "$STATE_DIR/nhi-wakeup"
                        echo "disabled" > "$dev/power/wakeup" 2>/dev/null || true
                    fi
                fi
            fi
        done

        # ---------------------------------------------------------------
        # 2. Disable non-essential xHCI wakeup sources
        # ---------------------------------------------------------------
        # On Strix Halo, multiple xHCI controllers can race during s2idle
        # resume. Keep only the controller hosting the internal keyboard
        # (c4:00.4) wakeup-enabled; disable the rest.
        log "Constraining xHCI wakeup sources..."
        : > "$STATE_DIR/xhc-wakeup"
        for dev in /sys/bus/pci/devices/*; do
            [[ -f "$dev/class" ]] || continue
            local_class=$(<"$dev/class")
            # 0x0c0330 = xHCI USB controller
            if [[ "$local_class" == "0x0c0330" ]]; then
                dev_name=$(basename "$dev")
                # Keep wakeup on the internal USB controller (keyboard lives here)
                [[ "$dev_name" == *"c4:00.4"* ]] && continue
                if [[ -f "$dev/power/wakeup" ]]; then
                    current=$(<"$dev/power/wakeup")
                    if [[ "$current" == "enabled" ]]; then
                        log "Disabling wakeup on xHCI $dev_name"
                        echo "$dev_name" >> "$STATE_DIR/xhc-wakeup"
                        echo "disabled" > "$dev/power/wakeup" 2>/dev/null || true
                    fi
                fi
            fi
        done

        # ---------------------------------------------------------------
        # 3. Unbind ASUS HID devices to prevent ENOMEM on resume
        # ---------------------------------------------------------------
        # The asus HID driver tries to re-probe on resume and fails with
        # ENOMEM (-12), which can cascade into a hung resume. Unbinding
        # before suspend and rebinding after avoids this entirely.
        log "Unbinding ASUS HID devices..."
        : > "$STATE_DIR/asus-hid"
        for hid_dev in /sys/bus/hid/devices/0003:0B05:*; do
            [[ -e "$hid_dev" ]] || continue
            dev_name=$(basename "$hid_dev")
            if [[ -e "$hid_dev/driver" ]]; then
                driver_name=$(basename "$(readlink "$hid_dev/driver")")
                log "Unbinding HID $dev_name (driver: $driver_name)"
                echo "$dev_name:$driver_name" >> "$STATE_DIR/asus-hid"
                echo "$dev_name" > "$hid_dev/driver/unbind" 2>/dev/null || true
            fi
        done

        # ---------------------------------------------------------------
        # 4. Unbind MMC to prevent "Power Off Notify" timeout
        # ---------------------------------------------------------------
        log "Unbinding MMC devices..."
        : > "$STATE_DIR/mmc-devices"
        if [[ -d "$MMC_DRIVER_PATH" ]]; then
            for dev in "$MMC_DRIVER_PATH"/mmc*; do
                [[ -e "$dev" ]] || continue
                dev_name=$(basename "$dev")
                if ! mount | grep -q "^/dev/${dev_name}"; then
                    log "Unbinding $dev_name"
                    echo "$dev_name" >> "$STATE_DIR/mmc-devices"
                    echo "$dev_name" > "$MMC_DRIVER_PATH/unbind" 2>/dev/null || true
                fi
            done
        fi

        log "=== Pre-suspend hook complete ==="
        ;;

    post)
        log "=== Post-resume hook starting ==="

        # ---------------------------------------------------------------
        # 1. Restore NHI wakeup state
        # ---------------------------------------------------------------
        if [[ -f "$STATE_DIR/nhi-wakeup" ]]; then
            while IFS= read -r dev_name; do
                [[ -n "$dev_name" ]] || continue
                log "Re-enabling wakeup on NHI $dev_name"
                echo "enabled" > "/sys/bus/pci/devices/$dev_name/power/wakeup" 2>/dev/null || true
            done < "$STATE_DIR/nhi-wakeup"
        fi

        # ---------------------------------------------------------------
        # 2. Restore xHCI wakeup state
        # ---------------------------------------------------------------
        if [[ -f "$STATE_DIR/xhc-wakeup" ]]; then
            while IFS= read -r dev_name; do
                [[ -n "$dev_name" ]] || continue
                log "Re-enabling wakeup on xHCI $dev_name"
                echo "enabled" > "/sys/bus/pci/devices/$dev_name/power/wakeup" 2>/dev/null || true
            done < "$STATE_DIR/xhc-wakeup"
        fi

        # ---------------------------------------------------------------
        # 3. Rebind MMC devices
        # ---------------------------------------------------------------
        if [[ -f "$STATE_DIR/mmc-devices" ]]; then
            while IFS= read -r dev_name; do
                [[ -n "$dev_name" ]] || continue
                log "Rebinding $dev_name"
                echo "$dev_name" > "$MMC_DRIVER_PATH/bind" 2>/dev/null || true
            done < "$STATE_DIR/mmc-devices"
        fi

        # ---------------------------------------------------------------
        # 4. Reset USB ASUS devices (keyboard/touchpad/lightbar)
        # ---------------------------------------------------------------
        log "Resetting ASUS USB devices..."
        for dev in /sys/bus/usb/devices/*; do
            [[ -f "$dev/idVendor" && -f "$dev/idProduct" ]] || continue
            vid=$(<"$dev/idVendor")
            pid=$(<"$dev/idProduct")
            [[ "$vid" == "0b05" ]] || continue

            case "$pid" in
                1a30)
                    log "Resetting keyboard/touchpad at $dev"
                    echo 0 > "$dev/authorized" 2>/dev/null || true
                    sleep 0.1
                    echo 1 > "$dev/authorized" 2>/dev/null || true
                    ;;
                18c6)
                    log "Resetting lightbar at $dev"
                    echo 0 > "$dev/authorized" 2>/dev/null || true
                    sleep 0.1
                    echo 1 > "$dev/authorized" 2>/dev/null || true
                    ;;
            esac
        done

        # ---------------------------------------------------------------
        # 5. Rebind ASUS HID devices
        # ---------------------------------------------------------------
        # Wait for USB devices to settle after reset before rebinding HID
        sleep 1
        if [[ -f "$STATE_DIR/asus-hid" ]]; then
            while IFS=: read -r dev_name driver_name; do
                [[ -n "$dev_name" ]] || continue
                # The HID device will be re-enumerated by USB reset above,
                # so only rebind if the device still exists unbound
                if [[ -e "/sys/bus/hid/devices/$dev_name" && ! -e "/sys/bus/hid/devices/$dev_name/driver" ]]; then
                    if [[ -e "/sys/bus/hid/drivers/$driver_name" ]]; then
                        log "Rebinding HID $dev_name to $driver_name"
                        echo "$dev_name" > "/sys/bus/hid/drivers/$driver_name/bind" 2>/dev/null || true
                    fi
                fi
            done < "$STATE_DIR/asus-hid"
        fi

        # ---------------------------------------------------------------
        # 6. Restore RGB settings (via z13ctl if available)
        # ---------------------------------------------------------------
        sleep 0.5
        if command -v z13ctl >/dev/null 2>&1; then
            log "Restoring RGB settings via z13ctl..."
            z13ctl apply 2>&1 | logger -t gz302-rgb-restore || true
        fi

        # Clean up state dir
        rm -rf "$STATE_DIR"

        log "=== Post-resume hook complete ==="
        ;;
esac
exit 0
HOOKEOF

sudo chmod +x "$HOOK_PATH"

# --- Kernel parameter recommendations ---
echo ""
echo "✓ Suspend hook installed!"
echo ""
echo "=== Kernel Parameter Recommendations ==="
echo ""
echo "For best s2idle reliability on Strix Halo, add these to your bootloader:"
echo ""

CMDLINE=$(cat /proc/cmdline 2>/dev/null)
SUGGEST_PARAMS=""
DISPLAY_MASK_PARAM=$(get_display_mask_param)

if ! echo "$CMDLINE" | grep -q "$DISPLAY_MASK_PARAM"; then
    if echo "$CMDLINE" | grep -q "amdgpu.dcdebugmask="; then
        SUGGEST_PARAMS+="  ${DISPLAY_MASK_PARAM}   # Replace the existing display mask with the kernel-aware value\n"
    else
        SUGGEST_PARAMS+="  ${DISPLAY_MASK_PARAM}   # Current OLED/display stability mask\n"
    fi
fi
if ! echo "$CMDLINE" | grep -q "rtc_cmos.use_acpi_alarm"; then
    SUGGEST_PARAMS+="  rtc_cmos.use_acpi_alarm=1   # Fix RTC wakeup via ACPI\n"
fi

if [[ -n "$SUGGEST_PARAMS" ]]; then
    echo -e "$SUGGEST_PARAMS"
    echo "To add these on CachyOS/Arch, edit /etc/default/grub or your"
    echo "bootloader config, then regenerate (e.g., sudo grub-mkconfig -o /boot/grub/grub.cfg)"
else
    echo "  All recommended parameters already present."
fi

echo ""
echo "Note: This suspend hook does not require amd_pmc.enable_stb=1."
echo "      Leave Smart Trace Buffer disabled unless you are collecting kernel debug data."
echo ""
echo "=== What This Fix Does ==="
echo ""
echo "  PRE-SUSPEND:"
echo "    • Disables Thunderbolt (NHI) controller wakeup"
echo "    • Limits xHCI wakeup to internal keyboard controller only"
echo "    • Unbinds ASUS HID devices (prevents ENOMEM on re-probe)"
echo "    • Unbinds internal SD card (prevents Power Off Notify timeout)"
echo ""
echo "  POST-RESUME:"
echo "    • Restores all wakeup sources"
echo "    • Rebinds MMC and ASUS HID devices"
echo "    • Resets keyboard/touchpad/lightbar USB"
echo "    • Restores RGB settings"
echo ""
echo "Test by suspending and resuming. Check logs with:"
echo "  journalctl -b -t gz302-reset"
