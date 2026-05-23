# Changelog

All notable changes to Strix Halo Linux Setup will be documented in this file.

## [6.8.0] - 2026-05-23

### Added
- **Known-device coverage regression checks**: `tests/device-manager-detection.sh` now validates the generated support-coverage mapping for the known Strix Halo device profiles, including the ASUS-control split and baseline-stack devices.
- **Generic dashboard capability**: `strix-halo-lib/device-manager.sh` now exposes `CAP_DASHBOARD=true` for every confirmed Strix Halo device, so the tray/dashboard path is no longer GZ302-only.

### Changed
- **Equal dashboard support across devices**: `strix-halo-setup.sh` now offers the Strix Halo dashboard to all confirmed Strix Halo devices, writes neutral tray metadata, and keeps ASUS control backends opt-in only where `z13ctl` is actually supported.
- **Dashboard-first coverage model**: The generated device matrix, README, and command-center docs now describe support in dashboard-first terms instead of implying that non-ASUS devices lose the tray path entirely.
- **Supported-device matrix clarity**: `scripts/sync-device-matrix.sh` now generates a Coverage column alongside the support tier in the README, integrations catalog, and installer help output so each profile advertises the exact validated support surface.
- **Support terminology docs**: `docs/technical/external-integrations-catalog.md` and `docs/technical/obsolescence-analysis.md` now explain that coverage labels are derived from the same capability metadata used by device detection, reducing ambiguity around what “partial” support means.
- **Command-center runtime behavior**: The PyQt dashboard now loads per-device labels from `/etc/strix-halo/tray.conf`, falls back to generic sysfs telemetry without `z13ctl`, and disables unsupported ASUS-only actions instead of presenting a GZ302-only UI on every device.

## [6.7.1] - 2026-05-16

### Changed
- **GitHub repository renamed**: `th3cavalry/GZ302-Linux-Setup` → `th3cavalry/strix-halo-linux-setup`. All in-tree URL references updated.

## [6.7.0] - 2026-05-16

### Changed
- **Project rebrand to Strix Halo Linux Setup**: Expanded scope from ASUS ROG Flow Z13 (GZ302) to all AMD Ryzen AI MAX / Strix Halo devices. All project-level `gz302` identifiers have been renamed:
  - `gz302-setup.sh` → `strix-halo-setup.sh`
  - `gz302-lib/` → `strix-halo-lib/`
  - `modules/gz302-gaming.sh` → `modules/gaming.sh`
  - `modules/gz302-hypervisor.sh` → `modules/hypervisor.sh`
  - `modules/gz302-llm.sh` → `modules/llm.sh`
  - `scripts/uninstall/gz302-uninstall.sh` → `scripts/uninstall/uninstall.sh`
  - System config paths: `/etc/gz302/` → `/etc/strix-halo/`, `~/.config/gz302/` → `~/.config/strix-halo/`
  - Desktop/tray files: `gz302-tray.desktop` → `strix-halo-tray.desktop`
  - Package name: `gz302-linux-setup` → `strix-halo-setup`
  - App window titles and roles updated to "Strix Halo Dashboard" / "Strix Halo Command Center"

## [6.6.5] - 2026-05-16

### Fixed
- **MT7925 WiFi detection**: `device_detect_mt7925()` now passes unescaped ERE `|` alternation to `_lspci_has` and `_lsusb_has` (which use `grep -E` internally); the previous `\|` was interpreted as a literal pipe character, causing `CAP_MT7925` to silently never be set.
- **CS35L41 audio detection**: Simplified `device_detect_cs35l41()` grep pattern from `"CS35L41\|cs35l41"` to `"cs35l41"` since `-i` already handles case-insensitive matching.

## [6.6.4] - 2026-05-16

