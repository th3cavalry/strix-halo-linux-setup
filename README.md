# ASUS ROG Flow Z13 (GZ302) Linux Toolkit

![Version](https://img.shields.io/badge/version-6.4.1-blue?style=for-the-badge)
![Kernel](https://img.shields.io/badge/Kernel-6.14%2B-orange?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Platform](https://img.shields.io/badge/Device-ASUS%20ROG%20Flow%20Z13-red?style=for-the-badge)

**Linux optimization suite for the ASUS ROG Flow Z13 (GZ302) powered by the AMD Ryzen AI MAX+ 395 (Strix Halo) processor.**

Hardware fixes, power/TDP management, RGB lighting, fan curves, battery limiting, and a system tray GUI — powered by [z13ctl](https://github.com/dahui/z13ctl).

---

## Installation

One script handles everything. Pick which sections to install interactively:

```bash
curl -L https://raw.githubusercontent.com/th3cavalry/GZ302-Linux-Setup/main/gz302-setup.sh -o gz302-setup.sh
chmod +x gz302-setup.sh
sudo ./gz302-setup.sh
```

The installer aligns `z13ctl` access for both CLI and GUI use. If it adds your account to the `users` group during setup, log out and back in once so existing desktop sessions pick up the new membership.

The installer prompts for four sections:

| Section | What it does |
| :--- | :--- |
| **1. Hardware Fixes** | WiFi (MT7925), GPU (Radeon 8060S), Input, Audio (SOF/CS35L41), OLED PSR-SU fix, Suspend fix |
| **2. z13ctl** | RGB lighting, power profiles, TDP, fan curves, battery charge limit, undervolt, sleep recovery |
| **3. Display & Tools** | Refresh rate control (rrcfg), system tray app |
| **4. Optional Modules** | Gaming (Steam, Lutris, MangoHUD), AI/LLM (Ollama, ROCm), Hypervisor (KVM/QEMU) |

### CLI Flags

```bash
sudo ./gz302-setup.sh -y              # Accept all defaults (non-interactive)
sudo ./gz302-setup.sh --fixes-only    # Hardware fixes only
sudo ./gz302-setup.sh --no-z13ctl     # Skip z13ctl installation
sudo ./gz302-setup.sh --help          # Show all options
```

---

## Quick Start (after installation)

```bash
# RGB lighting
z13ctl apply --color cyan --brightness high
z13ctl apply --mode rainbow --speed normal
z13ctl off

# Power profiles
z13ctl profile --set balanced
z13ctl tdp --set 50

# Battery
z13ctl batterylimit --set 80

# Fan curves (8-point, temp:pwm pairs)
z13ctl fancurve --set "48:2,53:22,57:30,60:43,63:56,65:68,70:89,76:102"

# Status
z13ctl status
```

### Backward-Compatible Wrappers

The installer creates `pwrcfg` and `gz302-rgb` wrappers that map to z13ctl:

| Command | Maps to |
| :--- | :--- |
| `z13ctl status` | `z13ctl status` |
| `z13ctl profile --set quiet` | `z13ctl profile --set quiet` |
| `z13ctl tdp --set 50` | `z13ctl tdp --set 50` |
| `z13ctl apply --mode rainbow` | `z13ctl apply --mode rainbow` |

---

## System Tray App

After installation, look for **"ASUS ROG Flow Z13 (GZ302) Command Center"** in your system tray.

- **Left-click:** Toggle Dashboard Window (Monitoring, Fan Curves, AI Status)
- **Right-click:** Quick access menu:
  - **⚡ Profiles:** Switch between all 8 performance modes (10W-90W)
  - **🌈 RGB Lighting:** Pick static colors separately for keyboard and backlight, plus brightness and animation effects
  - **🔋 Battery Limit:** Set 60/80/100% charge caps
  - **🔄 Auto Switch:** Toggle automatic AC/Battery profile switching
- **Hover:** Real-time temperature, profile, and power status

---

## Kernel Compatibility

The scripts automatically detect your kernel and adapt:

| Kernel | Status |
| :--- | :--- |
| **< 6.14** | Unsupported — please upgrade |
| **6.14 – 6.16** | Applies workarounds for WiFi (MT7925), Touchpad, Tablet mode |
| **6.17+** | Native support — cleans up obsolete fixes, focuses on tuning |

> [!NOTE]
> **Ubuntu 26.04 is supported.** On Linux 7.0+ most old hardware-enablement workarounds are no longer required, but the setup script is still useful for tuning and consistency.
> If you see OLED artifacts, confirm a kernel-appropriate `amdgpu.dcdebugmask=` value is present in your boot cmdline (`0xe12` on kernel 6.x, `0x600` on kernel 7.0+).

---

## Display Fixes

### OLED Display Artifacts

**Issue:** Purple/green color artifacts during scrolling, intermittent corruption during idle, or color-shift fringing on the built-in OLED panel (not external monitors).
**Cause:** Multiple DC power-save features active on the internal eDP panel: PSR, PSR-SU, Panel Replay (DCN 3.5 / Strix Halo), IPS (Idle Power Save), DRAM stutter, and scatter-gather display on APU. ABM (Adaptive Backlight Management) also causes colour-shift artifacts on OLED.
**Fix:** The installer applies a kernel-aware `amdgpu.dcdebugmask` automatically: `0xe12` on kernel 6.x, `0x600` on kernel 7.0+, plus modprobe options `abmlevel=0`, `sg_display=0`, and `cwsr_enable=0`.

---

## Repository Structure

```
GZ302-Linux-Setup/
├── gz302-setup.sh             # Unified installer (single entry point)
├── gz302-lib/                 # Core libraries (manager-based)
│   ├── utils.sh               # Shared utilities, logging, backups
│   ├── kernel-compat.sh       # Kernel version detection
│   └── ... (wifi, gpu, audio, etc.)
├── modules/                   # Optional feature packs (gaming, llm, etc.)
├── scripts/                   # System scripts (fix-suspend, uninstall)
├── command-center/            # PyQt6 system tray application
├── docs/                      # User guides and changelogs
│   └── technical/             # Hardware research and obsolescence analysis
└── legacy/                    # Deprecated and replaced scripts
```

---

## AI & Copilot Instructions

**MANDATORY for all AI/LLM interactions and automated code changes.** 
All AI agents MUST read and follow the strict mandates in [.github/copilot-instructions.md](.github/copilot-instructions.md).

---

## Credits

- **[z13ctl](https://github.com/dahui/z13ctl)** by Jeff Hagadorn — RGB lighting, power profiles, TDP, fan curves, battery limit, and daemon. The hardware control backend that makes this all possible.
- **[g-helper](https://github.com/seerge/g-helper)** by seerge — Protocol reverse-engineering reference for ASUS HID devices.
- **[Strix-Halo-Control](https://github.com/TechnoDaimon/Strix-Halo-Control)** by TechnoDaimon — GTK4 GUI inspiration for z13ctl integration.

---

## Uninstall

```bash
sudo bash scripts/uninstall/gz302-uninstall.sh
```

This removes all GZ302 tools, z13ctl daemon/config, systemd services, udev rules, and configuration files.

---

## Contributing & Support

- **Documentation:** See the [docs/](docs/) directory for user guides and [docs/technical/](docs/technical/) for hardware research.
- **AI Guidelines:** Strict rules for LLM/Copilot contributions are in [.github/copilot-instructions.md](.github/copilot-instructions.md).
- **Issues:** Report bugs on the [Issues page](https://github.com/th3cavalry/GZ302-Linux-Setup/issues).
- **Development:** See [CONTRIBUTING.md](CONTRIBUTING.md).

**License:** MIT
**Maintained by:** th3cavalry
