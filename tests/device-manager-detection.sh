#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../strix-halo-lib/device-manager.sh"

ASSERTIONS_PASSED=0
ASSERTIONS_FAILED=0

MOCK_SYS_VENDOR=""
MOCK_PRODUCT_NAME=""
MOCK_PRODUCT_FAMILY=""
MOCK_BOARD_NAME=""
MOCK_CPU_MODEL=""
MOCK_LSPCI_TEXT=""
MOCK_LSUSB_TEXT=""
MOCK_MODULES_TEXT=""
MOCK_APLAY_TEXT=""
MOCK_FIND_TEXT=""

reset_mocks() {
    MOCK_SYS_VENDOR=""
    MOCK_PRODUCT_NAME=""
    MOCK_PRODUCT_FAMILY=""
    MOCK_BOARD_NAME=""
    MOCK_CPU_MODEL=""
    MOCK_LSPCI_TEXT=""
    MOCK_LSUSB_TEXT=""
    MOCK_MODULES_TEXT=""
    MOCK_APLAY_TEXT=""
    MOCK_FIND_TEXT=""
}

record_pass() {
    printf 'PASS: %s\n' "$1"
    ASSERTIONS_PASSED=$((ASSERTIONS_PASSED + 1))
}

record_fail() {
    printf 'FAIL: %s\n' "$1"
    ASSERTIONS_FAILED=$((ASSERTIONS_FAILED + 1))
}

expect_eq() {
    local label="$1"
    local expected="$2"
    local actual="$3"

    if [[ "$actual" == "$expected" ]]; then
        record_pass "$label"
    else
        record_fail "$label (expected: $expected, actual: $actual)"
    fi
}

print_case() {
    printf '\nCASE: %s\n' "$1"
}

_dmi_read() {
    case "$1" in
        sys_vendor) printf '%s\n' "$MOCK_SYS_VENDOR" ;;
        product_name) printf '%s\n' "$MOCK_PRODUCT_NAME" ;;
        product_family) printf '%s\n' "$MOCK_PRODUCT_FAMILY" ;;
        board_name) printf '%s\n' "$MOCK_BOARD_NAME" ;;
        *) printf '\n' ;;
    esac
}

_cpu_model_read() {
    printf '%s\n' "$MOCK_CPU_MODEL"
}

_lspci_has() {
    printf '%s\n' "$MOCK_LSPCI_TEXT" | grep -Eiq "$1"
}

_lsusb_has() {
    printf '%s\n' "$MOCK_LSUSB_TEXT" | grep -Eiq "$1"
}

_kernel_module_loaded() {
    printf '%s\n' "$MOCK_MODULES_TEXT" | tr ' ' '\n' | grep -qx "$1"
}

aplay() {
    printf '%s\n' "$MOCK_APLAY_TEXT"
}

find() {
    printf '%s\n' "$MOCK_FIND_TEXT"
}

test_gz302_dmi_allowlist() {
    print_case "GZ302 allowlisted DMI sets the full ASUS tablet profile"
    reset_mocks
    MOCK_SYS_VENDOR="ASUSTeK COMPUTER INC."
    MOCK_PRODUCT_NAME="ROG Flow Z13 GZ302EA_GZ302EA"
    MOCK_PRODUCT_FAMILY="ROG Flow Z13"
    MOCK_BOARD_NAME="GZ302EA"

    device_detect

    expect_eq "GZ302 DMI marks Strix Halo" "true" "$CAP_STRIX_HALO"
    expect_eq "GZ302 profile name" "ROG Flow Z13 (GZ302)" "$DEVICE_MODEL"
    expect_eq "GZ302 enables dashboard" "true" "$CAP_DASHBOARD"
    expect_eq "GZ302 enables command center" "true" "$CAP_COMMAND_CENTER"
}

test_hp_z2_board_allowlist() {
    print_case "HP Z2 board-name matching identifies the workstation mini profile"
    reset_mocks
    MOCK_SYS_VENDOR="HP"
    MOCK_PRODUCT_NAME="HP Workstation"
    MOCK_PRODUCT_FAMILY=""
    MOCK_BOARD_NAME="Z2 G1a"

    device_detect

    expect_eq "HP Z2 DMI marks Strix Halo" "true" "$CAP_STRIX_HALO"
    expect_eq "HP Z2 profile name" "HP Mini Workstation (Z2 G1a)" "$DEVICE_MODEL"
    expect_eq "HP Z2 support tier" "partial" "$DEVICE_SUPPORT_TIER"
}

