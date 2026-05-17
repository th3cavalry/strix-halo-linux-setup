# Strix Halo Platform Transition Plan

**Date:** 2026-04-14  
**Scope:** Transition from ASUS ROG Flow Z13 (GZ302)-only support to broad support for Strix Halo devices, while keeping stable GZ302 behavior and focusing on gaming + AI performance.

---

## 1) Objectives

1. Support all practical Strix Halo device classes with one installer flow.
2. Auto-detect hardware/model/capabilities and apply only relevant fixes.
3. Keep current core guarantees: idempotent, kernel-aware, multi-distro parity.
4. Add opt-in ecosystem integration (external Strix Halo repos/toolboxes) through a curated, user-selectable catalog.
5. Preserve backward compatibility for existing GZ302 users.

---

## 2) Strix Halo Device Inventory (as of 2026-04-14)

### A. Confirmed shipping/available

1. **ASUS ROG Flow Z13 (2025, GZ302 series)**  
   - Ryzen AI Max+ 395 / Radeon 8060S
2. **HP ZBook Ultra G1a**  
   - Up to Ryzen AI Max+ PRO 395 / Radeon 8060S
3. **Framework Desktop (Mini-ITX platform)**  
   - Ryzen AI Max 385 and Ryzen AI Max+ 395 options

### B. Publicly announced / launch stated (availability varies by region)

1. **ASUS TUF Gaming A14 variant with Ryzen AI Max+ 392** (reported launch confirmation)
2. **Sixunited AXP77** (publicly shown as Strix Halo-based)

### C. Community-reported / pre-release ecosystem devices (treat as unverified until vendor availability pages exist)

1. **AYANEO NEXT 2** (Strix Halo handheld reporting)
2. **GPD Win 5** (Strix Halo handheld reporting)

> Recommendation: maintain this as a **living compatibility matrix** with confidence level (`confirmed`, `announced`, `community-reported`) rather than a static “final” list.

---

## 3) Current Codebase Gaps Blocking Broad Device Support

1. Project naming and many messages are GZ302-specific.
2. Several subsystem assumptions are device-specific (keyboard product defaults, panel assumptions, ASUS-centric control flow).
3. No centralized device profile layer that maps detected hardware to supported capabilities.
4. Optional module flow is package-feature based, not capability-recommendation based.
5. No curated framework for external Strix Halo repo installs from within the setup experience.

---

## 4) Target Architecture

## 4.1 Add Device & Capability Abstraction Layer

Create a new manager library (for example `strix-halo-lib/device-manager.sh`) to produce one normalized **device profile** from:

- DMI: `/sys/class/dmi/id/{sys_vendor,product_name,product_family,board_name}`
- CPU/APU identity: `lscpu`, `lspci`, relevant AMD identifiers
- Display/input/audio/IO capabilities from existing managers

Outputs:

- `device_vendor` (ASUS/HP/Framework/Other)
- `device_model` (normalized string)
- `device_class` (tablet, laptop, workstation-laptop, desktop, handheld, mini-pc)
- `capabilities` (booleans, e.g. `has_asus_wmi`, `has_detachable_keyboard`, `has_internal_oled`, `has_mt7925`, `has_cs35l41`, `supports_z13ctl`)
- `support_tier` (`full`, `partial`, `experimental`)

## 4.2 Profile-Driven Configuration

Add a profile registry (Bash data file or generated map) with:

- Generic Strix Halo baseline profile
- Vendor/model overlays (ASUS GZ302, HP ZBook Ultra G1a, Framework Desktop, etc.)
- Per-component applicability rules by capability + kernel version

All existing managers should consume profile flags instead of assuming GZ302 defaults.

## 4.3 Capability-Gated Install Sections

Enhance installer orchestration to:

1. Detect profile first.
2. Show detected device + support tier.
3. Offer recommended sections by capability:
   - Hardware fixes (only relevant fixes)
   - Control stack (z13ctl only when device supports it)
   - Display tools (only when internal panel features apply)
   - Gaming/AI modules (always available, with profile-based tuning recommendations)

---

## 5) External Repository Integration Plan (User-Selectable)

## 5.1 Curated Catalog

Introduce a curated external catalog file (example: `docs/technical/external-integrations-catalog.md` + install manifest in script-friendly format) with:

- Repo name + URL
- Purpose category (`control`, `gaming`, `ai`, `benchmarking`, `monitoring`)
- Supported distros
- Supported device classes/vendors
- Install method (`package`, `script`, `container`, `manual`)
- Trust level (`official`, `community-verified`, `experimental`)
- Last verified date + pinned release/tag/commit

## 5.2 Initial Candidate Integrations

