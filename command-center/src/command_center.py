#!/usr/bin/env python3
"""
GZ302 Command Center — Strix Halo Edition (v6.4.0)
Unified Dashboard and System Tray Controller.
Inspired by G-Helper and Strix-Halo-Control.
"""
import sys
import os
import signal
import shutil
import subprocess
import re
from pathlib import Path
from PyQt6.QtWidgets import (
    QApplication, QSystemTrayIcon, QMenu, QWidget, QVBoxLayout,
    QHBoxLayout, QLabel, QPushButton, QFrame, QGridLayout,
    QColorDialog, QSlider, QProgressBar, QLineEdit, QSizePolicy
)
from PyQt6.QtGui import QIcon, QAction, QActionGroup, QColor, QFont, QPainter, QPixmap, QCursor
from PyQt6.QtCore import QTimer, Qt, QPoint, QRect, QSize

try:
    from PyQt6.QtSvg import QSvgRenderer
except ImportError:
    QSvgRenderer = None

try:
    import psutil
except ImportError:
    psutil = None

# Import modules
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from modules.config import ConfigManager
from modules.notifications import NotificationManager
from modules.rgb_controller import RGBController
from modules.power_controller import PowerController

TRAY_ICON_SIZE = 24
VERSION = "6.4.0"
DASHBOARD_WINDOW_TITLE = "GZ302 Dashboard"
DASHBOARD_WINDOW_ROLE = "gz302-dashboard"
KWIN_DASHBOARD_SCRIPT_NAME = "gz302_dashboard_anchor"
RGB_COLOR_PRESETS = [
    ("Ice", "7FDBFF"),
    ("Mint", "2ECC71"),
    ("Lemon", "F1C40F"),
    ("Amber", "F39C12"),
    ("Coral", "FF6B6B"),
    ("Rose", "FF4D8D"),
    ("Violet", "9B59B6"),
    ("White", "FFFFFF"),
]