test_generic_max_dmi_is_rejected() {
    print_case "Generic Max-branded DMI strings no longer imply Strix Halo"
    reset_mocks
    MOCK_SYS_VENDOR="Example Devices"
    MOCK_PRODUCT_NAME="Creator Max 14"
    MOCK_PRODUCT_FAMILY="Studio"
    MOCK_BOARD_NAME="Rev A"

    device_detect

    expect_eq "Generic Max DMI does not mark Strix Halo" "false" "$CAP_STRIX_HALO"
    expect_eq "Generic Max DMI leaves fallback model" "Creator Max 14" "$DEVICE_MODEL"
}

test_generic_minipc_brand_without_signature_is_rejected() {
    print_case "Known mini-PC brands without Strix Halo proof remain unsupported"
    reset_mocks
    MOCK_SYS_VENDOR="GMKtec"
    MOCK_PRODUCT_NAME="NucBox K6"
    MOCK_PRODUCT_FAMILY=""
    MOCK_BOARD_NAME=""

    device_detect

    expect_eq "Generic GMKtec DMI does not mark Strix Halo" "false" "$CAP_STRIX_HALO"
    expect_eq "Generic GMKtec DMI keeps fallback model" "NucBox K6" "$DEVICE_MODEL"
}

test_non_strix_amd_laptop_is_rejected() {
    print_case "Non-Strix AMD laptops are not promoted into the Strix Halo path"
    reset_mocks
    MOCK_SYS_VENDOR="ASUSTeK COMPUTER INC."
    MOCK_PRODUCT_NAME="ROG Zephyrus G14"
    MOCK_PRODUCT_FAMILY="ROG"
    MOCK_BOARD_NAME="GA402"
    MOCK_CPU_MODEL="AMD Ryzen 9 7940HS w/ Radeon 780M Graphics"
    MOCK_LSPCI_TEXT="VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] Phoenix1 [1002:15bf]"

    device_detect

    expect_eq "Non-Strix AMD laptop does not mark Strix Halo" "false" "$CAP_STRIX_HALO"
    expect_eq "Non-Strix AMD laptop keeps dashboard disabled" "false" "$CAP_DASHBOARD"
    expect_eq "Non-Strix AMD laptop keeps z13ctl disabled" "false" "$CAP_Z13CTL"
}

test_cpu_signature_is_authoritative() {
    print_case "CPU signatures still override missing DMI aliases"
    reset_mocks
    MOCK_SYS_VENDOR="Unknown Vendor"
    MOCK_PRODUCT_NAME="Prototype"
    MOCK_PRODUCT_FAMILY=""
    MOCK_BOARD_NAME=""
    MOCK_CPU_MODEL="AMD Ryzen AI Max+ PRO 395 w/ Radeon 8060S"

    device_detect

    expect_eq "CPU signature marks Strix Halo" "true" "$CAP_STRIX_HALO"
    expect_eq "CPU signature enables dashboard" "true" "$CAP_DASHBOARD"
    expect_eq "Unknown CPU-backed device stays experimental" "experimental" "$DEVICE_SUPPORT_TIER"
    expect_eq "Unknown CPU-backed device keeps z13ctl disabled" "false" "$CAP_Z13CTL"
}

test_gpu_signature_is_authoritative() {
    print_case "GPU signatures still enable Strix Halo and ROCm on unknown DMI"
    reset_mocks
    MOCK_SYS_VENDOR="Unknown Vendor"
    MOCK_PRODUCT_NAME="Engineering Sample"
    MOCK_PRODUCT_FAMILY=""
    MOCK_BOARD_NAME=""
    MOCK_LSPCI_TEXT="VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] Strix Halo [Radeon 8060S] [1002:1586]"

    device_detect

    expect_eq "GPU signature marks Strix Halo" "true" "$CAP_STRIX_HALO"
    expect_eq "GPU signature enables dashboard" "true" "$CAP_DASHBOARD"
    expect_eq "GPU signature enables ROCm" "true" "$CAP_ROCM"
    expect_eq "Unknown GPU-backed device keeps fallback support tier" "experimental" "$DEVICE_SUPPORT_TIER"
}

