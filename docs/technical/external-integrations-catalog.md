# Strix Halo External Integrations Catalog

**Last updated:** 2026-05-17  
**Scope:** Curated list of third-party projects, toolkits, and applications for
AMD Strix Halo (Ryzen AI MAX / MAX+) devices on Linux.  
**Format:** Each entry includes its purpose, supported devices/distros, install
method, trust level, and last verified date.

---

## How to Use This Catalog

The Strix Halo Setup installer (`strix-halo-setup.sh`) reads this catalog and
presents relevant entries for the detected device and distribution.  Each
entry is **opt-in only** — nothing from this list is installed automatically.

Trust levels:

| Level | Meaning |
|---|---|
| `official` | Maintained by hardware vendor or formally adopted upstream |
| `community-verified` | Actively maintained, widely used, reviewed by this project |
| `experimental` | Functional but less tested; use with awareness of limitations |

---

## Hardware Control

### z13ctl
- **Description:** Hardware control daemon for ASUS ROG Flow Z13 (and compatible ASUS ROG laptops). Provides RGB lighting control, power profiles (TDP), fan curves, battery charge limit, undervolt, and sleep/resume recovery via the ASUS HID interface.
- **URL:** <https://github.com/dahui/z13ctl>
- **Category:** `control`
- **Supported devices:** ASUS ROG Flow Z13 (GZ302), ASUS ROG laptops with Strix Halo
- **Supported distros:** Arch (AUR: `z13ctl-bin`), Debian/Ubuntu (.deb release), Fedora (.rpm release), OpenSUSE (tarball)
- **Install method:** `package` (AUR/deb/rpm) or `binary` (release tarball)
- **Trust level:** `community-verified`
- **Last verified:** 2026-05-15

### Strix-Halo-Control
- **Description:** GTK4 GUI application for ASUS ROG Flow Z13 hardware control. Provides a graphical interface for the same z13ctl capabilities — RGB, fan curves, power profiles, and battery management. Inspired by G-Helper (Windows).
- **URL:** <https://github.com/TechnoDaimon/Strix-Halo-Control>
- **Category:** `control`
- **Supported devices:** ASUS ROG Flow Z13 (GZ302)
- **Supported distros:** Any (Python/GTK4)
- **Install method:** `script` (clone + run)
- **Trust level:** `community-verified`
- **Last verified:** 2026-05-15
- **Notes:** GUI alternative to the command-center tray app. Install only one or the other to avoid z13ctl daemon conflicts.

---

## AI / LLM Toolboxes

### amd-strix-halo-toolboxes (kyuz0)
- **Description:** Container-based AI workflow toolboxes optimized for Strix Halo hardware. Provides isolated, reproducible environments for LLM inference (Ollama, vLLM), image/video generation (ComfyUI), and model fine-tuning (QLoRA). Uses Fedora Toolbx or Distrobox for container management. Supports ROCm 6.4.4 through 7.2.3+.
- **URL:** <https://github.com/kyuz0/amd-strix-halo-toolboxes>
- **Website:** <https://strix-halo-toolboxes.com>
- **Category:** `ai`
- **Supported devices:** All Strix Halo devices (Radeon 8060S / gfx1151)
- **Supported distros:** Fedora (native), Ubuntu, Arch, OpenSUSE (via Distrobox)
- **Install method:** `container` (Toolbx / Distrobox)
- **Trust level:** `community-verified`
- **Last verified:** 2026-05-15
- **Notes:** Recommended path for AI workloads. Container isolation prevents ROCm version conflicts with the host system. Requires kernel ≥ 6.18 and firmware ≥ 20260110 for stability.

