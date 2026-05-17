import os
from pathlib import Path

class ConfigManager:
    """Manages application configuration loading and persistence."""
    
    def __init__(self, app_name="ASUS ROG Flow Z13 (GZ302) Command Center"):
        self.config_dir = Path("/etc/strix-halo")
        self.config_file = self.config_dir / "tray.conf"
        self.app_name = app_name
        self.load_config()

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
        except Exception:
            pass  # Fallback to defaults

    def get_app_name(self):
        return self.app_name