### Fixed
- **ShellCheck cleanup**: `strix-halo-lib/display-manager.sh` now reads tracked config files with direct redirection, and `strix-halo-lib/utils.sh` now uses explicit backup copy loops instead of `&& ... || true` chains.
- **Detection and validation stability**: `strix-halo-lib/device-manager.sh` no longer treats unsupported hardware probes as fatal during profile detection, and `tests/validate-version-sync.sh` now records missing version fields as mismatches instead of aborting early.

## [6.6.3] - 2026-05-16

### Fixed
- **Generated-content permission drift**: `scripts/sync-device-matrix.sh` now preserves the original file mode when rewriting marker blocks, so regenerating the installer matrix no longer drops the executable bit from `strix-halo-setup.sh` in CI.

### Changed
- **Release metadata sync**: Version references across the installer, libraries, modules, package metadata, command center, and docs are now aligned at 6.6.3.

## [6.6.2] - 2026-05-16

### Fixed
- **Unknown ASUS control-path scoping**: Generic ASUS Strix Halo fallback profiles no longer imply `z13ctl` applicability. Only explicitly validated ASUS profiles in `strix-halo-lib/device-profile-data.sh` now expose the z13ctl backend by default.
- **Version validation completeness**: `tests/validate-version-sync.sh` now verifies the `docs/README.md` installer version reference plus `display_fix_lib_version()` and `display_fix_lib_help()` in `strix-halo-lib/display-fix.sh`, closing the remaining release-metadata gaps in CI coverage.

## [6.6.1] - 2026-05-16

### Changed
- **Validation coverage hardened**: `.github/workflows/validate.yml` now runs bash syntax checks and ShellCheck recursively across all shell scripts, including nested helper scripts, instead of validating only a subset of paths.
- **Generated matrix sections annotated**: Auto-generated device-matrix blocks now include explicit provenance comments pointing back to `strix-halo-lib/device-profile-data.sh` and `scripts/sync-device-matrix.sh`.
- **Contributor guidance synced**: `CONTRIBUTING.md` and `docs/testing-guide.md` now reflect the recursive validation commands used by CI.

## [6.6.0] - 2026-05-16

### Added
- **Manifest-driven device matrix**: Added `strix-halo-lib/device-profile-data.sh` as the single source of truth for the known Strix Halo device matrix, with shared profile metadata for detection, capabilities, and documentation.
- **Generated matrix sync helper**: Added `scripts/sync-device-matrix.sh` to regenerate the README support table, installer supported-device help text, and external integrations catalog from the shared device-profile manifest.
- **Repository version validator**: Added `tests/validate-version-sync.sh` to enforce the full version contract used by this repository.

### Changed
- **Device manager profile application**: `strix-halo-lib/device-manager.sh` now applies exact known-device metadata from the shared profile manifest before falling back to vendor-level generic profiles.
- **Repository validation workflow**: `.github/workflows/validate.yml` now runs shell syntax checks, shellcheck, device-profile regressions, command-center Python compile checks, version validation, and generated-content drift detection.
- **Contributor templates**: Pull request and issue templates now ask for device-profile regressions, generated matrix sync, version validation, and DMI/device-profile diagnostics where relevant.
- **Testing documentation**: Contribution and testing docs now describe the generated-content sync and version-validation workflows, and the stale `--status` mention has been removed.

## [6.5.3] - 2026-05-16

### Fixed
- **Allowlisted DMI fallback**: `strix-halo-lib/device-manager.sh` now treats DMI-only Strix Halo matches as an exact known-device allowlist instead of matching broad tokens like `max`, which reduces false positives on unrelated systems.
- **ASUS TUF A14 profile scoping**: The A14 profile now requires an A14/TUF combination instead of matching any ASUS `tuf` or `a14` substring independently, so unknown ASUS Strix Halo devices fall back to the generic ASUS profile instead of being mislabeled.

### Added
- **Device-detection regression runner**: Added `tests/device-manager-detection.sh`, a dependency-free regression script that exercises the Strix Halo platform gate, known-device aliases, fallback behavior, and ASUS capability scoping.