1. **dahui/z13ctl** (ASUS-specific control path)
2. **TechnoDaimon/Strix-Halo-Control** (GUI control panel, ASUS-focused)
3. **kyuz0/amd-strix-halo-toolboxes** (AI container workflows)
4. Additional Strix Halo toolbox variants (vLLM/comfy/image-video) as optional advanced entries

## 5.3 Installer UX

Add a new optional section:

- “Community Integrations (Gaming/AI)”  
- Present only compatible/recommended entries for detected profile.
- Let user select multiple entries.
- For each selected item: show trust level, support scope, and what will be installed.

## 5.4 Safety Controls

1. Explicit opt-in only (default off).
2. Pin to known tags/releases/commit SHAs where possible.
3. Verify checksums/signatures for downloadable artifacts where available.
4. Maintain local install state for clean uninstall and repeatable re-runs.
5. Require supported distro path for each integration; otherwise skip with clear guidance.

---

## 6) Phased Implementation Roadmap

## Phase 1 — Foundation (non-breaking)

1. Add device-manager library and normalized profile output.
2. Build initial profile table:
   - Generic Strix Halo
   - ASUS GZ302
   - HP ZBook Ultra G1a
   - Framework Desktop
3. Add support tier messaging and capability dump in installer status.

## Phase 2 — Manager Refactor to Capability Inputs

1. Update wifi/gpu/input/audio/display managers to use profile flags.
2. Remove hard-coded GZ302-only assumptions where not required.
3. Keep kernel-aware cleanup behavior unchanged, now profile-aware.

## Phase 3 — Installer Experience

1. Add profile-driven recommendations to section prompts.
2. Gate z13ctl and ASUS-specific paths behind capability checks.
3. Add `--profile`, `--device-class`, and `--dry-run-profile` flags for diagnostics.

## Phase 4 — External Integration Catalog

1. Add catalog and installer selection flow.
2. Implement integration runners with distro gating and state tracking.
3. Add uninstall hooks for catalog-installed items where feasible.

## Phase 5 — Branding + Documentation Transition

1. Introduce Strix Halo platform wording while preserving GZ302 compatibility notes.
2. Update technical docs with profile matrix and support tiers.
3. Keep legacy naming/wrappers where needed to avoid breaking existing users.

---

## 7) Validation Strategy

1. **Static checks:** `bash -n` and `shellcheck` (existing workflow).
2. **Profile simulation tests:** add fixture-driven tests for known DMI/capability combinations.
3. **Kernel-aware tests:** validate `<6.17`, `6.17+`, and newer cleanup behavior paths.
4. **Distro parity checks:** ensure all new branches include Arch, Debian/Ubuntu, Fedora, OpenSUSE.
5. **Idempotency checks:** repeated runs must not duplicate config or leave stale state.

---

## 8) Risks and Mitigations

1. **Risk:** false hardware detection on unknown OEM strings  
   **Mitigation:** generic fallback profile + conservative fix application.
2. **Risk:** external repos changing install behavior  
   **Mitigation:** pin versions, add verification, and mark trust tier.
3. **Risk:** feature fragmentation across device classes  
   **Mitigation:** capability matrix as single source of applicability truth.
4. **Risk:** regressions for existing GZ302 users  
   **Mitigation:** preserve GZ302 profile as first-class reference and validate before each release.

---

## 9) Open Clarifications Needed

1. Should project branding/repo name eventually move from `GZ302-Linux-Setup` to a Strix Halo-wide name, or remain with broadened scope?
2. What minimum support bar defines `full` vs `partial` for new devices?
3. Should handheld-class Strix Halo devices be in initial scope, or phase-2 after laptop/desktop coverage?
4. Do we want community integrations installed directly on host by default, or container-first preference for AI stacks?
5. Is there a preferred allowlist size for v1 (for example: 3–5 integrations only) to reduce maintenance overhead?

---

## 10) Sources for Device/Repo Research

- ASUS ROG Flow Z13 (2025) product page (Ryzen AI Max+ 395)  
  https://rog.asus.com/laptops/rog-flow/rog-flow-z13-2025/
- HP workstation page listing ZBook Ultra G1a with Ryzen AI Max+ PRO 395  
  https://www.hp.com/us-en/workstations/mobile-workstation-pc.html
- Framework Desktop announcement (Ryzen AI Max family, pre-order/ship timeline)  
  https://frame.work/blog/introducing-the-framework-desktop
- Notebookcheck Strix Halo coverage (device launch references for 392 ecosystem)  
  https://www.notebookcheck.net/New-AMD-Strix-Halo-Ryzen-AI-Max-392-stars-in-early-benchmark-after-CES-2026-debut.1204390.0.html
- Upstream ecosystem repositories:
  - https://github.com/dahui/z13ctl
  - https://github.com/TechnoDaimon/Strix-Halo-Control
  - https://github.com/kyuz0/amd-strix-halo-toolboxes
