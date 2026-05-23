# GZ302 Documentation

Documentation for the ASUS ROG Flow Z13 (GZ302) Linux Setup project.

## Quick Links

| Document | Description |
|----------|-------------|
| [Kernel Support](technical/kernel-support.md) | Kernel compatibility matrix, troubleshooting |
| [AI/ML Packages](technical/ai-ml-packages.md) | ROCm, Ollama, PyTorch setup |
| [ROCm Support](technical/rocm-support.md) | ROCm 7.1.1 configuration |
| [Testing Guide](testing-guide.md) | How to test changes |
| [Changelog](CHANGELOG.md) | Version history |
| [Obsolescence Analysis](technical/obsolescence-analysis.md) | Component lifecycle status |

## Hardware Specifications

**ASUS ROG Flow Z13 (GZ302EA-XS99)**
- **CPU:** AMD Ryzen AI MAX+ 395 (16 cores, 32 threads)
- **GPU:** AMD Radeon 8060S (RDNA 3.5, 40 CUs)
- **NPU:** AMD XDNA (50 TOPS)
- **RAM:** 128GB LPDDR5X (unified memory)
- **WiFi:** MediaTek MT7925e (Wi-Fi 7)
- **Display:** 13.4" 2.5K 180Hz OLED touchscreen

## Supported Distributions

| Distribution | Kernel | Support Level |
|--------------|--------|---------------|
| Arch Linux | 6.17+ | ✅ Full |
| CachyOS | 6.18+ | ✅ Full |
| Fedora 43 | 6.17+ | ✅ Full |
| OpenSUSE TW | 6.17+ | ✅ Full |
| Ubuntu 26.04 | 6.19+ | ✅ Full |

> [!NOTE]
> Ubuntu 24.04.4 remains usable with the 6.17 HWE kernel. See [Kernel Support](technical/kernel-support.md) for the full Ubuntu matrix.

## Repository Structure

```text
GZ302-Linux-Setup/
├── strix-halo-setup.sh         # Unified installer (v6.8.0)
├── strix-halo-lib/             # Shared bash libraries
├── modules/               # Optional modules (gaming, AI, hypervisor)
├── scripts/               # Standalone tools & utilities
│   └── uninstall/         # Cleanup scripts
├── command-center/        # Python/Qt6 system tray app
├── pkg/arch/              # Arch Linux PKGBUILD
└── docs/                  # Documentation (you are here)
```

## Updating

To pull the latest fixes and apply them:

```bash
cd GZ302-Linux-Setup
git pull
sudo bash strix-halo-setup.sh
```

> [!NOTE]
> Some fixes (like suspend hooks) are installed to system paths and require re-running the installer to update.

## Getting Help

1. Check [Kernel Support](kernel-support.md) for compatibility issues
2. See [Testing Guide](testing-guide.md) for diagnostic commands
3. Open an issue: [GitHub Issues](https://github.com/th3cavalry/strix-halo-linux-setup/issues)
