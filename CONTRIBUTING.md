# Contributing to GZ302-Linux-Setup

Thank you for your interest in contributing to the GZ302 Linux Setup project! This guide will help you contribute effectively.

## 🎯 Project Goals

**Repository Philosophy (v3.0.0+):** The GZ302 Toolkit has evolved from a "hardware enablement" tool into a "performance optimization and convenience toolkit" for modern Linux kernels.

- **Hardware-specific**: Focused on ASUS ROG Flow Z13 (GZ302EA-XS99) with AMD Ryzen AI MAX+ 395
- **Kernel-aware**: Automatically adapts to kernel versions (6.14-6.18+), applying only necessary fixes
- **Optimization focus**: Prioritizes performance tuning over hardware workarounds (for kernel 6.17+)
- **Equal distribution support**: Arch, Debian/Ubuntu, Fedora, and OpenSUSE receive identical treatment
- **Modular design**: Core optimizations separated from optional software modules
- **Quality focus**: Clean, maintainable bash scripts with proper error handling
- **Obsolescence handling**: Actively removes outdated workarounds that harm performance on modern kernels

## 🛠️ Development Setup

### Prerequisites

- A Linux system (preferably with one of the supported distributions)
- `bash` 4.0 or higher
- `shellcheck` for linting (recommended)
- `git` for version control

### Installing ShellCheck

```bash
# Arch-based
sudo pacman -S shellcheck

# Debian/Ubuntu-based
sudo apt install shellcheck

# Fedora-based
sudo dnf install ShellCheck

# OpenSUSE
sudo zypper install ShellCheck
```

## 📝 Code Style Guidelines

### AI/LLM & Copilot Rules

**MANDATORY for all AI interactions.** If you are using an AI assistant to generate or modify code, you MUST ensure it follows the strict mandates in [.github/copilot-instructions.md](.github/copilot-instructions.md). This includes rules on library-first architecture, versioning, and idempotency.

### Bash Script Standards
...
1. **Always use `set -euo pipefail`** at the start of scripts
2. **Quote all variables** to prevent word splitting: `"$variable"`
3. **Quote command substitutions**: `"$(command)"`
4. **Use `-r` flag with `read`**: `read -r -p "prompt: " variable`
5. **Separate variable declarations**:
   ```bash
   # Good
   local var
   var=$(command)
  
   # Avoid
   local var=$(command)  # Can mask return values
   ```
6. **Kernel-aware logic**: When adding hardware fixes, check if they're needed for all kernels:
   ```bash
   # Good - kernel-aware
   if [[ $kernel_version_num -lt 617 ]]; then
       apply_workaround
   else
       info "Native support available, skipping workaround"
   fi
  
   # Avoid - applying fixes unconditionally
   apply_workaround  # May harm performance on newer kernels
   ```

### Function Conventions

- Use descriptive function names with underscores: `install_arch_packages`
- Document complex functions with comments
- Return 0 for success, non-zero for errors
- Use `local` for function-scoped variables

### Output Messages

Use the helper functions consistently:
```bash
info "Informational message"
success "Success message"
warning "Warning message"
error "Error message (exits script)"
```

## 🧪 Testing Your Changes

### 1. Syntax Validation

**Required before committing:**
```bash
# Test individual script
bash -n strix-halo-setup.sh

# Test all scripts
find . -name "*.sh" -type f -print0 | xargs -0 -I{} bash -n "{}"
```

### 2. ShellCheck Linting

**Required before committing:**
```bash
# Lint individual script
shellcheck strix-halo-setup.sh

# Lint all scripts
find . -name "*.sh" -type f -print0 | xargs -0 shellcheck
```

**All scripts must pass with zero warnings.**

### 3. Device Detection Regression Script

**Recommended for hardware-profile changes:**
```bash
bash tests/device-manager-detection.sh
```

This covers the Strix Halo platform gate, known-device DMI aliases, generic fallback handling, and the ASUS command-center/z13ctl capability split.

### 4. Generated Content Sync

**Required when changing the supported-device matrix or profile metadata:**
```bash
bash scripts/sync-device-matrix.sh
git diff -- README.md strix-halo-setup.sh docs/technical/external-integrations-catalog.md
```

### 5. Version Consistency

