# GZ302 Component Obsolescence Analysis (April 2026)

## Executive Summary

This document analyzes the obsolescence status of GZ302-Linux-Setup components as of April 2026, based on upstream Linux kernel support evolution (6.14-6.19+). The repository has fully transitioned from a **hardware enablement tool** (fixing broken hardware) to a **performance optimization toolkit** (tuning working hardware).

As the repository broadens toward Strix Halo platform support, hardware-fix, AI/LLM, and ASUS control-stack paths must remain gated behind confirmed Strix Halo CPU/GPU signatures. The known-device matrix now lives in `strix-halo-lib/device-profile-data.sh`, and the device manager uses that allowlisted DMI vendor/product/family/board metadata before falling back to CPU/GPU signatures for unknown devices. This reduces false positives without shrinking the supported Strix Halo matrix. The generated device matrix now also derives a support-coverage label from those same capabilities so user-facing docs can distinguish full-stack, dashboard-first core-stack, and baseline support without overstating vendor-specific ASUS control coverage. The generic Strix Halo dashboard now applies to all confirmed Strix Halo devices, while z13ctl-backed control surfaces remain explicitly gated to validated ASUS profiles.

**Last Updated:** May 17, 2026 
**Analysis Period:** Early 2025 (Kernel 6.14) → April 2026 (Kernel 6.19+) 
**Target Hardware:** ASUS ROG Flow Z13 (GZ302EA-XS99/XS98/XS96)

---

## Kernel Evolution Timeline

### Linux 6.14 (Early 2025)
- **Status:** Initial Strix Halo support
- **Issues:** Graphics corruption, WiFi jitter, missing tablet mode
- **Repository Role:** **MANDATORY** - Device unusable without workarounds

### Linux 6.15-6.16 (Mid 2025)
- **Status:** Stability improvements
- **Features:** Graphics fixes (Mesa 25.2), SmartMux support
- **Repository Role:** **HIGHLY RECOMMENDED** - WiFi and input fixes still needed

### Linux 6.17 (September 2025)
- **Status:** Production-ready GZ302 support
- **Features:** asus-wmi tablet mode, MT7925 performance fixes, native sensor support
- **Repository Role:** **CONTEXTUAL** - Hardware works, optimization valuable

### Linux 6.18 (Late 2025)
- **Status:** Enhanced hardware monitoring
- **Features:** asus-ec-sensors support, improved thermal management
- **Repository Role:** **OPTIMIZATION ONLY** - Focus on performance tuning

### Linux 6.19 (Q1 2026)
- **Status:** Native CS35L41 amplifier support merged
- **Features:** GZ302 subsystem ID (`1043:1fb3`) native quirk upstreamed; cs35l41_hda bridge driver auto-loads without manual `softdep`
- **Repository Role:** **OPTIMIZATION ONLY** - All hardware workarounds fully obsolete

---

## Component-by-Component Analysis

### 1. WiFi (MediaTek MT7925)

#### Repository Implementation (strix-halo-setup.sh)
```bash
# Applies modprobe configuration
options mt7925e disable_aspm=1
```

#### Upstream Status
| Kernel | Status | Native Support | Action Required |
|--------|--------|----------------|-----------------|
| 6.14-6.15 | Jitter issues | ❌ No | **Apply workaround** |
| 6.16 | Improved | ⚠️ Partial | **Apply workaround** |
| 6.17+ | Production | ✅ Yes | **Remove workaround** |

**Analysis:**
- **Kernels < 6.17:** WiFi driver has packet loss and high jitter due to aggressive ASPM
- **Kernels >= 6.17:** Native L1/L0 PCIe state transitions fixed, ASPM works correctly
- **Impact:** Applying workaround on 6.17+ **downgrades** driver and **harms battery life**

**Verdict:** **OBSOLETE for Kernel 6.17+** | **HARMFUL if applied unnecessarily**

**Recommendation:**
- Conditional application based on kernel version detection
- Ensure latest `linux-firmware` package installed (September 2025+)

---

### 2. Input & Tablet Mode (ASUS WMI)

#### Repository Implementation
- `gz302-tablet.sh` - Userspace daemon polling sensors
- `options hid_asus enable_touchpad=1` - Force touchpad detection
- Manual screen rotation via `xrandr`/`wlr-randr`

