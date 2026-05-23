# Strix Halo Linux Setup

![Version](https://img.shields.io/badge/version-6.8.0-blue?style=for-the-badge)
![Kernel](https://img.shields.io/badge/Kernel-6.14%2B-orange?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Platform](https://img.shields.io/badge/Platform-AMD%20Strix%20Halo-red?style=for-the-badge)

**Unified Linux optimization suite for AMD Strix Halo (Ryzen AI MAX / MAX+) devices.**

Hardware auto-detection, per-device fixes, a vendor-neutral Strix Halo dashboard, and ASUS hardware control via [z13ctl](https://github.com/dahui/z13ctl) where applicable.

Supports the known Strix Halo device matrix below plus other confirmed Strix Halo hardware through the generic baseline profile.

---

## Supported Devices

<!-- BEGIN:SUPPORTED_DEVICE_TABLE -->
<!-- AUTO-GENERATED from strix-halo-lib/device-profile-data.sh via scripts/sync-device-matrix.sh -->
| Device | APU | Class | Support tier | Coverage |
| :--- | :--- | :--- | :--- | :--- |
| **ASUS ROG Flow Z13 (GZ302)** | Ryzen AI Max+ 395 / Max 390 | Tablet / Gaming 2-in-1 | Full | Full stack |
| **HP ZBook Ultra G1a** | Ryzen AI Max+ PRO 395 | Workstation laptop | Partial | Dashboard + core stack |
| **HP Mini Workstation (Z2 G1a)** | Ryzen AI Max+ 395 | Mini workstation | Partial | Dashboard + core stack |
| **Framework Desktop** | Ryzen AI Max 385 / Max+ 395 | Desktop | Partial | Dashboard + core stack |
| **ASUS TUF Gaming A14** | Ryzen AI Max+ 392 | Laptop | Partial | Dashboard + ASUS control |
| **Sixunited AXP77** | Ryzen AI Max+ 395 | Mini-PC | Experimental | Dashboard + baseline stack |
| **GMKtec EVO-X2** | Ryzen AI Max+ 395 | Mini-PC | Experimental | Dashboard + baseline stack |
| **Minisforum MS-S1 Max** | Ryzen AI Max+ 395 | Mini-PC | Experimental | Dashboard + baseline stack |
| **AYANEO NEXT 2** | Ryzen AI Max+ 395 | Handheld | Experimental | Dashboard + baseline stack |
| **GPD Win 5** | Ryzen AI Max+ 395 | Handheld | Experimental | Dashboard + baseline stack |
| **Other Strix Halo** | Ryzen AI MAX family | Laptop / Mini-PC / Handheld | Experimental baseline | Dashboard + baseline stack |

> Coverage labels: **Full stack** = dashboard + core fixes + ASUS control + the full GZ302 command-center surface; **Dashboard + ASUS control** = dashboard + core fixes + ASUS control on supported ASUS devices; **Dashboard + core stack** = dashboard + cross-device fixes, gaming, AI/ROCm, and integrations; **Dashboard + baseline stack** = the same dashboard-first path under experimental validation.
<!-- END:SUPPORTED_DEVICE_TABLE -->

---

## Installation

One script handles everything. It auto-detects your hardware and selects the relevant sections:

```bash
curl -L https://raw.githubusercontent.com/th3cavalry/strix-halo-linux-setup/main/strix-halo-setup.sh -o strix-halo-setup.sh
chmod +x strix-halo-setup.sh
sudo ./strix-halo-setup.sh
```

The installer detects your device, distribution, kernel, and capabilities, then walks you through:

| Section | What it does |
| :--- | :--- |
| **1. Hardware Fixes** | WiFi (MT7925), GPU (Radeon 8060S), Input, Audio (SOF/CS35L41), OLED PSR-SU fix, Suspend fix |
| **2. Dashboard** | Strix Halo dashboard on all confirmed devices; ASUS z13ctl control surfaces where applicable |
| **3. Gaming** | Steam, Lutris, MangoHUD, GameMode, Wine, Proton-GE |
| **4. AI / LLM** | Ollama, LM Studio, ROCm, PyTorch, vLLM, ComfyUI |
| **5. Other Tools** | Hypervisor (KVM/QEMU), community integrations |

### CLI Flags

```bash
sudo ./strix-halo-setup.sh -y              # Accept all defaults (non-interactive)
sudo ./strix-halo-setup.sh --fixes-only    # Hardware fixes only
sudo ./strix-halo-setup.sh --no-z13ctl     # Skip z13ctl installation
sudo ./strix-halo-setup.sh --help          # Show all options
```

---

## Quick Start (after installation)

The commands below apply to ASUS devices where `z13ctl` is supported.

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

On ASUS devices where `z13ctl` is supported, the installer creates `pwrcfg` and `gz302-rgb` wrappers:

| Command | Maps to |
| :--- | :--- |
| `z13ctl status` | `z13ctl status` |
| `z13ctl profile --set quiet` | `z13ctl profile --set quiet` |
| `z13ctl tdp --set 50` | `z13ctl tdp --set 50` |
| `z13ctl apply --mode rainbow` | `z13ctl apply --mode rainbow` |

---

## Strix Halo Dashboard

After installation on any confirmed Strix Halo device, look for **"Strix Halo Dashboard"** in your system tray.

On non-ASUS or non-z13ctl Strix Halo devices, the dashboard stays in monitoring mode and keeps unsupported vendor-control actions disabled.

- **Left-click:** Toggle Dashboard Window (Monitoring, Fan Curves, AI Status)
- **Right-click:** Quick access menu.
- **ASUS + z13ctl:** Profiles, RGB lighting, battery limits, and auto-switch controls stay available.
- **Other Strix Halo devices:** Monitoring, launch, and generic dashboard flows stay available while unsupported vendor controls remain disabled.
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
> If you see OLED artifacts, confirm `amdgpu.dcdebugmask=0x600` is present in your boot cmdline (applies to all supported kernels).

---

## Display Fixes

### OLED Display Artifacts

**Issue:** Purple/green color artifacts during scrolling, intermittent corruption during idle, or color-shift fringing on the built-in OLED panel (not external monitors).
**Cause:** Multiple DC power-save features active on the internal eDP panel: PSR, PSR-SU, Panel Replay (DCN 3.5 / Strix Halo), IPS (Idle Power Save), DRAM stutter, and scatter-gather display on APU. ABM (Adaptive Backlight Management) also causes colour-shift artifacts on OLED.
**Fix:** The installer applies `amdgpu.dcdebugmask=0x600` (PSR-SU + Panel Replay disabled) for all supported kernels, plus modprobe options `abmlevel=0`, `sg_display=0`, and `cwsr_enable=0`.

---

## Repository Structure

```text
GZ302-Linux-Setup/
├── strix-halo-setup.sh             # Unified installer (single entry point)
├── strix-halo-lib/                 # Core libraries (manager-based)
│   ├── utils.sh               # Shared utilities, logging, backups
│   ├── device-manager.sh      # Hardware detection, device profiles, capabilities (NEW)
│   ├── device-profile-data.sh # Known-device matrix and profile capability data
│   ├── kernel-compat.sh       # Kernel version detection
│   └── ... (wifi, gpu, audio, etc.)
├── modules/                   # Optional feature packs (gaming, llm, etc.)
├── scripts/                   # System scripts and repo sync helpers
├── tests/                     # Regression checks and version validation helpers
├── command-center/            # PyQt6 system tray application
├── docs/                      # User guides and changelogs
│   └── technical/             # Hardware research and obsolescence analysis
│       ├── external-integrations-catalog.md  # Strix Halo ecosystem catalog (NEW)
│       └── strix-halo-platform-transition-plan.md
└── legacy/                    # Deprecated and replaced scripts
```

---

## Strix Halo Ecosystem

The installer can optionally set up community projects verified to work on Strix Halo hardware.
See [`docs/technical/external-integrations-catalog.md`](docs/technical/external-integrations-catalog.md) for the full catalog.

| Project | Purpose | Devices |
| :--- | :--- | :--- |
| [z13ctl](https://github.com/dahui/z13ctl) | RGB, TDP, fan curves, battery (ASUS backend) | ASUS ROG |
| [Strix-Halo-Control](https://github.com/TechnoDaimon/Strix-Halo-Control) | GTK4 GUI for z13ctl | ASUS ROG |
| [amd-strix-halo-toolboxes](https://github.com/kyuz0/amd-strix-halo-toolboxes) | Container AI workflows (Ollama, vLLM, ComfyUI) | All |
| [GameMode](https://github.com/FeralInteractive/gamemode) | CPU/GPU performance tuning for gaming | All |

---

## AI & Copilot Instructions

**MANDATORY for all AI/LLM interactions and automated code changes.** 
All AI agents MUST read and follow the strict mandates in [.github/copilot-instructions.md](.github/copilot-instructions.md).

---

## Credits

- **[z13ctl](https://github.com/dahui/z13ctl)** by Jeff Hagadorn — RGB lighting, power profiles, TDP, fan curves, battery limit, and daemon. The hardware control backend that makes this all possible.
- **[g-helper](https://github.com/seerge/g-helper)** by seerge — Protocol reverse-engineering reference for ASUS HID devices.
- **[Strix-Halo-Control](https://github.com/TechnoDaimon/Strix-Halo-Control)** by TechnoDaimon — GTK4 GUI inspiration for z13ctl integration.
- **[amd-strix-halo-toolboxes](https://github.com/kyuz0/amd-strix-halo-toolboxes)** by kyuz0 — Container-based AI workflow toolboxes for all Strix Halo devices.

---

## Uninstall

```bash
sudo bash scripts/uninstall/uninstall.sh
```

This removes all GZ302 tools, z13ctl daemon/config, systemd services, udev rules, and configuration files.

---

## Contributing & Support

- **Documentation:** See the [docs/](docs/) directory for user guides and [docs/technical/](docs/technical/) for hardware research.
- **AI Guidelines:** Strict rules for LLM/Copilot contributions are in [.github/copilot-instructions.md](.github/copilot-instructions.md).
- **Issues:** Report bugs on the [Issues page](https://github.com/th3cavalry/strix-halo-linux-setup/issues).
- **Development:** See [CONTRIBUTING.md](CONTRIBUTING.md).

**License:** MIT
**Maintained by:** th3cavalry
