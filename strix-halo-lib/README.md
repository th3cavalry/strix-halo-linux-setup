# GZ302 Library Directory

This directory contains modular library files that implement the "Library-First" design pattern for the GZ302 Linux Toolkit.

## Architecture Philosophy

**Traditional Approach (Monolithic):**
```bash
# Big script that does everything
detect_hardware()
apply_all_fixes()
verify_everything()
```

**Library-First Approach (Modular):**
```bash
# Separate libraries for each subsystem
source strix-halo-lib/wifi-manager.sh
source strix-halo-lib/audio-manager.sh
source strix-halo-lib/input-manager.sh

# Detection separate from application
wifi_detect_hardware
wifi_check_state
wifi_apply_configuration
wifi_verify_working
```

## Design Principles

1. **Separation of Concerns:** Detection, configuration, and verification are separate functions
2. **Idempotency:** Safe to run multiple times - checks before applying
3. **Kernel-Aware:** Adapts configuration based on kernel version
4. **State-Aware:** Knows what's already applied, doesn't duplicate work
5. **Testable:** Each function can be tested independently
6. **Maintainable:** Small, focused libraries easier to understand and modify

## Current Libraries

All libraries are **complete and tested**. They follow the same pattern:
- `*_detect_*()` - Detection functions (read-only)
- `*_apply_*()` - Configuration functions (idempotent)
- `*_verify_*()` - Verification functions
- `*_print_status()` - Status display

### Core Libraries

| Library | Purpose | Status |
|---------|---------|--------|
| `kernel-compat.sh` | Kernel version detection and compatibility checks | ✅ Complete |
| `state-manager.sh` | State tracking, backups, rollback support | ✅ Complete |
| `wifi-manager.sh` | MediaTek MT7925e WiFi configuration | ✅ Complete |
| `gpu-manager.sh` | AMD Radeon 8060S GPU configuration | ✅ Complete |
| `input-manager.sh` | Touchpad, keyboard, tablet mode | ✅ Complete |
| `audio-manager.sh` | CS35L41 speakers, SOF audio | ✅ Complete |

### Feature Libraries (v6.0.0)

| Library | Purpose | Status |
|---------|---------|--------|
| `display-manager.sh` | Refresh rate profiles, VRR (rrcfg) | ✅ Complete |

