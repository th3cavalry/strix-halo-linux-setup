#!/bin/bash
# shellcheck disable=SC2034
set -euo pipefail

# ==============================================================================
# Strix Halo Device Profile Data Library
# Version: 6.8.0
#
# Single source of truth for the known Strix Halo device matrix used by the
# installer, device detection, and generated documentation.
# ==============================================================================

STRIX_HALO_KNOWN_DEVICE_PROFILES=$(cat <<'EOF'
asus-gz302|asus|ASUS|ROG Flow Z13 (GZ302)|ASUS ROG Flow Z13 (GZ302)|tablet|Tablet / Gaming 2-in-1|full|Ryzen AI Max+ 395 / Max 390|true|true|true|true|gz302,rog flow z13
hp-zbook-ultra-g1a|hp,hewlett|HP|HP ZBook Ultra G1a|HP ZBook Ultra G1a|workstation-laptop|Workstation laptop|partial|Ryzen AI Max+ PRO 395|false|false|false|false|zbook ultra g1a
hp-z2-g1a|hp,hewlett|HP|HP Mini Workstation (Z2 G1a)|HP Mini Workstation (Z2 G1a)|mini-pc|Mini workstation|partial|Ryzen AI Max+ 395|false|false|false|false|z2 g1a
framework-desktop|framework|Framework|Framework Desktop|Framework Desktop|desktop|Desktop|partial|Ryzen AI Max 385 / Max+ 395|false|false|false|false|framework desktop
asus-tuf-a14|asus|ASUS|ASUS TUF Gaming A14|ASUS TUF Gaming A14|laptop|Laptop|partial|Ryzen AI Max+ 392|true|false|false|false|tuf gaming a14,tuf a14
sixunited-axp77|sixunited|Sixunited|Sixunited AXP77|Sixunited AXP77|mini-pc|Mini-PC|experimental|Ryzen AI Max+ 395|false|false|false|false|axp77
gmktec-evo-x2|gmktec|GMKtec|GMKtec EVO-X2|GMKtec EVO-X2|mini-pc|Mini-PC|experimental|Ryzen AI Max+ 395|false|false|false|false|evo-x2,evox2
minisforum-ms-s1-max|minisforum|Minisforum|Minisforum MS-S1 Max|Minisforum MS-S1 Max|mini-pc|Mini-PC|experimental|Ryzen AI Max+ 395|false|false|false|false|ms-s1,ms s1
ayaneo-next-2|ayaneo|AYANEO|AYANEO NEXT 2|AYANEO NEXT 2|handheld|Handheld|experimental|Ryzen AI Max+ 395|false|false|false|false|next 2
gpd-win-5|gpd|GPD|GPD Win 5|GPD Win 5|handheld|Handheld|experimental|Ryzen AI Max+ 395|false|false|false|false|win 5
EOF
)

STRIX_HALO_BASELINE_DOC_NAME="Other Strix Halo"
STRIX_HALO_BASELINE_APU="Ryzen AI MAX family"
STRIX_HALO_BASELINE_CLASS="Laptop / Mini-PC / Handheld"
STRIX_HALO_BASELINE_TIER="Experimental baseline"

device_profile_each_record() {
    while IFS= read -r record; do
        [[ -n "$record" ]] && printf '%s\n' "$record"
    done <<< "$STRIX_HALO_KNOWN_DEVICE_PROFILES"
}

device_profile_record_matches_dmi() {
    local record="$1"
    local vendor="$2"
    local combined="$3"
    local _id vendor_tokens _profile_vendor _device_model _doc_name _device_class
    local _doc_class _support_tier _apu _cap_z13ctl _cap_command_center
    local _cap_detachable _cap_internal_oled aliases
    local vendor_match="false"
    local token
    local alias

    IFS='|' read -r _id vendor_tokens _profile_vendor _device_model _doc_name _device_class \
        _doc_class _support_tier _apu _cap_z13ctl _cap_command_center _cap_detachable \
        _cap_internal_oled aliases <<< "$record"

    IFS=',' read -r -a vendor_values <<< "$vendor_tokens"
    for token in "${vendor_values[@]}"; do
        if [[ "$vendor" == *"$token"* ]]; then
            vendor_match="true"
            break
        fi
    done
    [[ "$vendor_match" == "true" ]] || return 1

    IFS=',' read -r -a alias_values <<< "$aliases"
    for alias in "${alias_values[@]}"; do
        if [[ "$combined" == *"$alias"* ]]; then
            return 0
        fi
    done

    return 1
}

device_profile_known_record_by_dmi() {
    local vendor="$1"
    local combined="$2"
    local record

    while IFS= read -r record; do
        [[ -n "$record" ]] || continue
        if device_profile_record_matches_dmi "$record" "$vendor" "$combined"; then
            printf '%s\n' "$record"
            return 0
        fi
    done <<< "$STRIX_HALO_KNOWN_DEVICE_PROFILES"

    return 1
}

device_profile_apply_record() {
    local record="$1"
    local _id _vendor_tokens profile_vendor device_model _doc_name device_class
    local _doc_class support_tier _apu cap_z13ctl cap_command_center
    local cap_detachable cap_internal_oled _aliases

    IFS='|' read -r _id _vendor_tokens profile_vendor device_model _doc_name device_class \
        _doc_class support_tier _apu cap_z13ctl cap_command_center cap_detachable \
        cap_internal_oled _aliases <<< "$record"

    DEVICE_VENDOR="$profile_vendor"
    DEVICE_MODEL="$device_model"
    DEVICE_CLASS="$device_class"
    DEVICE_SUPPORT_TIER="$support_tier"
    CAP_Z13CTL="$cap_z13ctl"
    CAP_COMMAND_CENTER="$cap_command_center"
    CAP_DETACHABLE_KB="$cap_detachable"
    CAP_INTERNAL_OLED="$cap_internal_oled"
}

device_profile_support_coverage_label() {
    local support_tier="$1"
    local cap_z13ctl="$2"
    local cap_command_center="$3"

    if [[ "$cap_command_center" == "true" ]]; then
        printf 'Full stack'
        return 0
    fi

    if [[ "$cap_z13ctl" == "true" ]]; then
        printf 'Dashboard + ASUS control'
        return 0
    fi

    case "$support_tier" in
        full|partial) printf 'Dashboard + core stack' ;;
        experimental) printf 'Dashboard + baseline stack' ;;
        *) printf '%s' "$support_tier" ;;
    esac
}

device_profile_support_coverage_from_record() {
    local record="$1"
    local _id _vendor_tokens _profile_vendor _device_model _doc_name _device_class
    local _doc_class support_tier _apu cap_z13ctl cap_command_center
    local _cap_detachable _cap_internal_oled _aliases

    IFS='|' read -r _id _vendor_tokens _profile_vendor _device_model _doc_name _device_class \
        _doc_class support_tier _apu cap_z13ctl cap_command_center _cap_detachable \
        _cap_internal_oled _aliases <<< "$record"

    device_profile_support_coverage_label "$support_tier" "$cap_z13ctl" "$cap_command_center"
}