#### Upstream Status
| Kernel | Status | Native Support | Action Required |
|--------|--------|----------------|-----------------|
| 6.14-6.16 | No ACPI events | ❌ No | **Use daemon** |
| 6.17+ | SW_TABLET_MODE | ✅ Yes | **Remove daemon** |

**Analysis:**
- **Kernels < 6.17:** No kernel broadcast of tablet mode events
- **Kernels >= 6.17:** Commit "platform/x86: asus-wmi: Fix ROG button mapping, tablet mode on ASUS ROG Z13" merged
- **Mechanism:** Kernel emits `SW_TABLET_MODE` input event, desktop environments respond automatically
- **Conflict:** Userspace daemon + kernel events cause screen rotation "fighting"

**Verdict:** **OBSOLETE for Kernel 6.17+** | **Creates conflicts if used**

**Integration:**
- GNOME 49+ and KDE Plasma 6 natively support `SW_TABLET_MODE`
- `iio-sensor-proxy` reads accelerometer orientation correctly
- No manual intervention needed

---

### 3. Audio (Cirrus Logic CS35L41)

#### Repository Implementation
```bash
# /etc/modprobe.d/cs35l41.conf
# cs35l41_hda is the ASoC bridge driver for these amps via ACPI/I2C.
# Ensures the HDA bus (snd_hda_intel) is ready before the amp driver loads.
softdep snd_hda_intel post: cs35l41_hda
```

#### Upstream Status
| Kernel | Status | Native Support | Action Required |
|--------|--------|----------------|-----------------|
| 6.14-6.18 | Missing quirk | ❌ No | **Apply softdep patch** |
| 6.19+ | Native support | ✅ Yes | **Remove config** |

**Analysis:**
- **Kernels 6.14-6.18:** GZ302 subsystem ID (`1043:1fb3`) missing from upstream quirk list; `softdep snd_hda_intel post: cs35l41_hda` required
- **Kernel 6.19+:** GZ302 CS35L41 quirk merged upstream — `strix-halo-setup.sh` auto-removes the modprobe config when detected
- **Distribution Impact:** Fedora 44+, Ubuntu 26.04+, Arch rolling (post-April 2026) ship 6.19+

**Verdict:** **OBSOLETE for Kernel 6.19+** | **Auto-removed by strix-halo-setup.sh**

**Note:** CachyOS with `linux-g14` patchset included this quirk earlier (6.17+)

---

### 4. Graphics & AI (Strix Halo Memory Management)

#### Repository Implementation
```bash
# GRUB kernel parameters
amdgpu.gttsize=131072  # 128MB Graphics Translation Table
amd_iommu=off          # Disable IOMMU for lower latency
```

#### Upstream Status
| Use Case | Kernel Support | Optimization Needed | Impact |
|----------|----------------|---------------------|--------|
| Desktop/Gaming | 6.16+ stable | ❌ No | Obsolete for general use |
| AI/LLM Workloads | 6.16+ stable | ✅ Yes | **Valid for performance** |

**Analysis:**

**General Computing (Desktop/Gaming):**
- **Stability:** Kernel 6.16+ handles memory management without crashes
- **SmartMux:** Native power gating eliminates need for manual tweaks
- **Verdict:** **OBSOLETE for general users**

**AI/LLM Workloads:**
- **Default Limitation:** Conservative GTT aperture size limits memory addressability
- **Large Model Loading:** 40GB+ models cause allocation failures with default settings
- **Performance:** Increased GTT size improves throughput for unified memory architecture
- **Verdict:** **VALID (RECOMMENDED) for AI users**

**Recommendation:**
- Default installation: Skip GTT resize
- LLM/AI module installation: Apply GTT optimization
- Document as **performance tuning**, not **stability fix**

---

### 5. Power Management & RGB

#### Repository Implementation
- `pwrcfg` - TDP profile switching (10W-90W)
- `rrcfg` - Refresh rate control (30Hz-180Hz)
- `gz302-rgb` - Keyboard backlight control
- System tray integration

#### Upstream Status
**These are userspace optimization tools, not hardware fixes**

