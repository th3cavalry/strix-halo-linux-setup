#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)

cd "$REPO_ROOT"

EXPECTED_VERSION=$(cat VERSION)
ERROR_COUNT=0

record_error() {
    printf 'ERROR: %s\n' "$1"
    ERROR_COUNT=$((ERROR_COUNT + 1))
}

require_equal() {
    local label="$1"
    local expected="$2"
    local actual="$3"

    if [[ "$expected" != "$actual" ]]; then
        record_error "$label mismatch (expected: $expected, actual: $actual)"
    fi
}

main() {
    local setup_header
    local setup_constant
    local command_center_version
    local command_center_py_version
    local pkg_version
    local readme_version
    local docs_readme_version
    local display_fix_version
    local display_fix_help_version
    local script_version

    setup_header=$(grep '^# Version:' strix-halo-setup.sh | head -1 | sed 's/^# Version: //' || true)
    setup_constant=$(grep '^SETUP_VERSION=' strix-halo-setup.sh | sed -E 's/SETUP_VERSION="([^"]+)"/\1/' || true)
    command_center_version=$(cat command-center/VERSION)
    command_center_py_version=$(grep '^VERSION = ' command-center/src/command_center.py | sed -E 's/VERSION = "([^"]+)"/\1/' || true)
    pkg_version=$(grep '^pkgver=' pkg/arch/PKGBUILD | cut -d= -f2 || true)
    readme_version=$(grep 'https://img.shields.io/badge/version-' README.md | head -1 | sed -E 's/.*version-([0-9.]+)-blue.*/\1/' || true)
    docs_readme_version=$(grep 'Unified installer (v' docs/README.md | head -1 | sed -E 's/.*\(v([0-9.]+)\).*/\1/' || true)
    display_fix_version=$(grep -E 'echo "[0-9.]+"' strix-halo-lib/display-fix.sh | head -1 | sed -E 's/.*"([0-9.]+)".*/\1/' || true)
    display_fix_help_version=$(grep '^GZ302 Display Fix Library v' strix-halo-lib/display-fix.sh | head -1 | sed -E 's/^GZ302 Display Fix Library v([0-9.]+)/\1/' || true)

    require_equal 'strix-halo-setup.sh header' "$EXPECTED_VERSION" "$setup_header"
    require_equal 'strix-halo-setup.sh SETUP_VERSION' "$EXPECTED_VERSION" "$setup_constant"
    require_equal 'command-center/VERSION' "$EXPECTED_VERSION" "$command_center_version"
    require_equal 'command_center.py VERSION' "$EXPECTED_VERSION" "$command_center_py_version"
    require_equal 'pkg/arch/PKGBUILD pkgver' "$EXPECTED_VERSION" "$pkg_version"
    require_equal 'README version badge' "$EXPECTED_VERSION" "$readme_version"
    require_equal 'docs/README.md version reference' "$EXPECTED_VERSION" "$docs_readme_version"
    require_equal 'display_fix_lib_version()' "$EXPECTED_VERSION" "$display_fix_version"
    require_equal 'display_fix_lib_help()' "$EXPECTED_VERSION" "$display_fix_help_version"

    for script in strix-halo-lib/*.sh modules/*.sh; do
        script_version=$(grep '^# Version:' "$script" | head -1 | sed 's/^# Version: //' || true)
        require_equal "$script header" "$EXPECTED_VERSION" "$script_version"
    done

    if ! grep -q "^## \[$EXPECTED_VERSION\]" docs/CHANGELOG.md; then
        record_error "docs/CHANGELOG.md is missing heading for $EXPECTED_VERSION"
    fi

    if [[ "$ERROR_COUNT" -gt 0 ]]; then
        printf 'Version validation failed with %s error(s).\n' "$ERROR_COUNT"
        return 1
    fi

    printf 'Version validation passed for %s.\n' "$EXPECTED_VERSION"
}

main "$@"