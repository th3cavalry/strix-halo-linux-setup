import re
import subprocess
from pathlib import Path

# z13ctl valid profiles: quiet, balanced, performance, custom
# We map our 7 tray profiles to z13ctl profiles + explicit TDP overrides.
# tdp=None means let the firmware manage TDP for that stock profile.
POWER_PROFILES = {
    "emergency":   {"z13ctl_profile": "quiet",       "tdp": 10},
    "battery":     {"z13ctl_profile": "quiet",       "tdp": 18},
    "efficient":   {"z13ctl_profile": "quiet",       "tdp": 30},
    "quiet":       {"z13ctl_profile": "quiet",       "tdp": None},
    "balanced":    {"z13ctl_profile": "balanced",    "tdp": 40},
    "performance": {"z13ctl_profile": "performance", "tdp": 55},
    "gaming":      {"z13ctl_profile": "performance", "tdp": 70},
    "maximum":     {"z13ctl_profile": "performance", "tdp": 90},
}

_AUTO_CONFIG_FILE = Path.home() / ".config" / "strix-halo" / "auto.conf"
_PROFILE_CACHE_FILE = Path.home() / ".config" / "strix-halo" / "tray-profile.conf"


class PowerController:
    """Manages power profiles and battery settings via z13ctl."""

    def __init__(self, notifier):
        self.notifier = notifier
        self.current_profile = self._read_current_profile()
        self._auto_enabled = False
        self._ac_profile = "performance"
        self._battery_profile = "balanced"
        self._last_plugged = None
        self._load_auto_config()

    def _run_z13ctl(self, args, timeout=10):
        last_result = None
        for cmd in (args, ["sudo", "-n"] + args):
            try:
                result = subprocess.run(
                    cmd,
                    capture_output=True,
                    text=True,
                    timeout=timeout,
                )
            except Exception:
                continue
            last_result = result
            if result.returncode == 0:
                return result
        return last_result

    def _result_error(self, result):
        if result is None:
            return "Unable to execute z13ctl"
        detail = result.stderr.strip() or result.stdout.strip() or "Unknown error"
        lowered = detail.lower()
        if (
            "permission" in lowered
            or "password is required" in lowered
            or "not permitted" in lowered
        ):
            detail = (
                f"{detail}\n"
                "Log out and back in if the installer just added your account to the 'users' group."
            )
        return detail

    def _read_current_profile(self):
        # Check saved tray profile first — preserves 7-tier names like gaming/maximum
        # and avoids a slow z13ctl call during startup
        try:
            if _PROFILE_CACHE_FILE.exists():
                val = _PROFILE_CACHE_FILE.read_text().strip()
                if val in POWER_PROFILES:
                    return val
        except Exception:
            pass
        # Fall back to z13ctl status (returns 3-tier: quiet/balanced/performance)
        try:
            result = self._run_z13ctl(["z13ctl", "status"], timeout=5)
            if result and result.returncode == 0:
                for line in result.stdout.splitlines():
                    low = line.lower()
                    if "profile" in low and ":" in line:
                        return line.split(":", 1)[1].strip().lower()
        except Exception:
            pass
        return "balanced"

    def _load_auto_config(self):
        try:
            if _AUTO_CONFIG_FILE.exists():
                for line in _AUTO_CONFIG_FILE.read_text().splitlines():
                    line = line.strip()
                    if not line or line.startswith('#'):
                        continue
                    if '=' in line:
                        k, v = line.split('=', 1)
                        k, v = k.strip(), v.strip().strip('"').strip("'")
                        if k == 'AUTO_SWITCH':
                            self._auto_enabled = v in ('1', 'true', 'yes')
                        elif k == 'AC_PROFILE':
                            if v in POWER_PROFILES:
                                self._ac_profile = v
                        elif k == 'BATTERY_PROFILE':
                            if v in POWER_PROFILES:
                                self._battery_profile = v
        except Exception:
            pass

    def _save_auto_config(self):
        try:
            _AUTO_CONFIG_FILE.parent.mkdir(parents=True, exist_ok=True)
            lines = [
                f'AUTO_SWITCH={"1" if self._auto_enabled else "0"}',
                f'AC_PROFILE={self._ac_profile}',
                f'BATTERY_PROFILE={self._battery_profile}',
            ]
            _AUTO_CONFIG_FILE.write_text('\n'.join(lines) + '\n')
        except Exception:
            pass

    def is_auto_enabled(self):
        return self._auto_enabled

    def get_ac_profile(self):
        return self._ac_profile

    def get_battery_profile(self):
        return self._battery_profile

    def set_auto(self, enabled):
        self._auto_enabled = enabled
        self._save_auto_config()
        if enabled:
            self._last_plugged = None  # force immediate check
            self.check_auto_switch()
        status = "enabled" if enabled else "disabled"
        self.notifier.notify("Auto Power", f"Auto-switching {status}", "info", 2000)

    def check_auto_switch(self):
        """Check power source and switch profile automatically if enabled."""
        if not self._auto_enabled:
            return
        try:
            batt = self.get_battery_info()
            plugged = batt.get("plugged")
            if plugged is None:
                return
            if plugged == self._last_plugged:
                return
            self._last_plugged = plugged
            target = self._ac_profile if plugged else self._battery_profile
            self.set_profile(target)
        except Exception:
            pass  # don't let a sysfs read failure kill the caller

    def get_profile_details(self):
        """Return (spl, sppt, fppt) wattages parsed from z13ctl status."""
        try:
            result = self._run_z13ctl(["z13ctl", "status"], timeout=5)
            if result and result.returncode == 0:
                for line in result.stdout.splitlines():
                    if "tdp" in line.lower() and "pl1" in line.lower():
                        vals = [int(m) for m in re.findall(r'(\d+)W', line)]
                        if len(vals) >= 3:
                            return vals[0], vals[1], vals[2]
                        if len(vals) == 1:
                            return vals[0], vals[0], vals[0]
        except Exception:
            pass
        # Fallback: use the profile's configured TDP
        spec = POWER_PROFILES.get(self.current_profile, {})
        tdp = spec.get("tdp") or 40
        return tdp, tdp, tdp

    def set_profile(self, profile):
        try:
            spec = POWER_PROFILES.get(profile)
            if spec:
                z13_profile = spec["z13ctl_profile"]
            else:
                # Accept raw z13ctl profile names (quiet/balanced/performance/custom)
                z13_profile = profile

            # Call z13ctl directly (daemon mode handles permissions)
            result = self._run_z13ctl(["z13ctl", "profile", "--set", z13_profile], timeout=30)
            if result and result.returncode == 0:
                self.notifier.notify_profile_change(profile, result.stdout.strip())
                self.current_profile = profile
                # Persist tray-level profile name (survives restarts)
                try:
                    _PROFILE_CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
                    _PROFILE_CACHE_FILE.write_text(profile + '\n')
                except Exception:
                    pass
                # Apply TDP override if specified (TDP requires elevated privileges)
                if spec and spec.get("tdp"):
                    tdp_val = spec["tdp"]
                    tdp_cmd = ["z13ctl", "tdp", "--set", str(tdp_val)]
                    if tdp_val > 75:
                        tdp_cmd.append("--force")
                    self._run_z13ctl(tdp_cmd, timeout=10)
                return True
            else:
                self.notifier.notify_error("Profile Change Failed", self._result_error(result))
                return False
        except Exception as e:
            self.notifier.notify_error("Profile Change Failed", str(e))
            return False

    def set_tdp(self, watts):
        try:
            result = self._run_z13ctl(["z13ctl", "tdp", "--set", str(watts)], timeout=10)
            if result and result.returncode == 0:
                self.notifier.notify("Power", f"TDP set to {watts}W", "success", 2000)
                return True
            else:
                self.notifier.notify_error("TDP Failed", self._result_error(result))
                return False
        except Exception as e:
            self.notifier.notify_error("Error", str(e))
            return False

    def set_fan_curve(self, curve):
        try:
            result = self._run_z13ctl(["z13ctl", "fancurve", "--set", curve], timeout=10)
            if result and result.returncode == 0:
                self.notifier.notify("Fans", "Custom curve applied", "success", 2000)
                return True
            self.notifier.notify_error("Fan Curve Failed", self._result_error(result))
            return False
        except Exception as e:
            self.notifier.notify_error("Error", str(e))
            return False

    def set_charge_limit(self, limit):
        try:
            result = self._run_z13ctl(["z13ctl", "batterylimit", "--set", str(limit)], timeout=10)
            if result and result.returncode == 0:
                self.notifier.notify(
                    "Battery", f"Charge limit set to {limit}%", "success", 2000
                )
                return True
            else:
                self.notifier.notify_error("Charge Limit Failed", self._result_error(result))
                return False
        except Exception as e:
            self.notifier.notify_error("Error", str(e))
            return False

    def get_status(self):
        try:
            result = self._run_z13ctl(["z13ctl", "status"], timeout=10)
            return result.stdout.strip() if result and result.returncode == 0 else "Unknown"
        except Exception:
            return "Unknown"

    def get_battery_info(self):
        try:
            for sup in Path("/sys/class/power_supply").glob("*"):
                if (sup / "status").exists():
                    status = (sup / "status").read_text().strip().lower()
                    if (sup / "capacity").exists():
                        pct = int((sup / "capacity").read_text().strip())
                        return {
                            "percent": pct,
                            "plugged": status != "discharging",
                            "status": status,
                        }
        except Exception:
            pass
        return {"percent": None, "plugged": None, "status": "unknown"}