test_non_a14_tuf_profile_falls_back() {
    print_case "Non-A14 ASUS TUF strings do not get forced into the A14 profile"
    reset_mocks
    MOCK_SYS_VENDOR="ASUSTeK COMPUTER INC."
    MOCK_PRODUCT_NAME="TUF Dash F15"
    MOCK_PRODUCT_FAMILY="ASUS TUF"
    MOCK_BOARD_NAME="FX507"
    MOCK_CPU_MODEL="AMD Ryzen AI Max+ 395 w/ Radeon 8060S"

    device_detect

    expect_eq "Unknown ASUS TUF stays on the generic ASUS profile" "ASUS Strix Halo (TUF Dash F15)" "$DEVICE_MODEL"
    expect_eq "Unknown ASUS TUF keeps command center disabled" "false" "$CAP_COMMAND_CENTER"
    expect_eq "Unknown ASUS TUF keeps z13ctl disabled until explicitly validated" "false" "$CAP_Z13CTL"
}

test_known_device_matrix_coverage() {
    local sys_vendor product_name product_family board_name expected_model
    local expected_tier expected_dashboard expected_z13ctl expected_command_center expected_coverage
    local actual_coverage

    print_case "Known device profiles keep their expected support coverage"

    while IFS='|' read -r sys_vendor product_name product_family board_name expected_model \
        expected_tier expected_dashboard expected_z13ctl expected_command_center expected_coverage; do
        [[ -n "$sys_vendor" ]] || continue

        reset_mocks
        MOCK_SYS_VENDOR="$sys_vendor"
        MOCK_PRODUCT_NAME="$product_name"
        MOCK_PRODUCT_FAMILY="$product_family"
        MOCK_BOARD_NAME="$board_name"

        device_detect
        actual_coverage=$(device_profile_support_coverage_label "$DEVICE_SUPPORT_TIER" "$CAP_Z13CTL" "$CAP_COMMAND_CENTER")

        expect_eq "$expected_model model" "$expected_model" "$DEVICE_MODEL"
        expect_eq "$expected_model tier" "$expected_tier" "$DEVICE_SUPPORT_TIER"
        expect_eq "$expected_model dashboard" "$expected_dashboard" "$CAP_DASHBOARD"
        expect_eq "$expected_model z13ctl" "$expected_z13ctl" "$CAP_Z13CTL"
        expect_eq "$expected_model tray app" "$expected_command_center" "$CAP_COMMAND_CENTER"
        expect_eq "$expected_model coverage" "$expected_coverage" "$actual_coverage"
    done <<'EOF'
    ASUSTeK COMPUTER INC.|ROG Flow Z13 GZ302EA_GZ302EA|ROG Flow Z13|GZ302EA|ROG Flow Z13 (GZ302)|full|true|true|true|Full stack
    HP|HP ZBook Ultra G1a|||HP ZBook Ultra G1a|partial|true|false|false|Dashboard + core stack
    HP|HP Workstation||Z2 G1a|HP Mini Workstation (Z2 G1a)|partial|true|false|false|Dashboard + core stack
    Framework|Framework Desktop|||Framework Desktop|partial|true|false|false|Dashboard + core stack
    ASUSTeK COMPUTER INC.|ASUS TUF Gaming A14|||ASUS TUF Gaming A14|partial|true|true|false|Dashboard + ASUS control
    Sixunited|AXP77|||Sixunited AXP77|experimental|true|false|false|Dashboard + baseline stack
    GMKtec|EVO-X2|||GMKtec EVO-X2|experimental|true|false|false|Dashboard + baseline stack
    Minisforum|MS-S1 Max|||Minisforum MS-S1 Max|experimental|true|false|false|Dashboard + baseline stack
    AYANEO|NEXT 2|||AYANEO NEXT 2|experimental|true|false|false|Dashboard + baseline stack
    GPD|Win 5|||GPD Win 5|experimental|true|false|false|Dashboard + baseline stack
EOF
}

main() {
    test_gz302_dmi_allowlist
    test_hp_z2_board_allowlist
    test_generic_max_dmi_is_rejected
    test_generic_minipc_brand_without_signature_is_rejected
    test_non_strix_amd_laptop_is_rejected
    test_cpu_signature_is_authoritative
    test_gpu_signature_is_authoritative
    test_non_a14_tuf_profile_falls_back
    test_known_device_matrix_coverage

    printf '\nAssertions passed: %s\n' "$ASSERTIONS_PASSED"

    if [[ "$ASSERTIONS_FAILED" -gt 0 ]]; then
        printf 'Assertions failed: %s\n' "$ASSERTIONS_FAILED"
        return 1
    fi

    printf 'All device-manager regression checks passed.\n'
}

main "$@"