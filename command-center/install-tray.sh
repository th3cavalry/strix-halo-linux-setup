#!/usr/bin/env bash
set -euo pipefail

# Install a Desktop launcher and Autostart entry for the Strix Halo Command Center
# This script can be run as a regular user for user-specific installation
# or with sudo for system-wide installation

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# Determine the canonical install location for the tray icon
# Priority: local script directory > system control-center > legacy command-center
# This ensures the script works both when run directly and from the main setup
if [[ -f "$SCRIPT_DIR/src/command_center.py" ]]; then
  APP_DIR="$SCRIPT_DIR"
elif [[ -f "/usr/local/share/strix-halo/control-center/src/command_center.py" ]]; then
  APP_DIR="/usr/local/share/strix-halo/control-center"
elif [[ -f "/usr/local/share/strix-halo/command-center/src/command_center.py" ]]; then
  APP_DIR="/usr/local/share/strix-halo/command-center"
else
  APP_DIR="$SCRIPT_DIR"
fi

APP_PY="$APP_DIR/src/command_center.py"

if [[ ! -f "$APP_PY" ]]; then
  echo "ERROR: Tray script not found at $APP_PY" >&2
  exit 1
fi

# Ensure executable bit (warn if it fails but continue)
if ! chmod +x "$APP_PY" 2>/dev/null; then
  echo "WARNING: Could not set executable bit on $APP_PY (may already be set)" >&2
fi

# Determine user home directory (handle sudo case)
if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
  USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
  USER_HOME="$HOME"
fi

# User locations
AUTOSTART_DIR="$USER_HOME/.config/autostart"
DESKTOP_DIR="$USER_HOME/.local/share/applications"
mkdir -p "$AUTOSTART_DIR" "$DESKTOP_DIR"

# Cleanup old/conflicting desktop files - be aggressive to fix "2 listings"
OLD_DESKTOP_FILES=(
  "/usr/share/applications/strix-halo-control-center.desktop"
  "/usr/share/applications/strix-halo-tray.desktop"
  "$DESKTOP_DIR/strix-halo-control-center.desktop"
  "$DESKTOP_DIR/strix-halo-tray.desktop"
  "/etc/xdg/autostart/strix-halo-control-center.desktop"
  "/etc/xdg/autostart/strix-halo-tray.desktop"
  "$AUTOSTART_DIR/strix-halo-control-center.desktop"
  "$AUTOSTART_DIR/strix-halo-tray.desktop"
)

for f in "${OLD_DESKTOP_FILES[@]}"; do
  if [[ -f "$f" ]]; then
    echo "Removing old/conflicting desktop file: $f"
    rm -f "$f" 2>/dev/null || sudo rm -f "$f" 2>/dev/null || true
  fi
done

# Install icon to system location for proper XDG integration
ICON_NAME="strix-halo-power-manager"
ICON_SRC="$APP_DIR/assets/profile-b.svg"

# Try to install icon to system-wide location if running as root
if [[ ${EUID:-$(id -u)} -eq 0 ]] && [[ -f "$ICON_SRC" ]]; then
  # Install to hicolor icon theme (most widely supported)
  ICON_DEST="/usr/share/icons/hicolor/scalable/apps/${ICON_NAME}.svg"
  mkdir -p "$(dirname "$ICON_DEST")"
  if cp "$ICON_SRC" "$ICON_DEST" 2>/dev/null; then
    echo "Installed system icon: $ICON_DEST"
  else
    echo "WARNING: Could not install system icon to $ICON_DEST" >&2
  fi
  
  # Update icon cache
  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null || true
  fi
elif [[ -f "$ICON_SRC" ]]; then
  # Fallback to user icon directory
  USER_ICON_DIR="$USER_HOME/.local/share/icons/hicolor/scalable/apps"
  mkdir -p "$USER_ICON_DIR"
  if cp "$ICON_SRC" "$USER_ICON_DIR/${ICON_NAME}.svg" 2>/dev/null; then
    echo "Installed user icon: $USER_ICON_DIR/${ICON_NAME}.svg"
  else
    echo "WARNING: Could not install user icon" >&2
  fi
fi

# Use python3 explicitly in Exec line for better compatibility across desktop environments
# Respect APP_NAME setting from /etc/strix-halo/tray.conf if present
APP_NAME_DEFAULT="Strix Halo Dashboard"
APP_NAME="$APP_NAME_DEFAULT"
if [[ -f /etc/strix-halo/tray.conf ]]; then
  # shellcheck disable=SC1091
  while IFS='=' read -r k v; do
    k=$(echo "$k" | tr -d ' "')
    v=$(echo "$v" | sed -e 's/^ *//g' -e 's/ *$//g' -e 's/^"//' -e 's/"$//')
    if [[ "$k" == "APP_NAME" && -n "$v" ]]; then
      APP_NAME="$v"
    fi
  done < /etc/strix-halo/tray.conf
fi

DESKTOP_FILE_CONTENT="[Desktop Entry]
Type=Application
Name=$APP_NAME
Comment=G-Helper inspired dashboard for AMD Strix Halo devices
Exec=python3 $APP_PY
Icon=$ICON_NAME
Terminal=false
Categories=Utility;System;Settings;HardwareSettings;
Keywords=power;battery;profile;asus;rog;strix-halo;
StartupNotify=false
X-GNOME-Autostart-enabled=true
"