### Changed
- **Testing guidance**: Updated `CONTRIBUTING.md`, `strix-halo-lib/README.md`, and `docs/testing-guide.md` to include the new device-detection regression workflow.

## [6.5.2] - 2026-05-16

### Added
- **Broader known-device profile coverage**: `strix-halo-lib/device-manager.sh` now explicitly recognizes HP Mini Workstation (Z2 G1a), Sixunited AXP77, GMKtec EVO-X2, Minisforum MS-S1 Max, AYANEO NEXT 2, and GPD Win 5 in addition to the already-supported GZ302, HP ZBook Ultra G1a, Framework Desktop, and ASUS TUF Gaming A14 profiles.

### Changed
- **Board-name aware detection**: Strix Halo profile matching now incorporates DMI `board_name` along with vendor, product, and family strings so OEM systems that expose the model through board identifiers are classified more reliably.
- **Installer and README support matrix**: The user-facing device inventory now lists the broader Strix Halo matrix instead of collapsing most mini-PC and handheld coverage into a generic “other” bucket.

## [6.5.1] - 2026-05-16

### Fixed
- **Strix Halo platform detection tightened**: `strix-halo-lib/device-manager.sh` now requires confirmed Strix Halo CPU/GPU signatures before enabling hardware-fix, AI, and ASUS control paths. Generic AMD graphics detection no longer marks unrelated systems as supported.
- **ASUS control-path scoping**: `strix-halo-setup.sh` now treats `z13ctl` as an ASUS-only backend and limits the GZ302 command-center tray app to profiles where it is actually applicable. Non-ASUS Strix Halo devices no longer see a misleading generic tray-app install path.
- **Conservative ASUS support tiers**: ASUS non-GZ302 Strix Halo profiles are now marked partial until the control stack is validated on those devices.
- **Debian/Ubuntu Distrobox fallback**: The installer now uses a system prefix when falling back to the upstream Distrobox installer, so `distrobox` is resolvable immediately after install during root-run setup flows.
- **Command-center version sync**: `command-center/src/command_center.py` now reports the same release version as the rest of the tree.

## [6.5.0] - 2026-05-15

### Added
- **Strix Halo platform broadening**: The installer now supports all AMD Strix Halo (Ryzen AI MAX / MAX+) devices, not just the ASUS ROG Flow Z13 (GZ302). Hardware auto-detection determines the device profile and applies only the relevant fixes.
- **`strix-halo-lib/device-manager.sh`** — new library that reads DMI, lspci, and kernel module state to produce a normalized device profile (`DEVICE_VENDOR`, `DEVICE_MODEL`, `DEVICE_CLASS`, `DEVICE_SUPPORT_TIER`) and capability flags (`CAP_ASUS_WMI`, `CAP_DETACHABLE_KB`, `CAP_INTERNAL_OLED`, `CAP_MT7925`, `CAP_CS35L41`, `CAP_Z13CTL`, `CAP_ROCM`). Known device profiles: ASUS ROG Flow Z13 (GZ302), HP ZBook Ultra G1a, Framework Desktop, ASUS TUF Gaming A14, and experimental mini-PC / handheld classes.
- **`docs/technical/external-integrations-catalog.md`** — curated catalog of Strix Halo community projects: z13ctl, Strix-Halo-Control, amd-strix-halo-toolboxes (kyuz0), vLLM, ComfyUI, GameMode, and MangoHUD. Includes device compatibility, install method, trust level, and known kernel bug/fix table.
- **New installer workflow** — the main flow is now:
  1. Hardware + system detection (device profile, kernel, distro, bootloader)
  2. Hardware fixes (kernel-level patches/params)
  3. Command Center (z13ctl gated to ASUS devices + tray app for all devices)
  4. Gaming packages (Steam, Lutris, MangoHUD, GameMode)
  5. AI / LLM packages (Ollama, ROCm, vLLM, ComfyUI)
  6. Other tools (Hypervisor + community integrations)