**Required before committing:**
```bash
bash tests/validate-version-sync.sh
```

### 6. Distribution Testing

**Strongly recommended:**
Test your changes on all supported distributions:
- Arch Linux (or EndeavourOS, Manjaro)
- Ubuntu (or Pop!_OS, Linux Mint)
- Fedora (or Nobara)
- OpenSUSE Tumbleweed or Leap

You can use virtual machines or containers for testing.

## 🔀 Pull Request Process

1. **Fork the repository** and create a feature branch
2. **Make your changes** following the code style guidelines
3. **Test thoroughly**:
   - Run syntax validation: `bash -n script.sh`
   - Run shellcheck: `shellcheck script.sh`
    - Run device-profile regression checks when touching `strix-halo-lib/device-manager.sh`: `bash tests/device-manager-detection.sh`
    - Run generated-content sync when changing supported devices: `bash scripts/sync-device-matrix.sh`
    - Run version validation: `bash tests/validate-version-sync.sh`
   - Test on target hardware or VM if possible
4. **Commit with clear messages**:
   ```
   Add support for XYZ feature
  
   - Specific change 1
   - Specific change 2
   - Tested on: Arch Linux, Ubuntu 24.04
   ```
5. **Ensure equal distribution support**: If you add a feature, implement it for all 4 distributions
6. **Submit pull request** with:
   - Clear description of changes
   - Testing details (which distributions you tested)
   - Any known limitations or issues

## 📦 Module Development

When creating or modifying modules (`gz302-*.sh`):

1. **Follow the modular pattern**: Each module should be self-contained
2. **Include standard helpers**: Copy color codes and helper functions
3. **Support all distributions**: Implement for Arch, Debian, Fedora, OpenSUSE
4. **Add proper error handling**: Use `set -euo pipefail`
5. **Document usage**: Add comments explaining what the module does
6. **Consider kernel requirements**: Document minimum kernel version if applicable
7. **Distinguish fixes from optimizations**: Clearly label hardware workarounds vs performance tuning

### Module Template

```bash
#!/bin/bash

# ==============================================================================
# GZ302 [Module Name] Module
#
# Description of what this module does
# ==============================================================================

set -euo pipefail

# Color codes
C_BLUE='\033[0;34m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[0;31m'
C_NC='\033[0m'

# Helper functions
info() { echo -e "${C_BLUE}[INFO]${C_NC} $1"; }
success() { echo -e "${C_GREEN}[SUCCESS]${C_NC} $1"; }
warning() { echo -e "${C_YELLOW}[WARNING]${C_NC} $1"; }
error() { echo -e "${C_RED}[ERROR]${C_NC} $1"; exit 1; }

# Main installation function
install_module() {
    local distro="$1"
   
    case "$distro" in
        "arch") install_arch ;;
        "debian") install_debian ;;
        "fedora") install_fedora ;;
        "opensuse") install_opensuse ;;
        *) error "Unsupported distribution: $distro" ;;
    esac
}

# Distribution-specific functions
install_arch() {
    info "Installing for Arch-based system..."
    # Implementation
}

install_debian() {
    info "Installing for Debian-based system..."
    # Implementation
}

install_fedora() {
    info "Installing for Fedora-based system..."
    # Implementation
}

install_opensuse() {
    info "Installing for OpenSUSE..."
    # Implementation
}

# Entry point
if [[ $# -ne 1 ]]; then
    error "Usage: $0 <distro>"
fi

install_module "$1"
```

## 🐛 Bug Reports

When reporting bugs, please include:

1. **Distribution and version**: `cat /etc/os-release`
2. **Hardware info**: `lscpu`, `lspci` output
3. **Error messages**: Complete error output
4. **Steps to reproduce**: Exact commands you ran
5. **Expected vs actual behavior**: What should happen vs what happened

## 💡 Feature Requests

For new features:

1. **Check existing issues** to avoid duplicates
2. **Describe the use case**: Why is this feature needed?
3. **Hardware relevance**: Is it specific to GZ302 hardware?
4. **Distribution support**: Can it work on all 4 distributions?
5. **Kernel compatibility**: Does it require specific kernel versions?
6. **Type of feature**: Is it a hardware fix, optimization, or convenience tool?

