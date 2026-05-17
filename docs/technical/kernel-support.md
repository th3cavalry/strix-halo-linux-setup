# GZ302 Kernel Support Guide

**Target Hardware:** ASUS ROG Flow Z13 (GZ302EA-XS99/XS98/XS96) with AMD Ryzen AI MAX+ 395  
**Last Updated:** May 2026  
**Kernel Range:** 6.14 - 7.0+

---

## Quick Reference

### Check Your Kernel
```bash
uname -r  # Example: 6.19.0-2-cachyos
```

### Support Level by Version

| Kernel | Status | Required Fixes |
|--------|--------|----------------|
| < 6.14 | ❌ Unsupported | Upgrade required |
| 6.14-6.15 | ⚠️ Early | All hardware fixes needed |
| 6.16 | ⚠️ Maturing | Most fixes needed |
| 6.17-6.18 | ✅ Production | Audio quirk only |
| 6.19+ | ✅ Optimal | Minimal fixes, all native |
| 7.0+ | ✅ Optimal | Tuning-focused; verify display mask if artifacts persist |

---

## Component Compatibility Matrix

### Hardware Fixes

| Component | 6.14-6.15 | 6.16 | 6.17-6.18 | 6.19+ | Notes |
|-----------|-----------|------|-----------|-------|-------|
| WiFi (MT7925) | ✅ Required | ✅ Required | ❌ Native | ❌ Native | ASPM workaround obsolete |
| Tablet Mode | ✅ Required | ✅ Required | ❌ Native | ❌ Native | SW_TABLET_MODE in kernel |
| Input/Touchpad | ✅ Required | ⚠️ Optional | ❌ Native | ❌ Native | hid_asus reliable |
| Audio (CS35L41) | ✅ Required | ✅ Required | ✅ Required | ❌ Native | Quirk upstreamed in 6.19 |
| GPU Stability | ✅ Required | ❌ Native | ❌ Native | ❌ Native | Stable in 6.16+ |
| Suspend/MMC | ⚠️ Issue | ⚠️ Issue | ⚠️ Issue | ⚠️ Issue | See Suspend Fix below |

### Userspace Tools (All Kernels)

| Tool | Purpose | Necessity |
|------|---------|-----------|
| pwrcfg | TDP profile management | Optional (convenience) |
| rrcfg | Display refresh control | Optional (convenience) |
| gz302-rgb | Keyboard backlight | Optional (convenience) |

---

## Distribution Status

| Distribution | Kernel | GZ302 Ready |
|--------------|--------|-------------|
| **Arch Linux** | 6.18+ | ✅ Excellent |
| **CachyOS** | 6.19+ | ✅ Excellent |
| **Fedora 43** | 6.17+ | ✅ Excellent |
| **OpenSUSE TW** | 6.18+ | ✅ Excellent |
| **Ubuntu 24.04.4** | 6.17 (HWE) | ✅ Excellent |
| **Ubuntu 26.04** | 7.0+ | ✅ Excellent |

### Ubuntu Kernel Upgrade
```bash
sudo apt-get update
sudo apt-get install linux-generic-hwe-24.04  # Gets 6.17+
```

---

## Kernel 6.17+ Configuration

### Required Kernel Parameters
```
amd_pstate=guided amdgpu.ppfeaturemask=0xffff7fff
```

### AI/LLM Workloads (Optional)
```
amdgpu.gttsize=131072 amd_iommu=off
```

### What Works Natively
- ✅ WiFi with power saving
- ✅ Tablet mode detection
- ✅ Touchpad/keyboard
- ✅ GPU stability
- ✅ Accelerometer orientation
- ✅ Audio (CS35L41) - Native in 6.19+

### What Still Needs Fixes
- ⚠️ Suspend/MMC timeout (see fix below)
- ⚠️ Audio (CS35L41 quirk) - Only for kernel < 6.19

---

## Suspend Fix (MMC Timeout)

The internal eMMC/SD card (mmcblk0) may cause suspend to fail with:
```
mmc0: error -110 writing Power Off Notify bit
```

This is a known kernel MMC driver issue. Apply the fix:

