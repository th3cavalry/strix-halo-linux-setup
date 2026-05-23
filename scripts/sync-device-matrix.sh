#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)

# shellcheck source=/dev/null
source "${REPO_ROOT}/strix-halo-lib/device-profile-data.sh"

support_tier_label() {
    case "$1" in
        full) printf 'Full' ;;
        partial) printf 'Partial' ;;
        experimental) printf 'Experimental' ;;
        *) printf '%s' "$1" ;;
    esac
}

setup_support_tier_label() {
    case "$1" in
        full) printf 'full support' ;;
        partial) printf 'partial support' ;;
        experimental) printf 'experimental' ;;
        *) printf '%s' "$1" ;;
    esac
}

baseline_support_coverage() {
    device_profile_support_coverage_label "experimental" "false" "false"
}

render_support_coverage_note() {
    printf '> Coverage labels: **Full stack** = dashboard + core fixes + ASUS control + the full GZ302 command-center surface; **Dashboard + ASUS control** = dashboard + core fixes + ASUS control on supported ASUS devices; **Dashboard + core stack** = dashboard + cross-device fixes, gaming, AI/ROCm, and integrations; **Dashboard + baseline stack** = the same dashboard-first path under experimental validation.\n'
}

render_readme_table() {
    printf '<!-- AUTO-GENERATED from strix-halo-lib/device-profile-data.sh via scripts/sync-device-matrix.sh -->\n'
    printf '| Device | APU | Class | Support tier | Coverage |\n'
    printf '| :--- | :--- | :--- | :--- | :--- |\n'

    while IFS= read -r record; do
        local _id _vendor_tokens _profile_vendor _device_model doc_name _device_class
        local doc_class support_tier apu _cap_z13ctl _cap_command_center
        local _cap_detachable _cap_internal_oled _aliases
        local coverage

        IFS='|' read -r _id _vendor_tokens _profile_vendor _device_model doc_name _device_class \
            doc_class support_tier apu _cap_z13ctl _cap_command_center _cap_detachable \
            _cap_internal_oled _aliases <<< "$record"

        coverage=$(device_profile_support_coverage_from_record "$record")
        printf '| **%s** | %s | %s | %s | %s |\n' "$doc_name" "$apu" "$doc_class" "$(support_tier_label "$support_tier")" "$coverage"
    done < <(device_profile_each_record)

    printf '| **%s** | %s | %s | %s | %s |\n' \
        "$STRIX_HALO_BASELINE_DOC_NAME" \
        "$STRIX_HALO_BASELINE_APU" \
        "$STRIX_HALO_BASELINE_CLASS" \
        "$STRIX_HALO_BASELINE_TIER" \
        "$(baseline_support_coverage)"

    printf '\n'
    render_support_coverage_note
}

render_catalog_table() {
    printf '<!-- AUTO-GENERATED from strix-halo-lib/device-profile-data.sh via scripts/sync-device-matrix.sh -->\n'
    printf '| Device | APU | Class | Support tier | Coverage |\n'
    printf '|---|---|---|---|---|\n'

    while IFS= read -r record; do
        local _id _vendor_tokens _profile_vendor _device_model doc_name _device_class
        local doc_class support_tier apu _cap_z13ctl _cap_command_center
        local _cap_detachable _cap_internal_oled _aliases
        local coverage

        IFS='|' read -r _id _vendor_tokens _profile_vendor _device_model doc_name _device_class \
            doc_class support_tier apu _cap_z13ctl _cap_command_center _cap_detachable \
            _cap_internal_oled _aliases <<< "$record"

        coverage=$(device_profile_support_coverage_from_record "$record")
        printf '| %s | %s | %s | %s | %s |\n' "$doc_name" "$apu" "$doc_class" "$(support_tier_label "$support_tier")" "$coverage"
    done < <(device_profile_each_record)

    printf '| %s | %s | %s | %s | %s |\n' \
        "$STRIX_HALO_BASELINE_DOC_NAME" \
        "$STRIX_HALO_BASELINE_APU" \
        "$STRIX_HALO_BASELINE_CLASS" \
        "$STRIX_HALO_BASELINE_TIER" \
        "$(baseline_support_coverage)"

    printf '\n'
    render_support_coverage_note
}