### Feature Categories

**Hardware Fixes** (workarounds for broken hardware):
- Only add if hardware genuinely doesn't work without it
- Document kernel version where native support arrives
- Include obsolescence plan

**Optimizations** (performance tuning):
- Always safe to apply, even if benefits are small
- Examples: GTT size for AI workloads, power profiles

**Convenience Tools** (quality of life):
- Wrappers around existing tools (asusctl, etc.)
- GUI utilities, system tray integrations
- The core of the "toolkit" philosophy

## � Versioning (MANDATORY)

**ALL changes require a version bump** following semantic versioning (MAJOR.MINOR.PATCH):

### When to Bump Versions

- **PATCH (X.X.+1)**: Bug fixes, documentation updates, minor improvements, dependency updates, typo fixes
- **MINOR (X.+1.0)**: New features, new hardware support, module additions, non-breaking enhancements
- **MAJOR (+1.0.0)**: Breaking changes, major architecture changes, incompatible API changes

### Version Update Workflow

**REQUIRED for EVERY change** - follow this exact order:

1. **Update root `VERSION` file FIRST**
   ```bash
   echo "5.1.2" > VERSION
   ```

2. **Sync to ALL locations** (use search/replace to ensure consistency):
   - `strix-halo-setup.sh` — Header: `# Version: 5.1.2` + help text version display
   - `strix-halo-lib/*.sh` — All library files: `# Version: 5.1.2`
   - `modules/*.sh` — All modules: `# Version: 5.1.2`
   - `command-center/VERSION` — `5.1.2`
   - `command-center/src/command_center.py` — Update About dialog version string
   - `pkg/arch/PKGBUILD` — `pkgver=5.1.2`
   - `README.md` — Update any version badges or references
   - `docs/CHANGELOG.md` — Add new version entry with changes

3. **Verify version sync**:
   ```bash
   # Check all version headers match
   grep -rn "Version:" strix-halo-setup.sh strix-halo-lib/ modules/ | grep -v "Kernel Version"
   cat VERSION command-center/VERSION
   grep "pkgver=" pkg/arch/PKGBUILD
   ```

4. **Commit with version in message**:
   ```bash
   git add -A
   git commit -m "Bump version to 5.1.2: Fix tray icon SVG rendering"
   ```

### Examples

- Fixed a bug? → PATCH: `5.1.1` → `5.1.2`
- Added a new module? → MINOR: `5.1.2` → `5.2.0`
- Changed installer architecture? → MAJOR: `5.2.0` → `6.0.0`
- Updated documentation only? → PATCH: `5.1.2` → `6.0.0`
- Fixed typo in comments? → PATCH: `6.0.0` → `6.0.0`

**NO exceptions** - every merged change must increment the version number.

## 📚 Documentation

When updating documentation:

1. **Keep README.md user-focused**: Installation and usage instructions
2. **Update version numbers** per the Versioning section above
3. **Use clear examples**: Show actual commands users would run
4. **Maintain consistency**: Follow existing formatting and style

## ✅ Checklist Before Submitting

- [ ] **Version bumped** in root `VERSION` file and synced to all locations
- [ ] **CHANGELOG.md updated** with version entry and changes
- [ ] Code passes `bash -n` syntax check
- [ ] Code passes `shellcheck` with zero warnings
- [ ] Changes tested on at least one supported distribution
- [ ] All 4 distributions have equivalent implementation
- [ ] Documentation updated if needed
- [ ] Commit messages are clear and descriptive
- [ ] Commit includes version number: "Bump version to X.Y.Z: Description"
- [ ] No sensitive data (credentials, personal info) in commits

## 🤝 Code Review

All contributions go through code review:

- Maintainers will review for code quality, security, and compatibility
- Feedback will be provided constructively
- You may be asked to make changes before merging
- Be patient - reviews may take a few days

## 📞 Getting Help

- **Questions**: Open a GitHub issue with the "question" label
- **Discussion**: Use GitHub Discussions for general topics
- **Security issues**: Report privately to the maintainer

## 📜 License

By contributing, you agree that your contributions will be provided as-is for the GZ302 community, matching the project's license.

---

**Thank you for helping make GZ302 Linux Setup better!** 🎉
