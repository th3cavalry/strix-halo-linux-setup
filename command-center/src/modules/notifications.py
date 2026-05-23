from PyQt6.QtWidgets import QSystemTrayIcon

# Optional: Try to import dbus for richer desktop notifications via org.freedesktop.Notifications
try:
    import dbus
    _DBUS_AVAILABLE = True
except ImportError:
    _DBUS_AVAILABLE = False

# DBus urgency levels (org.freedesktop.Notifications spec)
_URGENCY_LOW = 0
_URGENCY_NORMAL = 1
_URGENCY_CRITICAL = 2


def _send_dbus_notification(app_name, title, message, urgency_level, timeout_ms):
    """Send a desktop notification directly via DBus (org.freedesktop.Notifications)."""
    bus = dbus.SessionBus()
    obj = bus.get_object("org.freedesktop.Notifications", "/org/freedesktop/Notifications")
    iface = dbus.Interface(obj, "org.freedesktop.Notifications")
    hints = {"urgency": dbus.Byte(urgency_level)}
    iface.Notify(app_name, dbus.UInt32(0), "", title, message, dbus.Array([], signature="s"), hints, timeout_ms)


class NotificationManager:
    """Manages desktop notifications with optional sound feedback"""

    def __init__(self, tray_icon):
        self.tray = tray_icon
        self.dbus_available = _DBUS_AVAILABLE
        self._app_name = "Strix Halo Dashboard"

    @property
    def app_name(self):
        """Get app name from tray's config if available."""
        try:
            return self.tray.config.get_app_name()
        except:
            return self._app_name

    def notify(self, title, message, icon_type="info", duration=4000, urgency="normal"):
        """
        Send a desktop notification.

        Args:
            title: Notification title
            message: Notification body
            icon_type: "info", "warning", "error", "success"
            duration: Display duration in milliseconds
            urgency: "low", "normal", "critical"
        """
        # Map icon types
        qt_icons = {
            "info": QSystemTrayIcon.MessageIcon.Information,
            "warning": QSystemTrayIcon.MessageIcon.Warning,
            "error": QSystemTrayIcon.MessageIcon.Critical,
            "success": QSystemTrayIcon.MessageIcon.Information,
        }

        # Add emoji prefix for visual feedback
        emoji_prefix = {
            "info": "ℹ️",
            "warning": "⚠️",
            "error": "❌",
            "success": "✅",
        }

        # Format message with emoji
        formatted_title = f"{emoji_prefix.get(icon_type, '')} {title}"

        # Try DBus notification first for richer desktop integration
        if self.dbus_available:
            try:
                urgency_map = {
                    "low": _URGENCY_LOW,
                    "normal": _URGENCY_NORMAL,
                    "critical": _URGENCY_CRITICAL,
                }
                _send_dbus_notification(
                    self.app_name,
                    formatted_title,
                    message,
                    urgency_map.get(urgency, _URGENCY_NORMAL),
                    duration,
                )
                return
            except Exception:
                pass

        # Fallback to Qt system tray notification
        self.tray.showMessage(
            formatted_title,
            message,
            qt_icons.get(icon_type, QSystemTrayIcon.MessageIcon.Information),
            duration,
        )

    def notify_profile_change(self, profile, power_info=""):
        """Send notification for profile change with detailed info"""
        profile_info = {
            "emergency": ("🔋 Emergency Mode", "10W - Maximum battery preservation"),
            "battery": ("🔋 Battery Mode", "18W - Extended battery life"),
            "efficient": ("⚡ Efficient Mode", "30W - Light tasks with good performance"),
            "balanced": ("⚖️ Balanced Mode", "40W - General computing (Default)"),
            "performance": ("🚀 Performance Mode", "55W - Heavy workloads"),
            "gaming": ("🎮 Gaming Mode", "70W - Optimized for gaming"),
            "maximum": ("💪 Maximum Mode", "90W - Peak performance"),
        }

        title, desc = profile_info.get(profile, (f"Profile: {profile}", ""))
        message = desc
        if power_info:
            message += f"\n{power_info}"

        # Prepend application name for clarity
        self.notify(f"{self.app_name}: {title}", message, "success", 4000)

    def notify_error(self, title, message, hint=""):
        """Send error notification with optional hint"""
        full_message = message
        if hint:
            full_message += f"\n\n💡 Tip: {hint}"
        self.notify(f"{self.app_name}: {title}", full_message, "error", 6000, "critical")