```bash
# Quick fix
bash scripts/fix-suspend.sh

# Or rerun the main installer (reinstalls the suspend hook)
sudo bash strix-halo-setup.sh --fixes-only
```

The fix unbinds the MMC device before suspend and rebinds it on resume.
The suspend hook works without `amd_pmc.enable_stb=1`; this toolkit no longer recommends that parameter as a general Strix Halo requirement.

---

## Migration from Pre-6.17

If you installed GZ302 setup before kernel 6.17, remove obsolete components:

```bash
# Check kernel version
uname -r

# If >= 6.17, clean up:
sudo rm -f /etc/modprobe.d/mt7925.conf
sudo systemctl disable --now gz302-tablet.service 2>/dev/null
sudo sed -i '/enable_touchpad=1/d' /etc/modprobe.d/hid-asus.conf

# Reload modules
sudo modprobe -r mt7925e && sudo modprobe mt7925e
sudo modprobe -r hid_asus && sudo modprobe hid_asus
```

---

## Troubleshooting

| Symptom | Kernel < 6.17 | Kernel 6.17+ | Kernel 6.19+ |
|---------|---------------|--------------|---------------|
| WiFi drops | Apply ASPM workaround | Update linux-firmware | Native |
| No rotation | Install tablet daemon | Check DE support | Native |
| No touchpad | Apply input forcing | Reload hid_asus | Native |
| No audio | Apply audio quirk | Apply audio quirk | Native |
| GPU crashes | Apply GTT fix | Should be stable | Native |
| Suspend fails | Apply MMC fix | Apply MMC fix | Apply MMC fix |
| Intermittent OLED artifacts/flicker while scrolling | Apply display fix (`dcdebugmask`) | Use `amdgpu.dcdebugmask=0x600` on all supported kernels in a **single-line** `/etc/kernel/cmdline` (systemd-boot), GRUB cmdline, or Limine config | Same guidance applies |

### Display Fix Validation

On systemd-boot systems, `/etc/kernel/cmdline` must be a single line. If display parameters were appended on a separate line by older tooling, the fix may not apply reliably.

The installer now normalizes its managed display bits instead of only OR-ing them.

All supported kernels use `amdgpu.dcdebugmask=0x600` (PSR-SU + Panel Replay disabled). The previously used `0xe12` mask was found to break s2idle suspend on kernel 6.x — the side LED keeps cycling and the battery drains during sleep.

If an older `amdgpu.dcdebugmask=` value already exists, the installer rewrites the toolkit-managed bits to the current target and regenerates boot artifacts automatically. If you changed cmdline manually, rebuild once yourself:

```bash
# Arch/CachyOS (mkinitcpio)
sudo mkinitcpio -P

# Fedora/OpenSUSE style (dracut)
sudo dracut --regenerate-all -f
```

```bash
cat /etc/kernel/cmdline
# Expected to include (same line):
# ... amdgpu.dcdebugmask=0x600 ...
```

On Limine-managed systems, the installer updates `/etc/default/limine` when present and regenerates entries via `limine-update` or `limine-mkinitcpio`.

---

## Hardware Feature Support by Kernel

| Feature | 6.14 | 6.15 | 6.16 | 6.17 | 6.18 | 6.19+ |
|---------|------|------|------|------|------|-------|
| AMD XDNA NPU | Basic | Extended | Enhanced | Optimized | Optimized | Optimized |
| AMD P-State | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| MT7925 WiFi | ⚠️ Workaround | Native | Native | Optimized | Optimized | Optimized |
| Radeon 8060S | Basic | Enhanced | Better | Optimized | Optimized | Optimized |
| Power Mgmt | ✅ | ✅ | ✅ | ✅ Fine-grain | ✅ | ✅ |
| CS35L41 Audio | ⚠️ Quirks | ⚠️ Quirks | ⚠️ Quirks | ⚠️ Quirks | ⚠️ Quirks | ✅ Native |
| ROCm 7.2 (gfx1151) | ❌ | ❌ | ❌ | ❌ | ✅ Native | ✅ Native |

---

## References

- [Kernel.org Releases](https://www.kernel.org/releases.html)
- [ASUS Linux Community](https://asus-linux.org)
- [GZ302 Repository](https://github.com/th3cavalry/GZ302-Linux-Setup)