class DashboardWindow(QWidget):
    """G-Helper-style compact popup panel."""

    # All 8 profiles: (display label, z13ctl code, accent color)
    PROFILES = [
        ("Emergency\n10W",  "emergency", "#555"),
        ("Battery\n18W",    "battery",   "#4a9"),
        ("Efficient\n30W",  "efficient", "#4ae"),
        ("Silent",          "quiet",     "#59c"),
        ("Balanced\n40W",   "balanced",  "#88c"),
        ("Turbo\n55W",      "performance","#c84"),
        ("Gaming\n70W",     "gaming",    "#e63"),
        ("Maximum\n90W",    "maximum",   "#e33"),
    ]

    def __init__(self, power_ctrl, rgb_controller, config, notifier):
        super().__init__()
        self.power = power_ctrl
        self.rgb = rgb_controller
        self.config = config
        self.notifier = notifier
        self._profile_btns = {}

        self.setWindowTitle(DASHBOARD_WINDOW_TITLE)
        self.setWindowRole(DASHBOARD_WINDOW_ROLE)
        self.setWindowFlags(
            Qt.WindowType.FramelessWindowHint |
            Qt.WindowType.Tool |
            Qt.WindowType.WindowStaysOnTopHint
        )
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, False)

        self.setup_ui()
        self.apply_styles()

    # ------------------------------------------------------------------
    # UI construction
    # ------------------------------------------------------------------
    def setup_ui(self):
        root = QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        root.addWidget(self._build_header())
        root.addWidget(self._build_stats_bar())
        root.addWidget(self._build_divider())
        root.addWidget(self._build_profiles_section())
        root.addWidget(self._build_divider())
        root.addWidget(self._build_battery_section())
        root.addWidget(self._build_divider())
        root.addWidget(self._build_rgb_section())
        root.addWidget(self._build_divider())
        root.addWidget(self._build_fan_section())
        root.addWidget(self._build_footer())

    def _build_header(self):
        header = QFrame()
        header.setObjectName("header")
        hbox = QHBoxLayout(header)
        hbox.setContentsMargins(14, 10, 14, 10)

        title = QLabel("ROG Flow Z13 · GZ302")
        title.setObjectName("title_label")
        hbox.addWidget(title)

        hbox.addStretch()

        close_btn = QPushButton("✕")
        close_btn.setObjectName("close_btn")
        close_btn.setFixedSize(24, 24)
        close_btn.clicked.connect(self.hide)
        hbox.addWidget(close_btn)
        return header

    def _build_stats_bar(self):
        bar = QFrame()
        bar.setObjectName("stats_bar")
        hbox = QHBoxLayout(bar)
        hbox.setContentsMargins(14, 8, 14, 8)
        hbox.setSpacing(16)

        self.stat_temp  = self._stat_widget("APU", "--°C")
        self.stat_fans  = self._stat_widget("FANS", "-- RPM")
        self.stat_pwr   = self._stat_widget("MODE", "Balanced")
        self.stat_bat   = self._stat_widget("BATTERY", "--%")
        self.stat_cpu   = self._stat_widget("CPU", "0%")

        for w in (self.stat_temp, self.stat_fans, self.stat_pwr, self.stat_bat, self.stat_cpu):
            hbox.addWidget(w)
        return bar

    def _stat_widget(self, label, value):
        frame = QFrame()
        frame.setObjectName("stat_card")
        vbox = QVBoxLayout(frame)
        vbox.setContentsMargins(8, 6, 8, 6)
        vbox.setSpacing(1)
        lbl = QLabel(label)
        lbl.setObjectName("stat_label")
        val = QLabel(value)
        val.setObjectName("stat_value")
        vbox.addWidget(lbl)
        vbox.addWidget(val)
        # store the value label as attribute on the frame for easy update
        frame._value_lbl = val
        return frame

    def _build_profiles_section(self):
        section = QFrame()
        section.setObjectName("section")
        vbox = QVBoxLayout(section)
        vbox.setContentsMargins(14, 10, 14, 10)
        vbox.setSpacing(6)

        vbox.addWidget(self._section_title("PERFORMANCE"))

        grid = QGridLayout()
        grid.setSpacing(5)
        for i, (label, code, color) in enumerate(self.PROFILES):
            btn = QPushButton(label)
            btn.setObjectName("profile_btn")
            btn.setProperty("profile_color", color)
            btn.setCheckable(True)
            btn.setFixedHeight(52)
            btn.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed)
            btn.clicked.connect(lambda _, c=code: self._set_profile(c))
            self._profile_btns[code] = btn
            grid.addWidget(btn, i // 4, i % 4)
        vbox.addLayout(grid)
        return section

    def _build_battery_section(self):
        section = QFrame()
        section.setObjectName("section")
        vbox = QVBoxLayout(section)
        vbox.setContentsMargins(14, 10, 14, 10)
        vbox.setSpacing(6)
        vbox.addWidget(self._section_title("BATTERY LIMIT"))

        hbox = QHBoxLayout()
        hbox.setSpacing(6)
        self._bat_btns = {}
        for lim in [60, 80, 100]:
            btn = QPushButton(f"{lim}%")
            btn.setObjectName("bat_btn")
            btn.setCheckable(True)
            btn.setFixedHeight(32)
            btn.clicked.connect(lambda _, l=lim: self._set_charge_limit(l))
            self._bat_btns[lim] = btn
            hbox.addWidget(btn)
        vbox.addLayout(hbox)
        return section

    def _build_rgb_section(self):
        section = QFrame()
        section.setObjectName("section")
        vbox = QVBoxLayout(section)
        vbox.setContentsMargins(14, 10, 14, 10)
        vbox.setSpacing(6)
        vbox.addWidget(self._section_title("RGB LIGHTING"))

        vbox.addWidget(
            self._build_color_row(
                "Keyboard", self.rgb.set_keyboard_color, self.rgb.turn_off_keyboard
            )
        )
        vbox.addWidget(
            self._build_color_row(
                "Backlight", self.rgb.set_lightbar_color, self.rgb.turn_off_lightbar
            )
        )

        hbox = QHBoxLayout()
        hbox.setSpacing(6)
        hbox.addWidget(self._rgb_row_label("Keyboard"))
        for label, val in [("Off", 0), ("Low", 1), ("Med", 2), ("High", 3)]:
            btn = QPushButton(label)
            btn.setObjectName("rgb_btn")
            btn.setFixedHeight(28)
            btn.clicked.connect(lambda _, v=val: self.rgb.set_keyboard_brightness(v))
            hbox.addWidget(btn)
        hbox.addStretch()
        vbox.addLayout(hbox)

        hbox = QHBoxLayout()
        hbox.setSpacing(6)
        hbox.addWidget(self._rgb_row_label("Keyboard FX"))
        for label, fx in [("Rainbow", "rainbow"), ("Breathing", "breathing"), ("Off", None)]:
            btn = QPushButton(label)
            btn.setObjectName("rgb_btn")
            btn.setFixedHeight(28)
            if fx:
                btn.clicked.connect(lambda _, e=fx: self.rgb.set_keyboard_animation(e))
            else:
                btn.clicked.connect(self.rgb.turn_off_keyboard)
            hbox.addWidget(btn)
        hbox.addStretch()
        vbox.addLayout(hbox)
        return section

    def _build_color_row(self, zone_label, apply_color, turn_off):
        row = QFrame()
        row.setObjectName("rgb_zone_row")
        hbox = QHBoxLayout(row)
        hbox.setContentsMargins(0, 0, 0, 0)
        hbox.setSpacing(6)
        hbox.addWidget(self._rgb_row_label(zone_label))

        for color_name, hex_color in RGB_COLOR_PRESETS:
            hbox.addWidget(
                self._build_color_swatch(zone_label, color_name, hex_color, apply_color)
            )

        custom_btn = QPushButton("Custom")
        custom_btn.setObjectName("rgb_minor_btn")
        custom_btn.setFixedHeight(24)
        custom_btn.clicked.connect(
            lambda _, zone=zone_label, callback=apply_color: self._pick_custom_color(zone, callback)
        )
        hbox.addWidget(custom_btn)

        off_btn = QPushButton("Off")
        off_btn.setObjectName("rgb_minor_btn")
        off_btn.setFixedHeight(24)
        off_btn.clicked.connect(turn_off)
        hbox.addWidget(off_btn)
        hbox.addStretch()
        return row

    def _build_color_swatch(self, zone_label, color_name, hex_color, apply_color):
        btn = QPushButton()
        btn.setObjectName("rgb_swatch_btn")
        btn.setToolTip(f"{zone_label}: {color_name}")
        btn.setFixedSize(22, 22)
        btn.setCursor(Qt.CursorShape.PointingHandCursor)
        btn.clicked.connect(lambda _, value=hex_color: apply_color(value))
        btn.setStyleSheet(
            f"QPushButton {{"
            f"background-color: #{hex_color};"
            "border: 1px solid #2a2a2a;"
            "border-radius: 11px;"
            "padding: 0;"
            "}"
            "QPushButton:hover { border: 2px solid #f5f5f5; }"
            "QPushButton:pressed { border: 2px solid #ff4655; }"
        )
        return btn

    def _pick_custom_color(self, zone_label, apply_color):
        color = QColorDialog.getColor(QColor("#FFFFFF"), self, f"{zone_label} Color")
        if color.isValid():
            apply_color(color.name().lstrip("#").upper())

    def _rgb_row_label(self, text):
        lbl = QLabel(text)
        lbl.setObjectName("rgb_zone_label")
        lbl.setFixedWidth(68)
        return lbl

    def _build_fan_section(self):
        section = QFrame()
        section.setObjectName("section")
        vbox = QVBoxLayout(section)
        vbox.setContentsMargins(14, 10, 14, 10)
        vbox.setSpacing(6)
        vbox.addWidget(self._section_title("CUSTOM FAN CURVE"))

        hbox = QHBoxLayout()
        hbox.setSpacing(6)
        self.curve_input = QLineEdit()
        self.curve_input.setPlaceholderText("48:2,53:22,57:30,60:43,63:56,65:68,70:89,76:102")
        self.curve_input.setObjectName("curve_input")
        hbox.addWidget(self.curve_input)
        apply_btn = QPushButton("Apply")
        apply_btn.setObjectName("apply_btn")
        apply_btn.setFixedHeight(30)
        apply_btn.clicked.connect(self._apply_fan_curve)
        hbox.addWidget(apply_btn)
        vbox.addLayout(hbox)
        return section

    def _build_footer(self):
        footer = QFrame()
        footer.setObjectName("footer")
        hbox = QHBoxLayout(footer)
        hbox.setContentsMargins(14, 6, 14, 8)

        auto_btn = QPushButton("⚡ Auto Switch")
        auto_btn.setObjectName("footer_btn")
        auto_btn.setCheckable(True)
        auto_btn.setChecked(self.power.is_auto_enabled())
        auto_btn.toggled.connect(lambda checked: self.power.set_auto(checked))
        self._auto_btn = auto_btn
        hbox.addWidget(auto_btn)

        hbox.addStretch()

        ver_lbl = QLabel(f"v{VERSION}")
        ver_lbl.setObjectName("ver_label")
        hbox.addWidget(ver_lbl)
        return footer

    def _build_divider(self):
        line = QFrame()
        line.setObjectName("divider")
        line.setFixedHeight(1)
        return line

    def _section_title(self, text):
        lbl = QLabel(text)
        lbl.setObjectName("section_title")
        return lbl

    # ------------------------------------------------------------------
    # Styling
    # ------------------------------------------------------------------
    def apply_styles(self):
        self.setStyleSheet("""
            QWidget {
                background-color: #111;
                color: #ddd;
                font-family: "Segoe UI", "Noto Sans", sans-serif;
                font-size: 12px;
            }
            #header {
                background-color: #1a1a1a;
            }
            #title_label {
                font-size: 13px;
                font-weight: bold;
                color: #ff4655;
                text-transform: uppercase;
            }
            #close_btn {
                background: transparent;
                border: none;
                color: #555;
                font-size: 13px;
                padding: 0;
            }
            #close_btn:hover { color: #ff4655; }

            #stats_bar {
                background-color: #151515;
            }
            #stat_card {
                background-color: #1c1c1c;
                border-radius: 6px;
                min-width: 70px;
            }
            #stat_label {
                font-size: 9px;
                color: #555;
                text-transform: uppercase;
            }
            #stat_value {
                font-size: 13px;
                font-weight: bold;
                color: #eee;
            }

            #divider { background-color: #222; }

            #section { background-color: #111; }

            #section_title {
                font-size: 9px;
                font-weight: bold;
                color: #444;
                text-transform: uppercase;
                letter-spacing: 1px;
            }

            QPushButton#profile_btn {
                background-color: #1c1c1c;
                border: 1px solid #2a2a2a;
                border-radius: 6px;
                color: #bbb;
                font-size: 11px;
                padding: 4px;
            }
            QPushButton#profile_btn:hover {
                background-color: #252525;
                border-color: #444;
                color: #fff;
            }
            QPushButton#profile_btn:checked {
                background-color: #1e1e1e;
                border-color: #ff4655;
                color: #ff4655;
                font-weight: bold;
            }

            QPushButton#bat_btn, QPushButton#rgb_btn {
                background-color: #1c1c1c;
                border: 1px solid #2a2a2a;
                border-radius: 5px;
                color: #aaa;
            }
            QPushButton#bat_btn:hover, QPushButton#rgb_btn:hover {
                background-color: #252525;
                color: #fff;
            }
            QPushButton#bat_btn:checked {
                border-color: #ff4655;
                color: #ff4655;
            }

            QLineEdit#curve_input {
                background-color: #1c1c1c;
                border: 1px solid #2a2a2a;
                border-radius: 4px;
                color: #aaa;
                padding: 4px 8px;
                font-size: 11px;
            }
            QPushButton#apply_btn {
                background-color: #1c1c1c;
                border: 1px solid #333;
                border-radius: 4px;
                color: #aaa;
                padding: 0 10px;
            }
            QPushButton#apply_btn:hover {
                background-color: #ff4655;
                border-color: #ff4655;
                color: #fff;
            }

            #footer { background-color: #0d0d0d; }
            QPushButton#footer_btn {
                background-color: transparent;
                border: 1px solid #2a2a2a;
                border-radius: 4px;
                color: #555;
                padding: 2px 10px;
                font-size: 11px;
            }
            QPushButton#footer_btn:hover { color: #aaa; border-color: #444; }
            QPushButton#footer_btn:checked { color: #ff4655; border-color: #ff4655; }
            #ver_label { font-size: 10px; color: #333; }
            #rgb_zone_label {
                font-size: 10px;
                font-weight: bold;
                color: #666;
                text-transform: uppercase;
            }
            QPushButton#rgb_minor_btn {
                background-color: #171717;
                border: 1px solid #2a2a2a;
                border-radius: 4px;
                color: #aaa;
                padding: 0 8px;
            }
            QPushButton#rgb_minor_btn:hover {
                background-color: #252525;
                color: #fff;
            }
        """)
        self.adjustSize()

    # ------------------------------------------------------------------
    # Popup positioning - anchored to the bottom-right corner
    # ------------------------------------------------------------------
    def popup_near_tray(self, tray_icon):
        """Position the window in the bottom-right corner of the screen."""
        screen = QApplication.screenAt(QCursor.pos()) or QApplication.primaryScreen()
        screen_geom = screen.availableGeometry()
        self.adjustSize()
        x = screen_geom.right() - self.width() - 8
        y = screen_geom.bottom() - self.height() - 8
        self.move(x, y)
        if self.windowHandle() is not None:
            self.windowHandle().setPosition(x, y)

    # ------------------------------------------------------------------
    # Focus loss -> close (like a popup)
    # ------------------------------------------------------------------
    def focusOutEvent(self, event):
        super().focusOutEvent(event)
        QTimer.singleShot(150, self._check_hide)

    def _check_hide(self):
        if not self.isActiveWindow():
            self.hide()

    # ------------------------------------------------------------------
    # ------------------------------------------------------------------
    # Actions
    # ------------------------------------------------------------------
    def _set_profile(self, code):
        self.power.set_profile(code)
        self._update_profile_buttons()

    def _update_profile_buttons(self):
        active = self.power.current_profile
        for code, btn in self._profile_btns.items():
            btn.setChecked(code == active)

    def _set_charge_limit(self, lim):
        self.power.set_charge_limit(lim)
        for l, btn in self._bat_btns.items():
            btn.setChecked(l == lim)

    def _apply_fan_curve(self):
        curve = self.curve_input.text().strip()
        if curve:
            self.power.set_fan_curve(curve)

    # ------------------------------------------------------------------
    # Live stat updates (called by poll_status timer)
    # ------------------------------------------------------------------
    def update_ui_states(self):
        try:
            status = self.power.get_status()
            temp, fans = "--°C", "-- RPM"
            for line in status.splitlines():
                if "APU:" in line:
                    temp = line.split(":", 1)[1].strip()
                if "Fans:" in line:
                    fans = re.sub(r",\s*mode:.*", "", line.split(":", 1)[1].strip())

            self.stat_temp._value_lbl.setText(temp)
            self.stat_fans._value_lbl.setText(fans)
            self.stat_pwr._value_lbl.setText(self.power.current_profile.title())

            bat_info = self.power.get_battery_info()
            pct = bat_info.get("percent")
            if pct is not None:
                self.stat_bat._value_lbl.setText(f"{int(pct)}%")

            if psutil:
                self.stat_cpu._value_lbl.setText(f"{int(psutil.cpu_percent())}%")
        except Exception:
            pass

        self._update_profile_buttons()
        self._auto_btn.setChecked(self.power.is_auto_enabled())

class CommandCenterApp(QSystemTrayIcon):
    def __init__(self, app):
        super().__init__()
        self.app = app
        self.config = ConfigManager()
        self.notifier = NotificationManager(self)
        self.rgb = RGBController(self.notifier)
        self.power = PowerController(self.notifier)
        
        self.dashboard = DashboardWindow(self.power, self.rgb, self.config, self.notifier)
        self._kwin_script_loaded = False
        self._setup_kwin_dashboard_positioner()
        
        self.menu = QMenu()
        self.menu.aboutToShow.connect(self.setup_menu)
        self.setup_menu()
        # Keep the native context menu attached so Plasma exposes right-click
        # actions consistently through the status notifier integration.
        self.setContextMenu(self.menu)

        self.activated.connect(self._on_activated)
        self.update_icon()
        self.show()
        
        self.timer = QTimer()
        self.timer.timeout.connect(self.poll_status)
        self.timer.start(3000)
        
        self.notifier.notify("Strix Halo", "Control Panel Ready", "success", 2000)

    def _build_color_icon(self, hex_color):
        pixmap = QPixmap(14, 14)
        pixmap.fill(Qt.GlobalColor.transparent)
        painter = QPainter(pixmap)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        painter.setBrush(QColor(f"#{hex_color}"))
        painter.setPen(QColor("#2a2a2a"))
        painter.drawEllipse(1, 1, 12, 12)
        painter.end()
        return QIcon(pixmap)

    def _open_custom_color_dialog(self, zone_label, apply_color):
        color = QColorDialog.getColor(QColor("#FFFFFF"), self.dashboard, f"{zone_label} Color")
        if color.isValid():
            apply_color(color.name().lstrip("#").upper())

    def _populate_static_color_menu(self, menu, zone_label, apply_color, turn_off):
        for color_name, hex_color in RGB_COLOR_PRESETS:
            action = QAction(color_name, self)
            action.setIcon(self._build_color_icon(hex_color))
            action.triggered.connect(lambda _, value=hex_color: apply_color(value))
            menu.addAction(action)

        menu.addSeparator()
        menu.addAction("Custom...").triggered.connect(
            lambda _=False, zone=zone_label, callback=apply_color: self._open_custom_color_dialog(zone, callback)
        )
        menu.addAction("Off").triggered.connect(turn_off)

    def setup_menu(self):
        self.menu.clear()
        self.menu.addAction("🖥️ Open Dashboard").triggered.connect(
            lambda _=False: QTimer.singleShot(0, self._show_dashboard)
        )
        self.menu.addSeparator()

        # --- Power Profiles ---
        profiles_menu = self.menu.addMenu("⚡ Profiles")
        profile_group = QActionGroup(profiles_menu)
        for n, c in [
            ("Emergency (10W)", "emergency"),
            ("Battery (18W)", "battery"),
            ("Efficient (30W)", "efficient"),
            ("Silent (Quiet)", "quiet"),
            ("Balanced (40W)", "balanced"),
            ("Turbo (55W)", "performance"),
            ("Gaming (70W)", "gaming"),
            ("Maximum (90W)", "maximum")
        ]:
            a = QAction(n, self)
            a.setCheckable(True)
            a.setChecked(self.power.current_profile == c)
            a.triggered.connect(lambda _, code=c: self.power.set_profile(code))
            profiles_menu.addAction(a)
            profile_group.addAction(a)

        # --- Battery Limit ---
        limit_menu = self.menu.addMenu("🔋 Battery Limit")
        for lim in [60, 80, 100]:
            a = QAction(f"Limit to {lim}%", self)
            a.triggered.connect(lambda _, l=lim: self.power.set_charge_limit(l))
            limit_menu.addAction(a)

        self.menu.addSeparator()

        # --- RGB Lighting ---
        rgb_menu = self.menu.addMenu("🌈 RGB Lighting")
        static_menu = rgb_menu.addMenu("🎨 Static Colors")
        self._populate_static_color_menu(
            static_menu.addMenu("⌨️ Keyboard"),
            "Keyboard",
            self.rgb.set_keyboard_color,
            self.rgb.turn_off_keyboard,
        )
        self._populate_static_color_menu(
            static_menu.addMenu("💡 Backlight"),
            "Backlight",
            self.rgb.set_lightbar_color,
            self.rgb.turn_off_lightbar,
        )
        
        # Brightness Submenu
        bright_menu = rgb_menu.addMenu("⌨️ Keyboard Brightness")
        for label, val in [("Off", 0), ("Low", 1), ("Medium", 2), ("High", 3)]:
            a = QAction(label, self)
            a.triggered.connect(lambda _, v=val: self.rgb.set_keyboard_brightness(v))
            bright_menu.addAction(a)

        lightbar_menu = rgb_menu.addMenu("💡 Backlight Brightness")
        for label, val in [("Off", 0), ("Low", 1), ("Medium", 2), ("High", 3)]:
            a = QAction(label, self)
            a.triggered.connect(lambda _, v=val: self.rgb.set_window_backlight(v))
            lightbar_menu.addAction(a)
            
        # Effects Submenu
        effects_menu = rgb_menu.addMenu("✨ Keyboard Effects")
        for label, effect in [("Rainbow", "rainbow"), ("Color Cycle", "colorcycle"), ("Breathing", "breathing")]:
            a = QAction(label, self)
            a.triggered.connect(lambda _, e=effect: self.rgb.set_keyboard_animation(e))
            effects_menu.addAction(a)

        lightbar_fx_menu = rgb_menu.addMenu("✨ Backlight Effects")
        for label, effect in [("Rainbow", "rainbow"), ("Breathing", "breathing")]:
            a = QAction(label, self)
            a.triggered.connect(lambda _, e=effect: self.rgb.start_window_animation(e))
            lightbar_fx_menu.addAction(a)
        lightbar_fx_menu.addAction("Off").triggered.connect(self.rgb.turn_off_lightbar)
            
        rgb_menu.addAction("❌ Turn Off All").triggered.connect(self.rgb.turn_off)

        self.menu.addSeparator()

        # --- Auto Settings ---
        auto_action = QAction("🔄 Auto Settings Adjust", self)
        auto_action.setCheckable(True)
        auto_action.setChecked(self.power.is_auto_enabled())
        auto_action.triggered.connect(lambda checked: self.power.set_auto(checked))
        self.menu.addAction(auto_action)

        self.menu.addSeparator()
        self.menu.addAction("❌ Quit").triggered.connect(self.app.quit)

    def _run_kwin_script_command(self, method, *args):
        try:
            return subprocess.run(
                ["qdbus6", "org.kde.KWin", "/Scripting", method, *args],
                capture_output=True,
                text=True,
                timeout=5,
                check=False,
            )
        except (OSError, subprocess.SubprocessError):
            return None

    def _setup_kwin_dashboard_positioner(self):
        if os.environ.get("XDG_SESSION_TYPE") != "wayland":
            return
        if "KDE" not in os.environ.get("XDG_CURRENT_DESKTOP", ""):
            return
        if not shutil.which("qdbus6"):
            return

        script_path = Path(__file__).resolve().with_name("kwin_dashboard_positioner.js")
        if not script_path.exists():
            return

        self._run_kwin_script_command(
            "org.kde.kwin.Scripting.unloadScript",
            KWIN_DASHBOARD_SCRIPT_NAME,
        )
        load_result = self._run_kwin_script_command(
            "org.kde.kwin.Scripting.loadScript",
            str(script_path),
            KWIN_DASHBOARD_SCRIPT_NAME,
        )
        if load_result is None or load_result.returncode != 0:
            return

        start_result = self._run_kwin_script_command("org.kde.kwin.Scripting.start")
        self._kwin_script_loaded = start_result is not None and start_result.returncode == 0

    def _show_dashboard(self):
        """Show the dashboard and let KWin/Qt place it."""
        self.dashboard.update_ui_states()
        self.dashboard.show()
        QTimer.singleShot(0, self._finalize_dashboard_show)

    def _finalize_dashboard_show(self):
        self.dashboard.popup_near_tray(self)
        self.dashboard.raise_()
        self.dashboard.activateWindow()

    def _on_activated(self, reason):
        if reason in (
            QSystemTrayIcon.ActivationReason.Trigger,
            QSystemTrayIcon.ActivationReason.DoubleClick,
            QSystemTrayIcon.ActivationReason.Unknown,
        ):
            if self.dashboard.isVisible():
                self.dashboard.hide()
            else:
                QTimer.singleShot(50, self._show_dashboard)

    def update_icon(self):
        assets = Path(__file__).resolve().parent.parent / "assets"
        icon_name = "battery" if self.power.is_auto_enabled() and not self.power.get_battery_info().get("plugged") else "ac"
        if not self.power.is_auto_enabled():
            icon_name = {"quiet": "profile-b", "balanced": "profile-b", "performance": "profile-p", "gaming": "profile-g"}.get(self.power.current_profile, "profile-b")

        icon_path = assets / f"{icon_name}.svg"
        if QSvgRenderer is not None and icon_path.exists():
            renderer = QSvgRenderer(str(icon_path))
            if renderer.isValid():
                pixmap = QPixmap(TRAY_ICON_SIZE, TRAY_ICON_SIZE)
                pixmap.fill(Qt.GlobalColor.transparent)
                painter = QPainter(pixmap)
                renderer.render(painter)
                painter.end()
                self.setIcon(QIcon(pixmap))
                return

        # Fallback: paint a simple letter-based icon so the tray is never blank
        label = {"battery": "B", "ac": "A", "profile-b": "B", "profile-p": "P",
                 "profile-g": "G", "profile-e": "E", "profile-f": "F", "profile-m": "M"}.get(icon_name, "R")
        color = {"profile-p": "#e44", "profile-g": "#e84", "battery": "#4ae", "ac": "#8e4"}.get(icon_name, "#aaa")
        pixmap = QPixmap(TRAY_ICON_SIZE, TRAY_ICON_SIZE)
        pixmap.fill(Qt.GlobalColor.transparent)
        painter = QPainter(pixmap)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        painter.setBrush(QColor(color))
        painter.setPen(Qt.PenStyle.NoPen)
        painter.drawEllipse(1, 1, TRAY_ICON_SIZE - 2, TRAY_ICON_SIZE - 2)
        painter.setPen(QColor("#fff"))
        font = painter.font()
        font.setBold(True)
        font.setPixelSize(TRAY_ICON_SIZE - 8)
        painter.setFont(font)
        painter.drawText(pixmap.rect(), Qt.AlignmentFlag.AlignCenter, label)
        painter.end()
        self.setIcon(QIcon(pixmap))

    def poll_status(self):
        try:
            self.power.check_auto_switch()
            self.update_icon()
            if self.dashboard.isVisible(): self.dashboard.update_ui_states()
        except Exception: pass

def main():
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    app = QApplication(sys.argv)
    app.setApplicationName("GZ302 Dashboard")
    app.setQuitOnLastWindowClosed(False)
    
    if not QSystemTrayIcon.isSystemTrayAvailable():
        for _ in range(10):
            import time
            time.sleep(1)
            if QSystemTrayIcon.isSystemTrayAvailable(): break
            
    tray = CommandCenterApp(app)
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
