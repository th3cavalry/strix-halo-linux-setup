# Strix Halo Command Center — Strix Halo Edition

A unified system tray and dashboard application for the ASUS ROG Flow Z13 (GZ302) "Strix Halo".

## Overview

This is a G-Helper inspired GUI utility that provides quick access to system controls through a system tray application and a detailed dashboard. It leverages `z13ctl` to manage power, lighting, and performance settings without needing terminal commands.

## Features

### ⚡ Power Management
- **8 Distinct Profiles**: From Emergency (10W) to Maximum (90W).
- **Auto Settings Adjust**: Automatically switches profiles when plugging/unplugging AC power.
- **Battery Charge Limit**: Set thresholds (60%, 80%, 100%) to extend battery longevity.
- **Real-time TDP Overrides**: Surgical control over power limits via `z13ctl`.

### 🌈 RGB Lighting
- **Separate Static Color Pickers**: Visual swatches and custom color dialogs for keyboard and backlight.
- **Per-Zone Quick Controls**: Keyboard and backlight shortcuts are scoped to the selected zone instead of broadcasting to all LEDs.
- **Brightness Levels**: Off, Low, Medium, High.
- **Animation Effects**: Rainbow, Color Cycle, Breathing.
- **Quick Toggle**: "Turn Off All" option for immediate stealth mode.

### 🖥️ Dashboard
- **Real-time Monitoring**: Track APU temperature, CPU load, and fan speeds.
- **Visual Feedback**: The tray icon changes based on the active power profile and charging state.
- **Fan Curve Editor**: (In Dashboard) Apply custom T:P fan curves.

## Technology Stack

- **Python 3** - Main programming language
- **PyQt6** - GUI framework for system tray and dashboard
- **z13ctl** - The underlying driver for GZ302 hardware control

## Installation

### Prerequisites

1. GZ302 Linux Setup main scripts must be installed (`z13ctl` daemon should be running).
2. Python 3.8 or higher.

### Step 1: Install Python Dependencies

```bash
# Arch/Manjaro (SVG support is bundled in python-pyqt6)
sudo pacman -S python-pyqt6 python-psutil

# Ubuntu/Debian
sudo apt install python3-pyqt6 python3-pyqt6.qtsvg python3-psutil

# Fedora
sudo dnf install python3-pyqt6 python3-qt6-qtsvg python3-psutil
```

### Step 2: Configure Policy (Recommended)

```bash
cd command-center
sudo ./install-policy.sh
```

This configures `z13ctl` permissions to allow the GUI to make changes without password prompts.
If you installed through the main `strix-halo-setup.sh` workflow, the installer already handles the `users` group and the GUI sudoers fallback.

### Step 3: Install Desktop Launcher + Autostart

```bash
cd command-center
./install-tray.sh
```

This creates a launcher in your application menu and sets the command center to start automatically on login.

## Usage

1. **Open Dashboard**: Left-click the tray icon or select "Open Dashboard" from the right-click menu.
2. **Quick Switch**: Right-click the tray icon to access:
   - **⚡ Profiles**: Select performance modes.
   - **🔋 Battery Limit**: Quickly cap charging.
   - **🌈 RGB Lighting**: Pick static colors separately for keyboard and backlight, then adjust brightness and effects.
   - **🔄 Auto Settings Adjust**: Toggle automatic power switching.
3. **Tray Icons**:
   - 🔋 Battery icon: Running on battery (Auto-switch enabled).
   - 🔌 AC icon: Running on AC power (Auto-switch enabled).
   - 🎮 Profile letters (B, P, G): Manual profile overrides.

## Troubleshooting

### Blank or Missing Icon
- **GNOME Users**: Install the "AppIndicator and KStatusNotifierItem Support" extension.
- **Missing SVG Support**: On Arch, SVG is bundled in `python-pyqt6`. On Debian/Fedora, install `python3-pyqt6.qtsvg` or `python3-qt6-qtsvg`.

### Changes Don't Apply
- Ensure the `z13ctl` daemon is active: `systemctl --user status z13ctl.service`
- If the installer just added your account to the `users` group, log out and back in once.
- Try running `sudo z13ctl setup` to ensure udev rules and sockets are correctly configured.

---

**Note**: This is an optional companion utility. The main GZ302 setup scripts and `z13ctl` work perfectly via terminal commands.
