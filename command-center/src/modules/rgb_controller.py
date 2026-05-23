import os
import subprocess
import threading
import queue
from pathlib import Path
from PyQt6.QtCore import QTimer

# Speed mapping: internal numeric → z13ctl speed names
_SPEED_MAP = {1: "slow", 2: "normal", 3: "fast"}
_ZONE_LABELS = {"keyboard": "Keyboard", "lightbar": "Backlight"}

# z13ctl socket path
def get_z13ctl_socket():
    uid = os.getuid()
    runtime_dir = os.environ.get('XDG_RUNTIME_DIR', f'/run/user/{uid}')
    return Path(runtime_dir) / "z13ctl" / "z13ctl.sock"

_Z13CTL_SOCKET = get_z13ctl_socket()


class RGBController:
    """Manages Keyboard and Lightbar RGB control via z13ctl."""

    def __init__(self, notifier):
        self.notifier = notifier
        self.window_animation_thread = None
        self.window_animation_stop = None
        # Command queue for thread-safe serialization
        self._cmd_queue = queue.Queue()
        self._queue_worker_started = False
        self._check_installation()

    def _check_installation(self):
        self.keyboard_available = self.check_available()
        # z13ctl handles both keyboard and lightbar
        self.window_available = self.keyboard_available

    def is_available(self):
        return self.keyboard_available or self.window_available

    def refresh_availability(self):
        self._check_installation()
        return self.is_available()

    def check_available(self):
        """Check if z13ctl binary exists AND daemon is running."""
        try:
            # Check binary first
            for p in ["/usr/local/bin/z13ctl", "/usr/bin/z13ctl"]:
                if Path(p).exists():
                    # Then check daemon socket
                    if Path(_Z13CTL_SOCKET).exists():
                        return True
                    # If socket missing, try one z13ctl command to verify daemon
                    result = subprocess.run(
                        ["z13ctl", "status"],
                        capture_output=True,
                        timeout=2
                    )
                    if result.returncode == 0:
                        return True
                    sudo_result = subprocess.run(
                        ["sudo", "-n", "z13ctl", "status"],
                        capture_output=True,
                        timeout=2,
                    )
                    return sudo_result.returncode == 0
            return False
        except Exception:
            return False

    def _ensure_queue_worker(self):
        """Start the queue worker thread if not already running."""
        if not self._queue_worker_started:
            self._queue_worker_started = True
            threading.Thread(target=self._process_queue, daemon=True).start()

    def _device_command(self, device, *args):
        cmd = ["z13ctl"]
        if device:
            cmd.extend(["--device", device])
        cmd.extend(args)
        return cmd

    def _zone_label(self, device):
        return _ZONE_LABELS.get(device, "RGB")

    def _device_available(self, device):
        if device == "lightbar":
            return self.window_available
        return self.keyboard_available

    def _normalize_hex_color(self, hex_color):
        return hex_color.strip().lstrip("#").upper()

    def _execute_command(self, cmd, success_msg, error_msg, timeout):
        """Execute a single RGB command and notify result."""
        try:
            res = subprocess.run(
                cmd, capture_output=True, text=True, timeout=timeout
            )
            
            # Fallback to sudo -n if permission denied
            if res.returncode != 0 and "permission" in (res.stderr.strip() or res.stdout.strip()).lower():
                sudo_cmd = ["sudo", "-n"] + cmd
                res = subprocess.run(
                    sudo_cmd, capture_output=True, text=True, timeout=timeout
                )

            if res.returncode == 0:
                QTimer.singleShot(0, lambda: self.notifier.notify("RGB", success_msg, "success", 2000))
            else:
                err_detail = (
                    res.stderr.strip() or res.stdout.strip() or "Unknown error"
                )
                if "permission" in err_detail.lower():
                    hint = "Check z13ctl setup: sudo z13ctl setup"
                    msg = f"{error_msg}\n{hint}"
                    QTimer.singleShot(0, lambda m=msg: self.notifier.notify_error("RGB Error", m))
                else:
                    msg = f"{error_msg}: {err_detail[:100]}"
                    QTimer.singleShot(0, lambda m=msg: self.notifier.notify_error("RGB Error", m))
        except subprocess.TimeoutExpired:
            msg = f"{error_msg}: Command timed out"
            QTimer.singleShot(0, lambda m=msg: self.notifier.notify_error("RGB Error", m))
        except FileNotFoundError:
            QTimer.singleShot(0, lambda: self.notifier.notify_error(
                "RGB Error", "z13ctl not found. Run strix-halo-setup.sh"
            ))
            self.keyboard_available = False
            self.window_available = False
        except Exception as e:
            msg = str(e)[:100]
            QTimer.singleShot(0, lambda m=msg: self.notifier.notify_error("RGB Error", m))

    def _process_queue(self):
        """Process RGB commands from queue sequentially."""
        while True:
            try:
                cmd, success_msg, error_msg, timeout = self._cmd_queue.get()
                self._execute_command(cmd, success_msg, error_msg, timeout)
                self._cmd_queue.task_done()
            except Exception:
                continue

    def set_keyboard_color(self, hex_color):
        self.set_static_color("keyboard", hex_color)

    def set_lightbar_color(self, hex_color):
        self.set_static_color("lightbar", hex_color)

    def set_static_color(self, device, hex_color):
        if not self._device_available(device):
            self.notifier.notify_error(
                self._zone_label(device), "z13ctl not installed. Run: sudo ./strix-halo-setup.sh"
            )
            return

        clean_color = self._normalize_hex_color(hex_color)
        self._run_bg_command(
            self._device_command(
                device, "apply", "--mode", "static", "--color", clean_color
            ),
            success_msg=f"{self._zone_label(device)} color set to #{clean_color}",
            error_msg=f"Failed to set {self._zone_label(device).lower()} color",
        )

    def set_keyboard_animation(self, anim_type, c1=None, c2=None, speed=2):
        if not self.keyboard_available:
            self.notifier.notify_error("RGB", "z13ctl not installed")
            return
        speed_name = _SPEED_MAP.get(speed, "normal")
        cmd = self._device_command("keyboard", "apply")
        desc = ""
        if anim_type == "breathing":
            cmd += [
                "--mode", "breathe", "--color", c1 or "FFFFFF", "--speed", speed_name,
            ]
            desc = "Breathing"
        elif anim_type == "colorcycle":
            cmd += ["--mode", "cycle", "--speed", speed_name]
            desc = "Color Cycle"
        elif anim_type == "rainbow":
            cmd += ["--mode", "rainbow", "--speed", speed_name]
            desc = "Rainbow"
        else:
            self.notifier.notify_error("RGB", f"Unknown animation: {anim_type}")
            return
        self._run_bg_command(
            cmd,
            success_msg=f"{desc} activated",
            error_msg="Failed to set animation",
        )

    def set_keyboard_brightness(self, level):
        if not (0 <= level <= 3):
            return
        if not self.keyboard_available:
            self.notifier.notify_error("RGB", "z13ctl not installed")
            return
        level_name = {0: "off", 1: "low", 2: "medium", 3: "high"}.get(level, "medium")
        self._run_bg_command(
            self._device_command("keyboard", "brightness", level_name),
            success_msg=f"Keyboard brightness set to {level_name}",
            error_msg="Failed to set keyboard brightness",
            timeout=5,
        )

    def turn_off(self):
        if not self.keyboard_available:
            return
        self._run_bg_command(
            ["z13ctl", "off"],
            success_msg="Lighting turned off",
            error_msg="Failed to turn off lighting",
        )

    def turn_off_keyboard(self):
        if not self.keyboard_available:
            return
        self._run_bg_command(
            self._device_command("keyboard", "off"),
            success_msg="Keyboard lighting turned off",
            error_msg="Failed to turn off keyboard lighting",
        )

    def turn_off_lightbar(self):
        if not self.window_available:
            return
        self._run_bg_command(
            self._device_command("lightbar", "off"),
            success_msg="Backlight turned off",
            error_msg="Failed to turn off backlight",
        )

    def _run_bg_command(self, cmd, success_msg, error_msg, timeout=60):
        """Enqueue RGB command for sequential processing (thread-safe)."""
        self._ensure_queue_worker()
        self._cmd_queue.put((cmd, success_msg, error_msg, timeout))

    # --- Window / Lightbar ---
    # z13ctl handles lightbar natively; these methods provide tray-level
    # animation that calls z13ctl apply per frame for advanced effects
    # not yet supported by z13ctl's built-in modes.

    def set_window_backlight(self, level):
        if not self.window_available:
            self.notifier.notify_error("Lightbar", "z13ctl not installed")
            return
        if level == 0:
            self.turn_off_lightbar()
        else:
            level_name = {1: "low", 2: "medium", 3: "high"}.get(level, "medium")
            self._run_bg_command(
                self._device_command("lightbar", "brightness", level_name),
                success_msg=f"Backlight brightness set to {level_name}",
                error_msg="Failed to set backlight brightness",
            )

    def set_window_color(self, r, g, b):
        self.stop_window_animation()
        if not self.window_available:
            self.notifier.notify_error("Lightbar", "z13ctl not installed")
            return
        hex_color = f"{r:02x}{g:02x}{b:02x}"
        self.set_lightbar_color(hex_color)

    def stop_window_animation(self):
        if self.window_animation_stop:
            self.window_animation_stop.set()
        if self.window_animation_thread:
            self.window_animation_thread.join(timeout=1)
        self.window_animation_stop = None
        self.window_animation_thread = None

    def start_window_animation(self, anim_type, c1=None, c2=None, speed=2):
        self.stop_window_animation()
        speed_name = _SPEED_MAP.get(speed, "normal")
        # Use z13ctl's built-in animation modes when available
        if anim_type == "rainbow":
            self._run_bg_command(
                [
                    "z13ctl", "--device", "lightbar", "apply",
                    "--mode", "rainbow", "--speed", speed_name,
                ],
                success_msg="Backlight rainbow activated",
                error_msg="Failed to set backlight animation",
            )
            return
        if anim_type == "breathing":
            color = f"{c1[0]:02x}{c1[1]:02x}{c1[2]:02x}" if c1 else "FFFFFF"
            self._run_bg_command(
                [
                    "z13ctl", "--device", "lightbar", "apply",
                    "--mode", "breathe", "--color", color, "--speed", speed_name,
                ],
                success_msg="Backlight breathing activated",
                error_msg="Failed to set backlight animation",
            )
            return
        self.notifier.notify(
            "Backlight", f"Animation: {anim_type.title()}", "success", 2000
        )
