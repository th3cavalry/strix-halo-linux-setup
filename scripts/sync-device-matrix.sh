#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)

# shellcheck source=/dev/null
source "${REPO_ROOT}/gz302-lib/device-profile-data.sh"

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

render_readme_table() {
    printf '<!-- AUTO-GENERATED from gz302-lib/device-profile-data.sh via scripts/sync-device-matrix.sh -->\n'
    printf '| Device | APU | Class | Support tier |\n'
    printf '| :--- | :--- | :--- | :--- |\n'

    while IFS= read -r record; do
        local _id _vendor_tokens _profile_vendor _device_model doc_name _device_class
        local doc_class support_tier apu _cap_z13ctl _cap_command_center
        local _cap_detachable _cap_internal_oled _aliases

        IFS='|' read -r _id _vendor_tokens _profile_vendor _device_model doc_name _device_class \
            doc_class support_tier apu _cap_z13ctl _cap_command_center _cap_detachable \
            _cap_internal_oled _aliases <<< "$record"

        printf '| **%s** | %s | %s | %s |\n' "$doc_name" "$apu" "$doc_class" "$(support_tier_label "$support_tier")"
    done < <(device_profile_each_record)

    printf '| **%s** | %s | %s | %s |\n' \
        "$STRIX_HALO_BASELINE_DOC_NAME" \
        "$STRIX_HALO_BASELINE_APU" \
        "$STRIX_HALO_BASELINE_CLASS" \
        "$STRIX_HALO_BASELINE_TIER"
}

render_catalog_table() {
    printf '<!-- AUTO-GENERATED from gz302-lib/device-profile-data.sh via scripts/sync-device-matrix.sh -->\n'
    printf '| Device | APU | Class | Support tier |\n'
    printf '|---|---|---|---|\n'

    while IFS= read -r record; do
        local _id _vendor_tokens _profile_vendor _device_model doc_name _device_class
        local doc_class support_tier apu _cap_z13ctl _cap_command_center
        local _cap_detachable _cap_internal_oled _aliases

        IFS='|' read -r _id _vendor_tokens _profile_vendor _device_model doc_name _device_class \
            doc_class support_tier apu _cap_z13ctl _cap_command_center _cap_detachable \
            _cap_internal_oled _aliases <<< "$record"

        printf '| %s | %s | %s | %s |\n' "$doc_name" "$apu" "$doc_class" "$(support_tier_label "$support_tier")"
    done < <(device_profile_each_record)
}

render_setup_comment_block() {
    printf '# AUTO-GENERATED from gz302-lib/device-profile-data.sh via scripts/sync-device-matrix.sh.\n'
    while IFS= read -r record; do
        local _id _vendor_tokens _profile_vendor _device_model doc_name _device_class
        local _doc_class support_tier _apu _cap_z13ctl _cap_command_center
        local _cap_detachable _cap_internal_oled _aliases

        IFS='|' read -r _id _vendor_tokens _profile_vendor _device_model doc_name _device_class \
            _doc_class support_tier _apu _cap_z13ctl _cap_command_center _cap_detachable \
            _cap_internal_oled _aliases <<< "$record"

        printf '# - %s — %s\n' "$doc_name" "$(setup_support_tier_label "$support_tier")"
    done < <(device_profile_each_record)

    printf '# - Other confirmed Strix Halo — experimental baseline\n'
}

render_setup_help_function() {
    printf "    # AUTO-GENERATED from gz302-lib/device-profile-data.sh via scripts/sync-device-matrix.sh.\n"
    while IFS= read -r record; do
        local _id _vendor_tokens _profile_vendor _device_model doc_name _device_class
        local _doc_class support_tier _apu _cap_z13ctl _cap_command_center
        local _cap_detachable _cap_internal_oled _aliases

        IFS='|' read -r _id _vendor_tokens _profile_vendor _device_model doc_name _device_class \
            _doc_class support_tier _apu _cap_z13ctl _cap_command_center _cap_detachable \
            _cap_internal_oled _aliases <<< "$record"

        printf "    printf '%%s\\n' '%s — %s'\n" "$doc_name" "$(support_tier_label "$support_tier")"
    done < <(device_profile_each_record)

    printf "    printf '%%s\\n' 'Other confirmed Strix Halo — %s'\n" "$STRIX_HALO_BASELINE_TIER"
}

replace_block() {
    local file_path="$1"
    local start_marker="$2"
    local end_marker="$3"
    local content="$4"
    local tmp_file
    local seen_start="false"
    local seen_end="false"
    local in_block="false"

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
}

main() {
    replace_block \
        "${REPO_ROOT}/README.md" \
        "<!-- BEGIN:SUPPORTED_DEVICE_TABLE -->" \
        "<!-- END:SUPPORTED_DEVICE_TABLE -->" \
        "$(render_readme_table)"

    replace_block \
        "${REPO_ROOT}/gz302-setup.sh" \
        "# BEGIN AUTO-GENERATED SUPPORTED DEVICES" \
        "# END AUTO-GENERATED SUPPORTED DEVICES" \
        "$(render_setup_comment_block)"

    replace_block \
        "${REPO_ROOT}/gz302-setup.sh" \
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