render_setup_comment_block() {
    printf '# AUTO-GENERATED from strix-halo-lib/device-profile-data.sh via scripts/sync-device-matrix.sh.\n'
    while IFS= read -r record; do
        local _id _vendor_tokens _profile_vendor _device_model doc_name _device_class
        local _doc_class support_tier _apu _cap_z13ctl _cap_command_center
        local _cap_detachable _cap_internal_oled _aliases
        local coverage

        IFS='|' read -r _id _vendor_tokens _profile_vendor _device_model doc_name _device_class \
            _doc_class support_tier _apu _cap_z13ctl _cap_command_center _cap_detachable \
            _cap_internal_oled _aliases <<< "$record"

        coverage=$(device_profile_support_coverage_from_record "$record")
        printf '# - %s — %s (%s)\n' "$doc_name" "$(setup_support_tier_label "$support_tier")" "$coverage"
    done < <(device_profile_each_record)

    printf '# - Other confirmed Strix Halo — experimental baseline (%s)\n' "$(baseline_support_coverage)"
}

render_setup_help_function() {
    printf "    # AUTO-GENERATED from strix-halo-lib/device-profile-data.sh via scripts/sync-device-matrix.sh.\n"
    while IFS= read -r record; do
        local _id _vendor_tokens _profile_vendor _device_model doc_name _device_class
        local _doc_class support_tier _apu _cap_z13ctl _cap_command_center
        local _cap_detachable _cap_internal_oled _aliases
        local coverage

        IFS='|' read -r _id _vendor_tokens _profile_vendor _device_model doc_name _device_class \
            _doc_class support_tier _apu _cap_z13ctl _cap_command_center _cap_detachable \
            _cap_internal_oled _aliases <<< "$record"

        coverage=$(device_profile_support_coverage_from_record "$record")
        printf "    printf '%%s\\n' '%s — %s (%s)'\n" "$doc_name" "$(support_tier_label "$support_tier")" "$coverage"
    done < <(device_profile_each_record)

    printf "    printf '%%s\\n' 'Other confirmed Strix Halo — %s (%s)'\n" "$STRIX_HALO_BASELINE_TIER" "$(baseline_support_coverage)"
}

replace_block() {
    local file_path="$1"
    local start_marker="$2"
    local end_marker="$3"
    local content="$4"
    local file_mode
    local tmp_file
    local seen_start="false"
    local seen_end="false"
    local in_block="false"

    file_mode=$(stat -c '%a' "$file_path")
    tmp_file=$(mktemp)

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == "$start_marker" ]]; then
            seen_start="true"
            in_block="true"
            printf '%s\n' "$line" >> "$tmp_file"
            printf '%s\n' "$content" >> "$tmp_file"
            continue
        fi

        if [[ "$line" == "$end_marker" ]]; then
            seen_end="true"
            in_block="false"
            printf '%s\n' "$line" >> "$tmp_file"
            continue
        fi

        if [[ "$in_block" == "true" ]]; then
            continue
        fi

        printf '%s\n' "$line" >> "$tmp_file"
    done < "$file_path"

    if [[ "$seen_start" != "true" || "$seen_end" != "true" ]]; then
        rm -f "$tmp_file"
        printf 'Required marker block not found in %s\n' "$file_path" >&2
        return 1
    fi

    mv "$tmp_file" "$file_path"
    chmod "$file_mode" "$file_path"
}

main() {
    replace_block \
        "${REPO_ROOT}/README.md" \
        "<!-- BEGIN:SUPPORTED_DEVICE_TABLE -->" \
        "<!-- END:SUPPORTED_DEVICE_TABLE -->" \
        "$(render_readme_table)"

    replace_block \
        "${REPO_ROOT}/strix-halo-setup.sh" \
        "# BEGIN AUTO-GENERATED SUPPORTED DEVICES" \
        "# END AUTO-GENERATED SUPPORTED DEVICES" \
        "$(render_setup_comment_block)"

    replace_block \
        "${REPO_ROOT}/strix-halo-setup.sh" \
        "    # BEGIN AUTO-GENERATED SUPPORTED DEVICES HELP" \
        "    # END AUTO-GENERATED SUPPORTED DEVICES HELP" \
        "$(render_setup_help_function)"

    replace_block \
        "${REPO_ROOT}/docs/technical/external-integrations-catalog.md" \
        "<!-- BEGIN:KNOWN_STRIX_HALO_DEVICE_TABLE -->" \
        "<!-- END:KNOWN_STRIX_HALO_DEVICE_TABLE -->" \
        "$(render_catalog_table)"
}

main "$@"