- **Community integrations section** — the installer presents the ecosystem catalog and lets users opt-in to Strix-Halo-Control and amd-strix-halo-toolboxes (via Distrobox).
- **z13ctl capability gating** — z13ctl is now only offered and installed on devices where `CAP_Z13CTL=true` (ASUS ROG hardware). Non-ASUS users are directed to the integrations catalog.
- **ROCm capability detection** — the AI section shows whether the Radeon 8060S was confirmed before suggesting ROCm workloads.

### Changed
- **Project branding**: README title updated to "Strix Halo Linux Setup"; banner subtitle updated to "AMD Ryzen AI MAX Platform"; supported device table added.
- **`strix-halo-setup.sh` help text**: Updated to list new sections and all supported device classes.
- **`strix-halo-lib/utils.sh` banner**: Subtitle now reads "Strix Halo Linux Setup — AMD Ryzen AI MAX Platform" instead of GZ302-specific text.
- **Section 3 header**: "Display & Tools" renamed to "Display & Command Center".

## [6.4.2] - 2026-05-15

### Fixed
- **Dashboard multi-monitor placement**: KWin positioner now correctly uses `window.output` so the dashboard stays on the screen that actually contains the window instead of teleporting to the active screen.

## [6.4.1] - 2026-05-15

### Fixed
- **Display mask `0xe12` breaks suspend on kernel 6.x (Issue #168)**: Changed `amdgpu.dcdebugmask` to `0x600` (PSR-SU + Panel Replay disable only) for **all** supported kernels. The broader `0xe12` mask (which additionally disables DRAM stutter, PSR v1, and IPS) was causing s2idle suspend failures on kernel 6.x — the side LED kept cycling on/off and the battery drained during sleep. Existing bootloader configurations with `0xe12` are automatically normalized to `0x600` on the next installer run. Affected files: `strix-halo-lib/kernel-compat.sh`, `strix-halo-lib/display-fix.sh`, `scripts/fix-suspend.sh`.
- **Ubuntu 26.04 support clarification**: Updated README and kernel-support docs to explicitly confirm Ubuntu 26.04 support on the kernel 7.0+ path and clarify that Linux 7+ is primarily tuning/consistency, not legacy hardware-enablement.
- **OLED artifact guidance wording**: README note now reflects that `amdgpu.dcdebugmask=0x600` applies to all supported kernels (not a per-version split).

## [6.4.0] - 2026-05-05

### Added
- **Tray RGB palette for both zones**: The command center dashboard and tray menu now expose visual static-color pickers for the keyboard and backlight separately, including preset swatches and a custom color dialog.

### Fixed
- **Per-zone z13ctl targeting in the tray app**: Command-center RGB actions now use `z13ctl --device keyboard|lightbar` for zone-specific static colors, brightness, and effects so keyboard and backlight changes stop overwriting each other.

## [6.3.7] - 2026-05-04

### Fixed
- **Kernel 7 display-mask regression (Issue #166)**: `display_apply_psr_su_fix()` now normalizes the toolkit-managed `amdgpu.dcdebugmask` bits to a kernel-aware target instead of only OR-ing flags forever. Kernel 6.x keeps `0xe12`, while kernel 7.0+ now uses `0x600` to avoid KDE/KWin pageflip freezes while preserving the OLED PSR-SU and Panel Replay fix.
- **Limine `amd_pstate=guided` detection/update gap (Issue #166)**: Bootloader detection now recognizes `/etc/default/limine`, the AMD P-State path updates both default Limine configs and direct `limine.conf` installs, and the installer regenerates Limine entries with `limine-update` or `limine-mkinitcpio` when changes were made.
- **Display-fix guidance sync**: README, kernel-support docs, and the suspend helper now describe the kernel-aware display mask instead of recommending `0xe12` unconditionally.

## [6.3.6] - 2026-05-03

### Fixed
- **z13ctl permission alignment**: `strix-halo-setup.sh` now ensures the active user is in the `users` group before running `z13ctl setup`, resolves the installed `z13ctl` path when writing sudoers and fallback user units, and keeps command-center power and fan actions on the same direct-or-sudo execution path used by RGB controls.
- **Debian-family detection for Kali**: `detect_distribution()` now treats `ID=kali` as Debian-based so Kali follows the expected Debian package path for the core installer.
- **Suspend helper recommendations**: `scripts/fix-suspend.sh` now suggests the current `amdgpu.dcdebugmask=0xe12` mask and stops recommending `amd_pmc.enable_stb=1` as a general Strix Halo tuning parameter.
- **Ubuntu support documentation**: Aligned the repo docs around Ubuntu 26.04 on kernel 6.19+, removed the stale `gz302-rgb-install.sh` reinstall reference, and corrected the documented sudoers path for command-center troubleshooting.

## [6.3.5] - 2026-04-29

### Fixed
- **KWin dashboard helper unload race**: Stopped unloading the temporary KWin placement helper on tray app exit, which could race against a fast restart and leave the new tray process without the bottom-right placement hook.
- **Reliable KDE Wayland placement helper persistence**: The command center now refreshes the helper on startup only, so the active instance keeps the bottom-right positioning script loaded while it is running.

## [6.3.4] - 2026-04-29

### Fixed
- **Tray left-click regression on KDE Plasma Wayland**: Removed the `QMenu`/`QWidgetAction` dashboard popup path that could not be created from tray activation and restored the reliable top-level dashboard window flow.
- **G-Helper-style bottom-right placement on KDE Wayland**: Added a small KWin scripting hook that snaps the dashboard window to the bottom-right work area after it is shown, instead of relying on Wayland client-side window moves.
- **Dashboard identity for compositor placement**: The dashboard now exposes a stable window title and window role so the KWin placement helper can target it consistently.

## [6.3.3] - 2026-04-29

### Changed
- **Dashboard popup now uses a Wayland-friendly menu surface**: Replaced the centered top-level dashboard tool window with a custom `QMenu` + `QWidgetAction` popup so the compact G-Helper-style panel can be shown as a real popup surface near the screen edge.
- **Bottom-right dashboard placement**: The tray dashboard now calculates its position from `QMenu.sizeHint()` and opens in the bottom-right corner of the active screen instead of relying on compositor-controlled top-level placement.
- **Popup close behavior**: The dashboard close button now hides the popup menu container, preserving the single-surface popup behavior.

## [6.3.2] - 2026-04-29

### Fixed
- **Dashboard would not appear on KDE Plasma Wayland**: Replaced the `Qt.Popup` dashboard window with a frameless `Qt.Tool` window after Qt reported `Failed to create grabbing popup` without a valid transient parent from tray activation.
- **Dashboard placement timing**: The dashboard is now positioned after `show()` using the real window handle so the compositor has a concrete surface to place.
- **Popup-style dismissal restored**: Brought back focus-loss auto-hide so the frameless tool window still closes when you click away.

## [6.3.1] - 2026-04-29

### Fixed
- **Tray clicks on KDE Plasma Wayland**: Restored the native attached tray context menu so right-click works reliably again through the status notifier integration.
- **Primary tray activation**: Expanded dashboard-open handling to also accept `ActivationReason.Unknown`, which some tray implementations emit for primary activation instead of `Trigger`.
- **Dashboard launcher action**: The tray menu's "Open Dashboard" action now uses the same deferred popup path as left-click so it opens in the intended bottom-right position.

## [6.3.0] - 2026-04-29

### Changed
- **Dashboard redesigned as G-Helper-style compact popup**: Replaced the 650×500 sidebar+tab window with a frameless, compact floating panel (~480px wide) that:
  - Appears **positioned near the system tray icon** on left-click (above or below depending on screen edge)
  - **Closes automatically on focus loss** (click anywhere outside = dismiss)
  - Shows all **8 performance profiles as tiled buttons** at the top (like G-Helper's mode tiles), with the active profile highlighted in ROG red
  - Displays a **live stats bar** (APU temp, fan RPM, active mode, battery %, CPU load) always visible
  - Provides compact **Battery Limit**, **RGB Lighting**, and **Fan Curve** sections in a single scrollable panel — no sidebar navigation
  - Has a **footer** with Auto Switch toggle and version label
- Removed `QStackedWidget`/`QListWidget` sidebar layout and all individual tab methods
- Updated `_on_activated()` to call `popup_near_tray()` + `update_ui_states()` before showing

## [6.2.2] - 2026-04-29

### Fixed
- **Blank tray icon after v6.2.0 upgrade**: Autostart entry was still pointing to the stale `/home/brandon/command-center/src/gz302_tray.py` (old pre-v6.2.0 install). Re-running `install-tray.sh` now correctly sets the autostart to `command_center.py`.
- **`update_icon()` never-blank fallback**: Added a QPainter-drawn colored circle+letter icon as fallback so the tray is never blank if SVG rendering is unavailable.

### Removed
- **`legacy/` directory**: Deleted `gz302-kbd-backlight-listener.py` and `gz302-kbd-backlight-listener.service` — fully superseded by z13ctl.
- **Stale `/home/brandon/command-center/` install**: Removed root-owned copy of old `gz302_tray.py` that caused the autostart regression.
- **Dead `tray-icon → command-center` migration block** in `strix-halo-setup.sh`: Migration completed in v5.x; code was unreachable.
- **`python-pyqt6-svg` package** from Arch install commands and `requirements.txt`: Does not exist as a separate package on Arch/CachyOS — SVG support is bundled in `python-pyqt6`.
- **Old `gz302_tray`/`strix-halo-tray` pgrep targets** in `install-tray.sh`: Only `command_center.py` is current.

### Changed
- **`.github/copilot-instructions.md`**: Updated `tray-icon/` references to `command-center/` throughout.

## [6.2.1] - 2026-04-27

### Fixed
- **Intermittent OLED artifacts persisting after "successful" display fix (Issue #160)**: `display_apply_psr_su_fix()` now regenerates boot artifacts when it merges an existing `amdgpu.dcdebugmask=` value in `/etc/kernel/cmdline` (systemd-boot path). This ensures updated `dcdebugmask` bits are not only written but also applied on reboot for UKI/initramfs-based setups (notably Arch/CachyOS).

### Changed
- **Version synchronization**: Bumped project version to `6.2.1` and synchronized version markers across installer, libraries, modules, command-center, package metadata, and README badge.

## [6.0.0] - 2026-04-23

### Added
- **Strix Halo Dashboard**: Completely rewritten the command-center from a tray-only menu into a robust, G-Helper inspired GUI application.
- **Enhanced Tray Menu**: Reintroduced and expanded the right-click tray menu with quick-access controls for all 8 Power Profiles, RGB Lighting (brightness/effects), Battery Charge Limits, and Auto-Switching toggles.
- **Improved Wayland Reliability**: The new Dashboard window provides a stable control interface that bypasses the input-serial and popup-window bugs common in KDE/GNOME Wayland system trays.
- **Enhanced UI**: Added a compact, dark-themed Dashboard with real-time APU temperature and fan speed monitoring.
- **Integrated Controls**: Single-window access to Power Profiles, TDP limits, Display Refresh Rates, and RGB Lighting.
- **Dynamic Tray States**: The tray menu now dynamically updates checkmarks and profile states using the `aboutToShow` signal for high reliability.

### Changed
- **Tray Icon Behavior**: Left-clicking the tray icon now toggles the Dashboard visibility instead of attempting to open a fragile QMenu.

## [5.1.4] - 2026-04-22

### Fixed
- **Intermittent graphical artifacts after install/reboot (Issue #161)**: GPU setup now regenerates initramfs after writing `/etc/modprobe.d/amdgpu.conf`, ensuring `amdgpu` module parameters such as `sg_display=0` and `cwsr_enable=0` actually take effect on early-loaded drivers used by Arch, CachyOS, and other initramfs-based setups.
- **Limine Support**: Added manual `amdgpu.dcdebugmask=0xe12` injection for systems using the Limine bootloader.


## [5.1.2] - 2026-04-17

### Fixed
- **Tray icon blank/invisible (Issue #159)**: Added PyQt6-SVG support for all distributions to properly render SVG tray icons on CachyOS and other desktop environments

### Changed
- **Python dependencies**: Added SVG rendering packages (python-pyqt6-svg, python3-pyqt6.qtsvg, python3-qt6-qtsvg) for Arch, Debian, Fedora, and OpenSUSE
- **Documentation**: Updated command-center installation instructions to include SVG support requirements
- **Documentation**: Removed outdated testing notes (v4.0.0-dev references, obsolete v3.0.0 regression testing)

### Added
- **Systematic versioning rules**: Mandatory version bumps for all changes with comprehensive workflow documentation in CONTRIBUTING.md and .github/copilot-instructions.md
- **Validation commands**: Enhanced version synchronization verification across all project files

## [5.1.1] - 2026-05

### Added
- **Security and UX overhaul**: Implemented comprehensive security hardening and user experience improvements across all modules.

## [5.1.0] - 2026-04

### Added
- Updated all component versions to **5.1.0** for unified release tracking.
- Updated `install-tray.sh` to remove conflicting launchers from both `/usr/share/applications` and `~/.local/share/applications`.

## [5.0.2] - 2025-04

### Fixed
- **OLED flickering — Panel Replay** (`DC_DISABLE_REPLAY = 0x400`): Panel Replay was explicitly enabled for DCN 3.5 (Strix Halo) by the amdgpu driver and was never disabled by previous releases. This is the primary cause of persistent flickering on the internal OLED panel.
- **OLED flickering — DRAM stutter** (`DC_DISABLE_STUTTER = 0x002`): On APU with unified memory, DRAM self-refresh causes display memory access latency spikes visible as brief flicker.
- **APU scatter-gather display** (`amdgpu.sg_display=0`): Kernel explicitly documents this option for APU flickering under memory pressure (Strix Halo is an APU with unified memory).
- **Adaptive Backlight Management** (`amdgpu.abmlevel=0`): ABM now set via modprobe option (persistent across boots) rather than only at runtime.

### Changed
- `dcdebugmask` mask updated from `0xa10` to `0xe12`:
  - `0x002` = `DC_DISABLE_STUTTER` (new)
  - `0x010` = `DC_DISABLE_PSR` (PSR v1 + PSR-SU)
  - `0x200` = `DC_DISABLE_PSR_SU` (belt-and-suspenders)
  - `0x400` = `DC_DISABLE_REPLAY` (Panel Replay — new, critical)
  - `0x800` = `DC_DISABLE_IPS` (all Idle Power States)
- `/etc/modprobe.d/amdgpu.conf` now includes `abmlevel=0` and `sg_display=0` in addition to `ppfeaturemask=0xffff7fff`
- All `# Version:` headers bumped to 5.0.2 across all scripts

## [5.0.1] - 2025-04

### Fixed
- **OLED display artifacts** (initial fix): `amdgpu.dcdebugmask=0xa10` targeting PSR, PSR-SU, and IPS; `abmlevel=0` for OLED ABM. Panel Replay not yet addressed (see 5.0.2).

### Changed
- `strix-halo-lib/display-fix.sh` updated for all bootloaders (GRUB, systemd-boot, loader entries, Limine, rEFInd)
- `strix-halo-lib/gpu-manager.sh` added `abmlevel=0` to modprobe config

## [5.0.0] - 2025-04

### Added
- z13ctl integration: RGB, power profiles, TDP, fan curves, and battery limit now powered by [z13ctl](https://github.com/dahui/z13ctl)
- pwrcfg, gz302-rgb, rrcfg wrapper commands for backward compatibility
- PyQt6 system tray (command-center/) for power profile switching
- strix-halo-lib/ library-first v5 architecture with all hardware as standalone sourced modules
- `strix-halo-lib/kernel-compat.sh` for kernel version–aware workarounds (6.14–6.17+)
- `strix-halo-lib/state-manager.sh` with atomic file writes and checkpoint system
- `strix-halo-lib/display-fix.sh` for OLED PSR/dcdebugmask fixes
- Optional modules (`modules/`) downloaded on demand: gaming, LLM, hypervisor
- Multi-distro support: Arch, Debian/Ubuntu, Fedora, OpenSUSE

### Changed
- Unified installer (`strix-halo-setup.sh`) replaces previous multi-script approach
- All hardware control via z13ctl (RGB, power, TDP, fan, battery)
- FHS-compliant config paths under `/etc/strix-halo/`, state under `/var/lib/gz302/`

## [4.2.1] - 2025-04-27

### Added
- **OLED PSR-SU fix library** (`strix-halo-lib/display-fix.sh`): Fixes scrolling artifacts (purple/green glitches, QR-code patterns) on the OLED panel by disabling PSR-SU via `amdgpu.dcdebugmask=0x200`
- PSR-SU fix integrated into `apply_hardware_fixes()` as step 7 — automatically detects and applies on first run
- Safe mask merging: existing `dcdebugmask` values are OR'd (not overwritten) to preserve other debug flags
- Supports GRUB, systemd-boot (`/etc/kernel/cmdline`), and loader entries
- Runtime PSR-SU disable via `amdgpu_dm_debug_mask` debugfs node

### Changed
- **PyTorch ROCm URL** updated from `rocm6.2` to `rocm7.2` (current stable)
- **LM Studio download** changed from hardcoded v0.3.6 AppImage to dynamic `https://lmstudio.ai/download/linux` redirect
- **RGB config permissions** tightened from 777/666 to 775/664 with `chgrp users` (OWASP compliance)
- **SOF firmware installation** deduplicated — `install_sof_firmware()` in main script now delegates to `audio-manager.sh` library (was 60 lines inline)
- Version banner in `main()` now reads from `VERSION` file instead of hardcoded "v2.3.13"
- All version strings synchronized to 4.2.1 across all files

### Fixed
- `dcdebugmask` value corrected from `0x20` (wrong bit) to `0x200` (`DC_DISABLE_PSR_SU`)
- Duplicate `provide_distro_optimization_info` call removed from `setup_debian_based()`
- Duplicate "GPU and thermal optimizations" completion line removed
- Step numbering corrected in all 4 distro setup functions (was "Step X of 7" with only 3-4 steps)
- `gz302-minimal.sh` self-references corrected from `gz302-minimal-v4.sh` to `gz302-minimal.sh`

### Removed
- 4 empty `enable_*_services()` stub functions and their call sites
- Legacy TODO/delegation comments from `apply_hardware_fixes()`
- Dead code and excessive blank lines throughout

## [4.2.0] - 2025-04

### Added
- Library-first architecture (`strix-halo-lib/`) for all hardware managers
- State management system with checkpoints and backups
- Kernel compatibility layer (`kernel-compat.sh`)
- Multi-distro support (Arch, Debian, Fedora, OpenSUSE)

## [4.0.0] - 2025

### Changed
- Major refactor from monolithic script to modular library architecture
- Optional modules (gaming, LLM, hypervisor) downloaded on demand
- RGB control split into keyboard (C binary) and lightbar (Python)