**Analysis:**
- **Functionality:** Wrappers around `asusctl`, `power-profiles-daemon`
- **Value Proposition:** Convenient power profile management specific to GZ302 thermal envelope
- **Dependency:** Requires `asusctl` which is distribution-packaged
- **Category:** User convenience, not hardware enablement

**Verdict:** **VALID (VALUABLE)** | **Core toolkit functionality**

**Positioning:** These tools represent the **future direction** of the repository:
- Not fixing broken hardware
- Optimizing working hardware
- Providing GZ302-specific convenience

---

## Distribution-Specific Guidance

### Fedora 43 (Kernel 6.17+)
**Obsolete Components:**
- ✅ WiFi workarounds (native support)
- ✅ Tablet mode daemon (native support)
- ✅ Input forcing (native support)

**Required Components:**
- ⚠️ Audio quirks (still needed)
- ✅ Power management tools (valuable)
- ✅ AI optimizations (if using LLMs)

**Recommendation:** Minimal hardware fixes + toolkit utilities

---

### Ubuntu 26.04 (Kernel 6.19+)
**Obsolete Components:**
- ✅ WiFi workarounds (native support)
- ✅ Tablet mode daemon (native support)
- ✅ Input forcing (native support)
- ✅ Audio quirks (native CS35L41 support)

**Required Components:**
- ✅ Power management tools (valuable)
- ✅ AI optimizations (if using LLMs)

**Additional Consideration:**
- Verify `linux-firmware` is current if MT7925 behavior lags your kernel rollout

**Recommendation:** Toolkit utilities only (pwrcfg, rrcfg, RGB)

---

### Arch Linux / CachyOS (Kernel 6.19+)
**Obsolete Components:**
- ✅ All hardware workarounds (rolling release ships 6.19+)
- ✅ Audio quirks (native CS35L41 support in 6.19+)

**CachyOS Specific:**
- `linux-g14` or `linux-cachyos` kernels likely include audio quirks
- Test audio before applying DSDT patch
- ROCm packages optimized for Zen 4/5

**Recommendation:** Toolkit utilities only (pwrcfg, rrcfg, RGB)

---

### OpenSUSE Tumbleweed (Kernel 6.18+)
**Status:** Similar to Arch (rolling release)

**Package Availability:**
- `asusctl` may require OBS repository
- `switcheroo-control` usually in default repos

---

## Transition Strategy for Existing Users

### If You Installed Before September 2025 (Kernel < 6.17)

**Your system has obsolete workarounds that may harm performance/battery:**

1. **Check your kernel:** `uname -r`
2. **If >= 6.17, remove obsolete components:**
   ```bash
   # Remove WiFi ASPM workaround
   sudo rm -f /etc/modprobe.d/mt7925.conf
  
   # Disable tablet mode daemon (if installed)
   sudo systemctl disable --now gz302-tablet.service
  
   # Remove input forcing
   sudo sed -i '/enable_touchpad=1/d' /etc/modprobe.d/hid-asus.conf
  
   # Reload modules
   sudo modprobe -r mt7925e && sudo modprobe mt7925e
   sudo modprobe -r hid_asus && sudo modprobe hid_asus
   ```

3. **Keep valid components:**
   - Audio quirks (still needed)
   - `pwrcfg` and `rrcfg` tools
   - RGB control
   - AI optimizations (if used)

4. **Reboot to apply changes**

---

### Fresh Installation (April 2026+)

**Use kernel-aware installation:**

The updated `strix-halo-setup.sh` script now detects your kernel version and applies **only necessary fixes**.

**What happens automatically:**
- Kernel < 6.17: Full hardware workarounds applied
- Kernel 6.17-6.18: Only audio quirks + optimizations
- Kernel 6.19+: **No hardware workarounds needed** — all obsolete configs auto-removed
- User choice: Toolkit utilities (pwrcfg, rrcfg, RGB via z13ctl)

---

## Future Repository Direction

### The "GZ302 Toolkit" Philosophy

**OLD (Early 2025):**
- "Make Linux work on GZ302"
- Focus: Hardware enablement
- Necessity: High (device unusable without)

**NEW (Late 2025):**
- "Optimize GZ302 for Linux"
- Focus: Performance tuning, convenience
- Necessity: Low (device works, toolkit enhances)

