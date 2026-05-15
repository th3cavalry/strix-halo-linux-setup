# GZ302 Testing Guide — Strix Halo Edition

**Current Version:** 6.4.1  
**Status:** Unified Testing Framework for GZ302 & Strix Halo Platform

---

## Overview

This guide provides comprehensive testing procedures for the GZ302-Linux-Setup project (v6.x). It covers core hardware enablement scripts and the PyQt6-based Command Center.

---

## Test Environments

### Supported Platforms
1. **ASUS ROG Flow Z13 (GZ302)**: Primary reference hardware.
2. **Generic Strix Halo Devices**: HP ZBook Ultra, Framework ITX, etc.
3. **Kernels**: 6.14 (Minimum), 6.17+ (Recommended/Native).

---

## 1. Command Center (GUI) Testing

The Command Center is the most visible component and requires rigorous UI/UX validation.

### System Tray Menu
- [ ] **Dynamic Updates**: Right-click the tray icon multiple times. Verify that checkmarks correctly follow the active power profile.
- [ ] **Power Profiles**: Select each of the 8 profiles (Emergency to Maximum). Use `z13ctl status` to verify the profile and TDP apply correctly.
- [ ] **RGB Lighting**: 
    - Test keyboard and backlight static color swatches separately from both the dashboard and tray menu.
    - Test each custom color dialog and confirm it changes only the selected zone.
    - Test each brightness level (Off, Low, Medium, High).
    - Test animation effects (Rainbow, Color Cycle, Breathing).
    - Verify "Turn Off All" kills both keyboard and lightbar LEDs.
- [ ] **Battery Limit**: Select 60%, 80%, and 100%. Verify via `z13ctl status`.
- [ ] **Auto Switch Toggle**: Enable/Disable. Verify state is saved in `~/.config/gz302/auto.conf`.

### Dashboard Window
- [ ] **Visibility**: Left-click tray icon to show/hide.
- [ ] **Static Color Picker**: Verify the dashboard shows separate keyboard and backlight color rows with visual swatches and a custom color action.
- [ ] **Real-time Stats**: Verify APU temperature and CPU load update every 3 seconds.
- [ ] **Fan Curves**: Apply a custom curve. Verify `z13ctl status` shows the new curve points.
- [ ] **AI/NPU Status**: Confirm the "AI & NPU" tab correctly identifies the Ryzen AI NPU state.

---

## 2. Core Script Testing (z13ctl & Helpers)

### Installation & Idempotency
- [ ] **Fresh Install**: Run `sudo ./gz302-setup.sh` on a clean system.
- [ ] **Idempotency**: Run the script a second time. It should complete in < 5 seconds without re-downloading or re-applying static fixes.
- [ ] **Status Mode**: Run `sudo ./gz302-setup.sh --status`. Verify it accurately reflects which components are "Applied".

### Hardware Enablement
- [ ] **WiFi (MT7925)**: Verify connectivity and absence of "deauthentication" loops in `dmesg`.
- [ ] **GPU (Radeon 8060S)**: Run `vulkaninfo` or `glxinfo` to verify driver initialization on gfx1151.
- [ ] **Audio (CS35L41)**: Verify both speakers are active and balanced.
- [ ] **Suspend/Resume**: Verify system wakes correctly without GPU hangs or WiFi dropouts.

---

## 3. Automated Validation

### Syntax & Linting
```bash
# Validate all scripts
for script in gz302-*.sh; do bash -n "$script" && echo "✓ $script"; done

# Shellcheck (Critical for logic errors)
shellcheck gz302-setup.sh gz302-lib/*.sh
```

### Python/PyQt6 Sanity
```bash
# Check for import errors or syntax issues
python3 -m py_compile command-center/src/command_center.py
python3 -m py_compile command-center/src/modules/*.py
```

---

## 4. Regression Testing

### Migration from v5.x
- [ ] Verify that old `pwrcfg` configs are correctly handled or migrated by the new `z13ctl` logic.
- [ ] Ensure `sudo ./install-policy.sh` updates the sudoers entries for the new binary names.

---

## Troubleshooting Tests

- **Missing Icons**: On Arch, SVG is bundled in `python-pyqt6`. On Debian/Fedora, install `python3-pyqt6.qtsvg` / `python3-qt6-qtsvg`.
- **Permission Denied**: Check `/etc/sudoers.d/gz302` and confirm the current user is in the `users` group.
- **z13ctl Timeout**: Ensure the daemon is running: `systemctl --user status z13ctl.service`.

---

**Last Updated:** 2026-04-23  
**Status:** Updated for Command Center v6.2.0 features.