> **Note:** Power and RGB control are now handled by [z13ctl](https://github.com/dahui/z13ctl). The old `power-manager.sh` and `rgb-manager.sh` have been removed.

## Library Usage

### wifi-manager.sh
Manages the MediaTek MT7925e WiFi controller.

**Key Functions:**
- `wifi_detect_hardware()` - Check if WiFi hardware present
- `wifi_requires_aspm_workaround()` - Check if kernel needs workaround
- `wifi_apply_configuration()` - Apply kernel-appropriate config
- `wifi_verify_working()` - Verify WiFi is functional
- `wifi_print_status()` - Display formatted status

### display-manager.sh
Manages display refresh rates and VRR.

**Key Functions:**
- `display_detect_outputs()` - List connected displays
- `display_apply_profile()` - Apply refresh rate profile
- `display_vrr_enable/disable()` - VRR control
- `display_get_current_refresh()` - Get current refresh rate
- `display_print_status()` - Display status
- `display_get_rrcfg_script()` - Get rrcfg CLI script content

**Supports:** X11 (xrandr), Wayland (wlr-randr), KDE (kscreen-doctor)

## Benefits of Library-First Design

### For Users
- **Faster Execution:** Skip already-applied fixes (idempotency)
- **Selective Control:** Apply/remove individual components
- **Clear Status:** See exactly what's configured
- **Less Risk:** Smaller changes, easier to rollback

### For Developers
- **Easier Testing:** Test individual functions in isolation
- **Simpler Debugging:** Smaller code units easier to understand
- **Better Collaboration:** Multiple people can work on different libraries
- **Code Reuse:** Libraries can be used by multiple scripts

### For Maintainers
- **Reduced Complexity:** 3961-line monolith → multiple 200-300 line libraries
- **Easier Updates:** Change one library without touching others
- **Better Documentation:** Each library self-contained with clear API
- **Sustainable Growth:** Add new hardware support without growing monolith

## Migration Strategy

### Phase 1: Proof of Concept ✅ Complete
✅ Create wifi-manager.sh as reference implementation  
✅ Document architecture and design principles  
✅ Validate concept with community

### Phase 2: Core Libraries ✅ Complete
✅ Extract audio logic → audio-manager.sh
✅ Extract input logic → input-manager.sh
✅ Extract GPU logic → gpu-manager.sh
✅ Create kernel-compat.sh for version checking

### Phase 3: State Management ✅ Complete
✅ Create state-manager.sh
✅ Implement state tracking in /var/lib/gz302/state/
✅ Add rollback capabilities
✅ Integrate state checks into all libraries

### Phase 4: Feature Libraries ✅ Complete
✅ Create display-manager.sh for refresh rate control
✅ Power & RGB migrated to z13ctl (external backend)

### Phase 5: Unified Installer ✅ Complete
✅ strix-halo-setup.sh replaces all old entry points
✅ z13ctl installed as hardware control backend
✅ All libraries integrated into strix-halo-setup.sh

## Usage Examples

### Basic Detection
```bash
source strix-halo-lib/wifi-manager.sh

if wifi_detect_hardware >/dev/null 2>&1; then
    echo "WiFi hardware found"
    wifi_get_state | jq .
fi
```

### Power & RGB (via z13ctl)
```bash
# Power and RGB are now controlled via z13ctl:
z13ctl profile --set balanced
z13ctl apply --color red --mode static
z13ctl off
```

### Apply Configuration
```bash
source strix-halo-lib/wifi-manager.sh

# Apply appropriate config for kernel version
wifi_apply_configuration

# Verify it worked
if wifi_verify_working; then
    echo "WiFi configured successfully"
fi
```

### Check Status
```bash
source strix-halo-lib/wifi-manager.sh

# Display formatted status
wifi_print_status
```

### Idempotency Demonstration
```bash
source strix-halo-lib/wifi-manager.sh

# First run: applies configuration
wifi_apply_configuration
# Output: "ASPM workaround applied successfully"

# Second run: detects already applied, does nothing
wifi_apply_configuration
# Output: "Native ASPM support already configured"
```

## Testing

### Device Detection Regression Checks
```bash
# Run the lightweight hardware-profile regression script
bash tests/device-manager-detection.sh

# Refresh generated device tables and help output after profile data changes
bash scripts/sync-device-matrix.sh

# Validate the repository version contract
bash tests/validate-version-sync.sh
```

The current regression script validates:
- allowlisted DMI-only matches for known devices like GZ302 and HP Z2 G1a
- rejection of loose DMI strings that previously caused false positives
- CPU/GPU signature fallback for unknown Strix Halo hardware
- correct ASUS profile separation between the generic ASUS path and the A14-specific path

Known-device metadata now lives in `strix-halo-lib/device-profile-data.sh`, which also feeds the generated support tables in the README, installer help text, and external catalog.

### Future Expansion
```bash
# bats remains a good future option for per-library unit tests
# but the repository now ships a dependency-free regression runner first
```

## Contributing

When adding new libraries:

1. **Follow the Pattern:** Use wifi-manager.sh as template
2. **Separate Concerns:** Detection, state check, configuration, verification
3. **Make Idempotent:** Always check before applying
4. **Document Well:** Add comprehensive comments and help function
5. **Test Thoroughly:** Test on multiple kernel versions and distros
6. **Use Standard Tools:** Prefer standard commands over complex parsing

## Version History

- **3.0.0** (Dec 2025): Initial library-first architecture
  - Created wifi-manager.sh as proof-of-concept
  - Established design principles and patterns
  - Documented architecture and roadmap

## References

- [Kernel Support Details](../docs/technical/kernel-support.md)
- [Obsolescence Analysis](../docs/technical/obsolescence-analysis.md)
- [Main README](../README.md)