### Remaining Value Propositions

1. **Power Management:** GZ302-specific TDP profiles (10W-90W range) via z13ctl
2. **AI/LLM Optimization:** Strix Halo memory tuning for large models
3. **RGB Control:** Keyboard backlight convenience via z13ctl
4. **Distribution Parity:** Equal support across Arch/Debian/Fedora/OpenSUSE
5. **AMD P-State:** Automated `amd_pstate=guided` bootloader configuration (GRUB, systemd-boot, Limine v4/v5, and `/etc/default/limine`-managed installs)

### Obsolescence as Success

**The obsolescence of hardware fixes represents the success of the Linux community:**
- Kernel developers integrated GZ302 support upstream
- Distribution maintainers ship modern kernels
- The repository evolved from necessity to convenience

---

## Technical Details: Kernel Commits

### Key Upstream Commits (Kernel 6.17)

**asus-wmi Tablet Mode:**
```
commit: [TBD - platform/x86: asus-wmi branch]
Author: Linux kernel developers
Date: September 2025
Title: platform/x86: asus-wmi: Fix ROG button mapping, tablet mode on ASUS ROG Z13

Changes:
- Updated ACPI event mapping for GZ302 sensor hub
- Enabled SW_TABLET_MODE broadcast
- Fixed keyboard detachment detection
```

**mt7925e WiFi Performance:**
```
commit: [TBD - wireless-next branch]
Author: MediaTek engineers
Date: August-September 2025
Title: wifi: mt7925: Fix ASPM L1/L0 state transitions

Changes:
- Corrected PCIe power state handling
- Eliminated jitter in active transfers
- Enabled battery-friendly power saving
```

### Distribution Kernel Adoption Timeline

| Distribution | Kernel Version | Release Date | GZ302 Status |
|--------------|----------------|--------------|--------------|
| Arch Linux | 6.19.x | April 2026 | ✅ Full native support |
| Fedora 44 | 6.19.x | Q2 2026 | ✅ Full native support |
| Ubuntu 26.04 | 6.19.x | April 2026 | ✅ Full native support |
| OpenSUSE TW | 6.19.x | April 2026 | ✅ Full native support |

---

## Validation & Testing

### How to Verify Your System Needs

**Test 1: WiFi Performance (Check if workaround needed)**
```bash
# Check current configuration
cat /etc/modprobe.d/mt7925.conf 2>/dev/null

# Test WiFi stability (run for 5 minutes)
ping -c 300 -i 1 8.8.8.8 | awk '{ print $7 }' | grep time=
# Look for consistent <50ms times (good)
# High variance or >100ms indicates problems
```

**Test 2: Tablet Mode (Check if kernel handles it)**
```bash
# Monitor input events
evtest | grep -i tablet
# Expected on 6.17+: SW_TABLET_MODE events when detaching keyboard
# If no events, kernel support missing
```

**Test 3: Audio (Check if quirk needed)**
```bash
# Test speaker output
speaker-test -t wav -c 2
# If no sound + dmesg shows "Failed to sync masks", quirk needed
```

---

## Glossary

**ASPM:** Active State Power Management - PCIe link power saving 
**GTT:** Graphics Translation Table - GPU memory address mapping 
**SW_TABLET_MODE:** Kernel input event for 2-in-1 convertible state 
**CS35L41:** Cirrus Logic audio amplifier chip 
**DSDT:** Differentiated System Description Table (ACPI firmware table) 
**asus-wmi:** ASUS Windows Management Instrumentation driver (Linux) 
**Strix Halo:** AMD codename for Ryzen AI MAX+ 395 APU architecture

---

## References

- **Kernel Git:** https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
- **Linux Firmware:** https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git
- **ASUS Linux Community:** https://asus-linux.org
- **Phoronix Kernel Coverage:** https://phoronix.com (Kernel 6.17 announcement)
- **Repository Research:** `Info/KERNEL_RESEARCH_SUMMARY_2025.md`

---

**Document Maintenance:** This document should be updated when:
- New kernel versions change GZ302 support status
- Upstream merges audio quirks (CS35L41)
- Distribution kernel versions significantly change
- New hardware workarounds are discovered/deprecated

**Version:** 4.0.0 (April 4, 2026)