### vLLM (AMD ROCm)
- **Description:** High-throughput LLM inference server with PagedAttention, tool use, and OpenAI-compatible API. AMD fork maintained with Strix Halo (gfx1151) support.
- **URL:** <https://github.com/vllm-project/vllm>
- **Category:** `ai`
- **Supported devices:** All Strix Halo devices
- **Supported distros:** Any (pip/container)
- **Install method:** `container` (recommended) or `pip`
- **Trust level:** `community-verified`
- **Last verified:** 2026-05-15
- **Notes:** Best deployed via the kyuz0 toolboxes above. Standalone install requires ROCm 7.2+ on host.

### ComfyUI (AMD ROCm)
- **Description:** Modular node-based stable diffusion / image-video generation UI. Runs on the Radeon 8060S via ROCm. Well-suited to Strix Halo's large unified memory (up to 128 GB) for high-resolution or long-context generation.
- **URL:** <https://github.com/comfyanonymous/ComfyUI>
- **Category:** `ai`
- **Supported devices:** All Strix Halo devices
- **Supported distros:** Any (pip/container)
- **Install method:** `container` (recommended) or `pip`
- **Trust level:** `community-verified`
- **Last verified:** 2026-05-15

---

## Gaming

### ProtonDB / Proton-GE
- **Description:** Community-managed Proton builds with extra patches for improved game compatibility. Installed via ProtonUp-Qt or the Steam compatibility tools directory.
- **URL:** <https://github.com/GloriousEggroll/proton-ge-custom>
- **Category:** `gaming`
- **Supported devices:** All Strix Halo devices
- **Supported distros:** Any (Steam required)
- **Install method:** `script` (ProtonUp-Qt)
- **Trust level:** `community-verified`
- **Last verified:** 2026-05-15

### GameMode (Feral Interactive)
- **Description:** Linux daemon that optimises system performance on demand when games are launched. CPU governor, I/O scheduler, and process priority tuning. Integrates with Steam and Lutris.
- **URL:** <https://github.com/FeralInteractive/gamemode>
- **Category:** `gaming`
- **Supported devices:** All Strix Halo devices
- **Supported distros:** Arch (`gamemode`), Debian/Ubuntu (`gamemode`), Fedora (`gamemode`), OpenSUSE (`gamemode`)
- **Install method:** `package`
- **Trust level:** `official`
- **Last verified:** 2026-05-15

---

## Device-Specific Reference Projects

### Asus-Z13-Flow-2025-PCMR (Shahzebqazi)
- **Description:** Community setup guide and script collection for Arch Linux on the ASUS ROG Flow Z13 (2025). Documents kernel parameters, audio quirks, power management, and ASUS WMI configuration relevant to GZ302.
- **URL:** <https://github.com/Shahzebqazi/Asus-Z13-Flow-2025-PCMR>
- **Category:** `control`
- **Supported devices:** ASUS ROG Flow Z13 (GZ302)
- **Supported distros:** Arch Linux
- **Install method:** `manual` (reference / scripts)
- **Trust level:** `experimental`
- **Last verified:** 2026-05-15
- **Notes:** Useful as a reference for Arch-specific edge cases. This toolkit already incorporates the relevant fixes.

---

## Monitoring & Benchmarking

### MangoHUD
- **Description:** Vulkan/OpenGL overlay for real-time GPU, CPU, frame-time, and temperature monitoring during gaming or benchmarking. Supports Strix Halo's amdgpu driver.
- **URL:** <https://github.com/flightlessmango/MangoHud>
- **Category:** `monitoring`
- **Supported devices:** All Strix Halo devices
- **Supported distros:** Arch, Debian/Ubuntu, Fedora, OpenSUSE
- **Install method:** `package`
- **Trust level:** `community-verified`
- **Last verified:** 2026-05-15

---

## Known Strix Halo Devices (as of 2026-05-17)