# Install desktop launcher to user directory
DESKTOP_FILE="$DESKTOP_DIR/strix-halo-tray.desktop"
printf "%s" "$DESKTOP_FILE_CONTENT" > "$DESKTOP_FILE"
chmod 644 "$DESKTOP_FILE"

# Fix ownership if running as root
if [[ ${EUID:-$(id -u)} -eq 0 ]] && [[ -n "${SUDO_USER:-}" ]]; then
  if ! chown "$SUDO_USER:$SUDO_USER" "$DESKTOP_FILE" 2>/dev/null; then
    echo "WARNING: Could not set ownership on $DESKTOP_FILE" >&2
  fi
fi

# Install autostart entry
# Skip user-level autostart if system-level autostart exists (prevents duplicates)
AUTOSTART_FILE="$AUTOSTART_DIR/strix-halo-tray.desktop"
SYSTEM_AUTOSTART="/etc/xdg/autostart/strix-halo-control-center.desktop"
if [[ -f "$SYSTEM_AUTOSTART" ]]; then
  echo "System-level autostart exists at $SYSTEM_AUTOSTART - skipping user autostart"
  # Remove any existing user autostart to prevent duplicates
  rm -f "$AUTOSTART_FILE" 2>/dev/null || true
  rm -f "$AUTOSTART_DIR/strix-halo-control-center.desktop" 2>/dev/null || true
else
  printf "%s" "$DESKTOP_FILE_CONTENT" > "$AUTOSTART_FILE"
  chmod 644 "$AUTOSTART_FILE"
  echo "Enabled autostart entry:    $AUTOSTART_FILE"
fi

# Fix ownership if running as root
if [[ ${EUID:-$(id -u)} -eq 0 ]] && [[ -n "${SUDO_USER:-}" ]]; then
  if ! chown "$SUDO_USER:$SUDO_USER" "$AUTOSTART_FILE" 2>/dev/null; then
    echo "WARNING: Could not set ownership on $AUTOSTART_FILE" >&2
  fi
fi

# Install system-wide desktop file if running as root
if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
  SYSTEM_DESKTOP_DIR="/usr/share/applications"
  mkdir -p "$SYSTEM_DESKTOP_DIR"
  SYSTEM_DESKTOP_FILE="$SYSTEM_DESKTOP_DIR/strix-halo-tray.desktop"
  printf "%s" "$DESKTOP_FILE_CONTENT" > "$SYSTEM_DESKTOP_FILE"
  chmod 644 "$SYSTEM_DESKTOP_FILE"
  echo "Installed system-wide desktop launcher: $SYSTEM_DESKTOP_FILE"
  
  # Update desktop database
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$SYSTEM_DESKTOP_DIR" 2>/dev/null || true
  fi
fi

# Update user desktop database
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
fi

echo "Installed desktop launcher: $DESKTOP_FILE"
echo ""

echo "Registering APP_NAME to /etc/strix-halo/tray.conf and notifying running tray (if any)..."
# Ensure config dir exists
mkdir -p /etc/strix-halo
if [[ ! -f /etc/strix-halo/tray.conf ]] || ! grep -q "APP_NAME" /etc/strix-halo/tray.conf 2>/dev/null; then
  echo "APP_NAME=\"$APP_NAME\"" > /etc/strix-halo/tray.conf
  chmod 644 /etc/strix-halo/tray.conf
fi

# ==============================================================================
# z13ctl Backend Check
# Ensure z13ctl is installed since the tray app depends on it for RGB & power
# ==============================================================================
if ! command -v z13ctl >/dev/null 2>&1; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Optional z13ctl Backend Missing"
  echo "The dashboard will still launch, but ASUS RGB and power control"
  echo "features require z13ctl on supported devices."
  echo "Install z13ctl manually if you want those ASUS-specific controls:"
    echo "  https://github.com/dahui/z13ctl"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
fi
# ==============================================================================

# Notify running tray processes using SIGUSR1 so they reload UI strings
pids=()
while read -r p; do
  [[ -n "$p" ]] && pids+=("$p")
done < <(pgrep -f "command_center.py" 2>/dev/null || true)

if [[ ${#pids[@]} -gt 0 ]]; then
  for pid in "${pids[@]}"; do
    if kill -0 "$pid" >/dev/null 2>&1; then
      kill -USR1 "$pid" 2>/dev/null || true
      echo "Sent SIGUSR1 to tray process: $pid"
    fi
  done
  echo "Tray processes notified; they will reload their UI shortly."
else
  echo "No running tray process detected. Start it via the app menu or logging out/in." 
fi

echo ""
echo "You can now launch '$APP_NAME' from your app menu or it will start on login."
echo ""
echo "NOTE: If you use GNOME, you may need to install the 'AppIndicator' extension:"
echo "  - GNOME: Install 'AppIndicator and KStatusNotifierItem Support' from extensions.gnome.org"
echo "  - KDE/XFCE/LXQt: System tray support is built-in"
