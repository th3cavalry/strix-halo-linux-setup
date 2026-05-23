import os
from pathlib import Path

class ConfigManager:
    """Manages application configuration loading and persistence."""
    
    def __init__(self, app_name="Strix Halo Dashboard"):
        self.config_dir = Path("/etc/strix-halo")
        self.config_file = self.config_dir / "tray.conf"
        self.app_name = app_name
        self.device_label = "Strix Halo Device"
        self.has_dashboard = True
        self.has_z13ctl = False
        self.has_command_center = False
        self.load_config()

    def _parse_bool(self, value):
        return value.lower() in ("1", "true", "yes", "on")

    def load_config(self):
        """Load tray configuration from file."""
        try:
            if self.config_file.exists():
                for line in self.config_file.read_text().splitlines():
                    line = line.strip()
                    if not line or line.startswith('#'):
                        continue
                    if '=' in line:
                        k, v = line.split('=', 1)
                        k = k.strip()
                        v = v.strip().strip('"').strip("'")
                        if k == 'APP_NAME':
                            self.app_name = v
                        elif k == 'DEVICE_LABEL':
                            self.device_label = v
                        elif k == 'HAS_DASHBOARD':
                            self.has_dashboard = self._parse_bool(v)
                        elif k == 'HAS_Z13CTL':
                            self.has_z13ctl = self._parse_bool(v)
                        elif k == 'HAS_COMMAND_CENTER':
                            self.has_command_center = self._parse_bool(v)
        except Exception:
            pass  # Fallback to defaults

    def get_app_name(self):
        return self.app_name

    def get_device_label(self):
        return self.device_label

    def dashboard_enabled(self):
        return self.has_dashboard

    def z13ctl_enabled(self):
        return self.has_z13ctl

    def command_center_enabled(self):
        return self.has_command_center