<!-- BEGIN:KNOWN_STRIX_HALO_DEVICE_TABLE -->
<!-- AUTO-GENERATED from strix-halo-lib/device-profile-data.sh via scripts/sync-device-matrix.sh -->
| Device | APU | Class | Support tier | Coverage |
|---|---|---|---|---|
| ASUS ROG Flow Z13 (GZ302) | Ryzen AI Max+ 395 / Max 390 | Tablet / Gaming 2-in-1 | Full | Full stack |
| HP ZBook Ultra G1a | Ryzen AI Max+ PRO 395 | Workstation laptop | Partial | Dashboard + core stack |
| HP Mini Workstation (Z2 G1a) | Ryzen AI Max+ 395 | Mini workstation | Partial | Dashboard + core stack |
| Framework Desktop | Ryzen AI Max 385 / Max+ 395 | Desktop | Partial | Dashboard + core stack |
| ASUS TUF Gaming A14 | Ryzen AI Max+ 392 | Laptop | Partial | Dashboard + ASUS control |
| Sixunited AXP77 | Ryzen AI Max+ 395 | Mini-PC | Experimental | Dashboard + baseline stack |
| GMKtec EVO-X2 | Ryzen AI Max+ 395 | Mini-PC | Experimental | Dashboard + baseline stack |
| Minisforum MS-S1 Max | Ryzen AI Max+ 395 | Mini-PC | Experimental | Dashboard + baseline stack |
| AYANEO NEXT 2 | Ryzen AI Max+ 395 | Handheld | Experimental | Dashboard + baseline stack |
| GPD Win 5 | Ryzen AI Max+ 395 | Handheld | Experimental | Dashboard + baseline stack |
| Other Strix Halo | Ryzen AI MAX family | Laptop / Mini-PC / Handheld | Experimental baseline | Dashboard + baseline stack |

> Coverage labels: **Full stack** = dashboard + core fixes + ASUS control + the full GZ302 command-center surface; **Dashboard + ASUS control** = dashboard + core fixes + ASUS control on supported ASUS devices; **Dashboard + core stack** = dashboard + cross-device fixes, gaming, AI/ROCm, and integrations; **Dashboard + baseline stack** = the same dashboard-first path under experimental validation.
<!-- END:KNOWN_STRIX_HALO_DEVICE_TABLE -->

> **Note:** This list is a living compatibility matrix. Confidence levels:
> - *Full* — confirmed shipping, tested, all major features working  
> - *Partial* — confirmed hardware with a validated subset of surfaces; use the Coverage column for the exact supported paths  
> - *Experimental* — community-reported or early validation; coverage remains baseline until device-specific confirmation improves

---

## Known Bugs & Kernel Fixes (as of 2026-05-15)

| Issue | Affected kernels | Fix / Workaround | Resolved in |
|---|---|---|---|
| amdgpu VPE power-gate soft-lock on suspend (~8% of cycles) | < 6.18 | `VPE_IDLE_TIMEOUT` patch (landed 6.18) | 6.18+ |
| ROCm CWSR crash / VGPR instability | < 6.18 | `options amdgpu cwsr_enable=0` in `/etc/modprobe.d/` | 6.18+ |
| OLED PSR-SU / Panel Replay scrolling artifacts | All | `amdgpu.dcdebugmask=0x600` boot param | Workaround only |
| linux-firmware 20251125 breaks ROCm | All | Pin to ≥ 20260110 firmware | Firmware update |
| MT7925 WiFi ASPM instability | < 6.17 | `options mt7925e disable_aspm=1` modprobe | 6.17+ |
| ASUS HID tablet-mode input | < 6.17 | Udev rules + asus_nb_wmi workaround | 6.17+ |
| CS35L41 audio no-sound | < 6.19 | SOF firmware + modprobe quirk | 6.19+ |

---

## Adding New Integrations

To propose a new entry, open a GitHub issue with:
1. Project URL and description
2. Evidence of Strix Halo support (issue, PR, documentation, or benchmark)
3. Install method and distro support matrix
4. Trust level justification

All entries must include a verified last-tested date and a pinned version reference before being classified as `community-verified`.
