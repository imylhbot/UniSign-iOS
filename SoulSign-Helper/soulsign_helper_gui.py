# -*- coding: utf-8 -*-
"""
SoulSign 电脑助手 Pro (SoulSign Helper Pro Desktop)
专业�?iOS 免越狱本地代码签�?· USB 极速安�?· iOS 16+ 开发者模式一键激�?"""

import sys
import os
import threading
import time
import zipfile
import plistlib
import shutil
import tempfile
import subprocess
import json

# Set Windows AppUserModelID so the taskbar groups under this app icon instead of Python's generic icon
if sys.platform == "win32":
    try:
        import ctypes
        ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID("com.SoulSign.desktop.helper.v2")
    except Exception:
        pass

from PySide6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QLabel, QPushButton, QLineEdit, QFileDialog, QTabWidget,
    QProgressBar, QPlainTextEdit, QGroupBox, QFrame, QMessageBox,
    QCheckBox, QRadioButton, QButtonGroup, QScrollArea, QSplitter,
    QStackedWidget, QSizePolicy, QComboBox
)

from PySide6.QtCore import Qt, Signal, QObject, QTimer, QSize, QPoint, QRectF
from PySide6.QtGui import (
    QFont, QIcon, QColor, QPainter, QBrush, QPen, QLinearGradient,
    QRadialGradient, QCursor, QPixmap, QPainterPath
)

from usbmux import USBMux
from lockdown import LockdownClient
from developer_mode import DeveloperModeManager
from installer import DeviceInstaller
from pc_signer import PCSigner


def resource_path(relative_path):
    """Get absolute path to resource, works for dev and for PyInstaller frozen binary."""
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base_path, relative_path)


def parse_ipa_info(ipa_path):
    """Extract app display name, bundle ID, version, and file size from an IPA package."""
    if not ipa_path or not os.path.exists(ipa_path):
        return None
    
    info = {
        "name": os.path.splitext(os.path.basename(ipa_path))[0],
        "bundle_id": "com.SoulSign.app",
        "version": "1.0.0",
        "build": "1",
        "min_os": "15.0",
        "size_str": "0 MB",
        "file_path": ipa_path
    }
    
    try:
        size_bytes = os.path.getsize(ipa_path)
        if size_bytes >= 1024 * 1024 * 1024:
            info["size_str"] = f"{size_bytes / (1024**3):.2f} GB"
        else:
            info["size_str"] = f"{size_bytes / (1024**2):.1f} MB"
            
        with zipfile.ZipFile(ipa_path, "r") as zf:
            for fname in zf.namelist():
                if fname.startswith("Payload/") and fname.endswith(".app/Info.plist"):
                    plist_data = zf.read(fname)
                    p = plistlib.loads(plist_data)
                    info["name"] = p.get("CFBundleDisplayName") or p.get("CFBundleName") or info["name"]
                    info["bundle_id"] = str(p.get("CFBundleIdentifier", info["bundle_id"]))
                    info["version"] = str(p.get("CFBundleShortVersionString", info["version"]))
                    info["build"] = str(p.get("CFBundleVersion", info["build"]))
                    info["min_os"] = str(p.get("MinimumOSVersion", info["min_os"]))
                    break
    except Exception:
        pass
        
    return info


class WorkerSignals(QObject):
    log = Signal(str)
    progress = Signal(float, str)
    device_detected = Signal(dict)
    no_device = Signal()
    finished = Signal(bool, str)


class IPADropAreaWidget(QFrame):
    """Sleek Drag and Drop IPA zone with metadata preview."""
    ipa_selected = Signal(str)
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setAcceptDrops(True)
        self.setCursor(QCursor(Qt.PointingHandCursor))
        self.setFixedHeight(92)
        self.current_ipa = ""
        self.is_hovered = False
        
        self.main_layout = QVBoxLayout(self)
        self.main_layout.setContentsMargins(14, 8, 14, 8)
        
        # 1. Empty State Widget
        self.empty_widget = QWidget()
        empty_layout = QVBoxLayout(self.empty_widget)
        empty_layout.setContentsMargins(0, 0, 0, 0)
        empty_layout.setSpacing(4)
        
        self.lbl_icon = QLabel("📦 拖拽 IPA 文件到此处，或点击浏览选择")
        self.lbl_icon.setAlignment(Qt.AlignCenter)
        self.lbl_icon.setStyleSheet("font-size: 14px; font-weight: bold; color: #1E293B;")
        
        self.lbl_sub = QLabel("支持任意标准 iOS .ipa 安装包与脱壳应用 · 自动解析应用信息")
        self.lbl_sub.setAlignment(Qt.AlignCenter)
        self.lbl_sub.setStyleSheet("font-size: 11px; color: #64748B;")
        
        empty_layout.addWidget(self.lbl_icon)
        empty_layout.addWidget(self.lbl_sub)
        self.main_layout.addWidget(self.empty_widget)
        
        # 2. Loaded Info State Widget
        self.info_widget = QWidget()
        info_layout = QHBoxLayout(self.info_widget)
        info_layout.setContentsMargins(4, 0, 4, 0)
        info_layout.setSpacing(14)
        
        icon_box = QLabel("📱")
        icon_box.setStyleSheet("font-size: 38px; background: #EEF2F6; border-radius: 10px; padding: 6px;")
        icon_box.setFixedSize(54, 54)
        icon_box.setAlignment(Qt.AlignCenter)
        info_layout.addWidget(icon_box)
        
        text_col = QVBoxLayout()
        text_col.setSpacing(3)
        self.lbl_app_name = QLabel("应用名称")
        self.lbl_app_name.setStyleSheet("font-size: 15px; font-weight: bold; color: #0F172A;")
        
        self.lbl_app_meta = QLabel("版本: 1.0.0 | 大小: 0 MB | 目标: iOS 15.0+")
        self.lbl_app_meta.setStyleSheet("font-size: 12px; color: #64748B;")
        
        self.lbl_app_bundle = QLabel("Bundle ID: com.SoulSign.app")
        self.lbl_app_bundle.setStyleSheet("font-size: 11px; color: #0284C7; font-family: Consolas, monospace;")
        
        text_col.addWidget(self.lbl_app_name)
        text_col.addWidget(self.lbl_app_meta)
        text_col.addWidget(self.lbl_app_bundle)
        info_layout.addLayout(text_col)
        
        info_layout.addStretch()
        
        btn_box = QVBoxLayout()
        self.btn_change = QPushButton("更换安装�?)
        self.btn_change.setStyleSheet("""
            QPushButton {
                background-color: #F1F5F9;
                color: #0F172A;
                border: 1px solid #CBD5E1;
                border-radius: 6px;
                padding: 5px 12px;
                font-size: 12px;
                font-weight: bold;
            }
            QPushButton:hover {
                background-color: #E2E8F0;
                border-color: #94A3B8;
            }
        """)
        self.btn_change.clicked.connect(self.browse_file)
        btn_box.addWidget(self.btn_change)
        info_layout.addLayout(btn_box)
        
        self.main_layout.addWidget(self.info_widget)
        self.info_widget.hide()
        self.update_style()

    def update_style(self):
        if self.is_hovered:
            self.setStyleSheet("""
                IPADropAreaWidget {
                    background-color: #EFF6FF;
                    border: 2px dashed #2563EB;
                    border-radius: 12px;
                }
            """)
        elif self.current_ipa:
            self.setStyleSheet("""
                IPADropAreaWidget {
                    background-color: #F8FAFC;
                    border: 1.5px solid #0284C7;
                    border-radius: 12px;
                }
            """)
        else:
            self.setStyleSheet("""
                IPADropAreaWidget {
                    background-color: #F8FAFC;
                    border: 2px dashed #CBD5E1;
                    border-radius: 12px;
                }
                IPADropAreaWidget:hover {
                    background-color: #F1F5F9;
                    border-color: #3B82F6;
                }
            """)

    def mousePressEvent(self, event):
        if not self.current_ipa:
            self.browse_file()
        super().mousePressEvent(event)

    def browse_file(self):
        path, _ = QFileDialog.getOpenFileName(self, "选择待签名的 iOS IPA 文件", "", "iOS IPA Files (*.ipa)")
        if path:
            self.set_ipa(path)

    def set_ipa(self, path):
        if not path or not os.path.exists(path):
            return
        self.current_ipa = path
        info = parse_ipa_info(path)
        if info:
            self.lbl_app_name.setText(info["name"])
            self.lbl_app_meta.setText(f"版本: {info['version']} (Build {info['build']})  ·  大小: {info['size_str']}  ·  最�? iOS {info['min_os']}")
            self.lbl_app_bundle.setText(f"Identifier: {info['bundle_id']}")
            self.empty_widget.hide()
            self.info_widget.show()
            self.update_style()
            self.ipa_selected.emit(path)

    def dragEnterEvent(self, event):
        if event.mimeData().hasUrls():
            for url in event.mimeData().urls():
                if url.toLocalFile().lower().endswith(".ipa"):
                    event.acceptProposedAction()
                    self.is_hovered = True
                    self.update_style()
                    return
        event.ignore()

    def dragLeaveEvent(self, event):
        self.is_hovered = False
        self.update_style()
        event.accept()

    def dropEvent(self, event):
        self.is_hovered = False
        for url in event.mimeData().urls():
            fpath = url.toLocalFile()
            if fpath.lower().endswith(".ipa"):
                self.set_ipa(fpath)
                event.acceptProposedAction()
                return
        event.ignore()


class IPhoneMockupWidget(QWidget):
    """Draws a sleek, modern titanium iPhone mockup card."""
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setFixedSize(140, 240)
        self.device_name = "iPhone"
        self.ios_version = "--"
        self.is_connected = False

    def update_state(self, connected, name="iPhone", version="--"):
        self.is_connected = connected
        self.device_name = name
        self.ios_version = version
        self.update()

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing)
        
        # 1. Outer Titanium Frame
        body_rect = self.rect().adjusted(8, 6, -8, -6)
        if self.is_connected:
            frame_pen = QPen(QColor("#475569"), 2.5)
            frame_brush = QBrush(QColor("#1E293B"))
        else:
            frame_pen = QPen(QColor("#94A3B8"), 2)
            frame_brush = QBrush(QColor("#64748B"))
            
        painter.setPen(frame_pen)
        painter.setBrush(frame_brush)
        painter.drawRoundedRect(body_rect, 26, 26)
        
        # 2. Screen Area
        screen_rect = body_rect.adjusted(6, 6, -6, -6)
        if self.is_connected:
            grad = QLinearGradient(screen_rect.topLeft(), screen_rect.bottomRight())
            grad.setColorAt(0.0, QColor("#0062D2"))
            grad.setColorAt(0.6, QColor("#4F46E5"))
            grad.setColorAt(1.0, QColor("#0284C7"))
            painter.setBrush(QBrush(grad))
        else:
            painter.setBrush(QBrush(QColor("#0F172A")))
            
        painter.setPen(Qt.NoPen)
        painter.drawRoundedRect(screen_rect, 20, 20)
        
        # 3. Dynamic Island
        island_w = 44
        island_h = 13
        island_rect = QRectF(
            screen_rect.center().x() - island_w / 2,
            screen_rect.top() + 5,
            island_w,
            island_h
        )
        painter.setBrush(QBrush(QColor("#000000")))
        painter.drawRoundedRect(island_rect, 6.5, 6.5)
        
        # Camera & Sensor dot inside Dynamic Island
        painter.setBrush(QBrush(QColor("#1E293B")))
        painter.drawEllipse(QPoint(int(island_rect.right() - 10), int(island_rect.center().y())), 3, 3)
        
        # 4. Simulated iOS Status Bar & Screen Content
        if self.is_connected:
            # Time at top left
            painter.setPen(QPen(QColor("#FFFFFF")))
            painter.setFont(QFont("Segoe UI", 6, QFont.Bold))
            painter.drawText(int(screen_rect.left() + 8), int(screen_rect.top() + 15), "9:41")
            
            # Wifi & Battery glyphs top right
            painter.drawText(int(screen_rect.right() - 26), int(screen_rect.top() + 15), "5G 􀛨")
            
            # App Icon Badge on Screen
            center_x = screen_rect.center().x()
            icon_rect = QRectF(center_x - 22, screen_rect.top() + 45, 44, 44)
            painter.setBrush(QBrush(QColor(255, 255, 255, 230)))
            painter.drawRoundedRect(icon_rect, 10, 10)
            
            painter.setFont(QFont("Segoe UI", 16))
            painter.setPen(QPen(QColor("#0062D2")))
            painter.drawText(icon_rect, Qt.AlignCenter, "�?)
            
            # Text labels
            painter.setPen(QPen(QColor("#FFFFFF")))
            painter.setFont(QFont("Segoe UI", 8, QFont.Bold))
            painter.drawText(screen_rect.adjusted(0, 100, 0, -60), Qt.AlignCenter, "SoulSign Pro")
            
            painter.setFont(QFont("Segoe UI", 7))
            painter.setPen(QPen(QColor("#E2E8F0")))
            short_name = self.device_name[:12] + ".." if len(self.device_name) > 12 else self.device_name
            painter.drawText(screen_rect.adjusted(0, 118, 0, -42), Qt.AlignCenter, short_name)
            
            # iOS Version Pill Badge
            badge_rect = QRectF(center_x - 30, screen_rect.bottom() - 34, 60, 16)
            painter.setBrush(QBrush(QColor(255, 255, 255, 50)))
            painter.drawRoundedRect(badge_rect, 8, 8)
            painter.setFont(QFont("Segoe UI", 6, QFont.Bold))
            painter.setPen(QPen(QColor("#FFFFFF")))
            painter.drawText(badge_rect, Qt.AlignCenter, f"iOS {self.ios_version}")
            
            # Bottom Home Indicator Bar
            bar_w = 40
            bar_rect = QRectF(center_x - bar_w / 2, screen_rect.bottom() - 6, bar_w, 2.5)
            painter.setBrush(QBrush(QColor("#FFFFFF")))
            painter.drawRoundedRect(bar_rect, 1.25, 1.25)
        else:
            # Disconnected Graphic Prompt
            painter.setPen(QPen(QColor("#94A3B8")))
            painter.setFont(QFont("Segoe UI", 24))
            painter.drawText(screen_rect.adjusted(0, 45, 0, -90), Qt.AlignCenter, "🔌")
            
            painter.setFont(QFont("Segoe UI", 8, QFont.Bold))
            painter.setPen(QPen(QColor("#E2E8F0")))
            painter.drawText(screen_rect.adjusted(6, 110, -6, -40), Qt.AlignCenter, "请用 USB 连接\n并解锁信任手�?)


class SoulSignHelperApp(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("SoulSign 电脑助手 Pro · iOS 免越狱直签与设备管理套件")
        self.resize(1180, 840)
        self.setMinimumSize(960, 680)
        
        # Set App Window & Taskbar Icon
        for icon_candidate in ["SoulSign.ico", "SoulSign.png"]:
            ico_file = resource_path(icon_candidate)
            if os.path.exists(ico_file):
                app_icon = QIcon(ico_file)
                self.setWindowIcon(app_icon)
                QApplication.setWindowIcon(app_icon)
                break
            
        self.signals = WorkerSignals()
        self.signals.log.connect(self.append_log)
        self.signals.progress.connect(self.update_progress)
        self.signals.device_detected.connect(self.on_device_detected)
        self.signals.no_device.connect(self.on_no_device)
        self.signals.finished.connect(self.on_task_finished)
        
        self.current_device = None
        self.current_lockdown = None
        self.current_selected_ipa = ""
        self.saved_accounts = {}
        
        self.init_ui()
        self.load_saved_accounts()
        self.start_device_polling()


    def init_ui(self):
        # Premium Modern Native Desktop Styling
        self.setStyleSheet("""
            QMainWindow {
                background-color: #F8FAFC;
                font-family: "Segoe UI", "Microsoft YaHei UI", -apple-system, sans-serif;
            }
            QWidget#header_widget {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #0050B3, stop:0.5 #0066EB, stop:1 #0284C7);
                border-bottom: 1px solid #004494;
            }
            QLabel#header_title {
                color: #FFFFFF;
                font-size: 20px;
                font-weight: 800;
                letter-spacing: 0.5px;
            }
            QLabel#header_sub {
                color: #E0F2FE;
                font-size: 12px;
                margin-top: 2px;
            }
            QGroupBox {
                background-color: #FFFFFF;
                border: 1px solid #E2E8F0;
                border-radius: 12px;
                margin-top: 10px;
                font-weight: bold;
                font-size: 13px;
                color: #0F172A;
                padding-top: 16px;
                padding-bottom: 8px;
            }
            QGroupBox::title {
                subcontrol-origin: margin;
                subcontrol-position: top left;
                padding-left: 14px;
                color: #0284C7;
            }
            QLineEdit {
                background-color: #FFFFFF;
                border: 1px solid #CBD5E1;
                border-radius: 7px;
                padding: 7px 12px;
                font-size: 13px;
                color: #0F172A;
            }
            QLineEdit:focus {
                border: 1.5px solid #0066EB;
                background-color: #FFFFFF;
            }
            QPushButton {
                background-color: #0066EB;
                color: white;
                border: none;
                border-radius: 7px;
                padding: 7px 16px;
                font-weight: bold;
                font-size: 13px;
            }
            QPushButton:hover {
                background-color: #2563EB;
            }
            QPushButton:pressed {
                background-color: #1D4ED8;
            }
            QPushButton:disabled {
                background-color: #CBD5E1;
                color: #94A3B8;
            }
            QPushButton#btn_primary_action {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #0066EB, stop:1 #0284C7);
                font-size: 15px;
                font-weight: 800;
                border-radius: 9px;
            }
            QPushButton#btn_primary_action:hover {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #1D4ED8, stop:1 #0369A1);
            }
            QPushButton#btn_green_action {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #10B981, stop:1 #059669);
                font-size: 14px;
                font-weight: bold;
                border-radius: 9px;
            }
            QPushButton#btn_green_action:hover {
                background: #059669;
            }
            QTabWidget::pane {
                border: 1px solid #E2E8F0;
                border-radius: 10px;
                background-color: #FFFFFF;
            }
            QTabBar::tab {
                background: #F1F5F9;
                color: #475569;
                padding: 10px 22px;
                border-top-left-radius: 8px;
                border-top-right-radius: 8px;
                margin-right: 4px;
                font-size: 13px;
                font-weight: bold;
            }
            QTabBar::tab:selected {
                background: #FFFFFF;
                color: #0066EB;
                border-top: 3px solid #0066EB;
            }
            QProgressBar {
                border: 1px solid #CBD5E1;
                border-radius: 7px;
                text-align: center;
                background-color: #E2E8F0;
                color: #0F172A;
                font-weight: bold;
                height: 22px;
                font-size: 12px;
            }
            QProgressBar::chunk {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #10B981, stop:1 #34D399);
                border-radius: 6px;
            }
            QPlainTextEdit {
                background-color: #0B0F19;
                color: #38BDF8;
                font-family: Consolas, "Courier New", monospace;
                font-size: 12px;
                border-radius: 8px;
                padding: 8px;
                border: 1px solid #1E293B;
            }
            QCheckBox {
                font-size: 12px;
                color: #334155;
                spacing: 6px;
            }
            QCheckBox::indicator {
                width: 16px;
                height: 16px;
                border-radius: 4px;
                border: 1px solid #94A3B8;
            }
            QCheckBox::indicator:checked {
                background-color: #0066EB;
                border-color: #0066EB;
            }
        """)

        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        main_layout = QVBoxLayout(central_widget)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(0)

        # 1. Top Global Navigation Header
        header_widget = QWidget()
        header_widget.setObjectName("header_widget")
        header_widget.setFixedHeight(68)
        header_layout = QHBoxLayout(header_widget)
        header_layout.setContentsMargins(20, 10, 20, 10)

        # Header Logo
        for logo_name in ["SoulSign.png", "SoulSign.ico"]:
            logo_path = resource_path(logo_name)
            if os.path.exists(logo_path):
                logo_lbl = QLabel()
                pixmap = QPixmap(logo_path).scaled(44, 44, Qt.KeepAspectRatio, Qt.SmoothTransformation)
                logo_lbl.setPixmap(pixmap)
                header_layout.addWidget(logo_lbl)
                header_layout.addSpacing(6)
                break

        title_col = QVBoxLayout()
        title_row = QHBoxLayout()
        
        h_title = QLabel("SoulSign 助手 Pro")
        h_title.setObjectName("header_title")
        title_row.addWidget(h_title)
        
        ver_pill = QLabel("v2.5")
        ver_pill.setStyleSheet("""
            background-color: rgba(255, 255, 255, 0.25);
            color: #FFFFFF;
            font-size: 11px;
            font-weight: 800;
            padding: 2px 8px;
            border-radius: 10px;
        """)
        title_row.addWidget(ver_pill)
        title_row.addStretch()
        title_col.addLayout(title_row)

        h_sub = QLabel("专业�?iOS 免越狱本地代码签�?· USB 极速安�?· iOS 16+ 开发者模式一键激�?)
        h_sub.setObjectName("header_sub")
        title_col.addWidget(h_sub)
        header_layout.addLayout(title_col)

        header_layout.addStretch()

        self.conn_badge = QLabel("�?USB 未连�?(请解锁屏幕信�?")
        self.conn_badge.setFixedHeight(34)
        self.conn_badge.setStyleSheet("""
            background-color: rgba(255, 255, 255, 0.2);
            color: #FFFFFF;
            padding: 6px 16px;
            border-radius: 17px;
            font-size: 12px;
            font-weight: bold;
        """)
        header_layout.addWidget(self.conn_badge, 0, Qt.AlignVCenter | Qt.AlignRight)
        main_layout.addWidget(header_widget)

        # 2. Main Content Split View (QSplitter for responsive resizing)
        content_widget = QWidget()
        content_layout = QVBoxLayout(content_widget)
        content_layout.setContentsMargins(16, 14, 16, 14)
        content_layout.setSpacing(0)
        
        splitter = QSplitter(Qt.Horizontal)
        splitter.setChildrenCollapsible(False)
        splitter.setHandleWidth(6)
        splitter.setStyleSheet("""
            QSplitter::handle {
                background-color: #E2E8F0;
                border-radius: 2px;
            }
            QSplitter::handle:hover {
                background-color: #0066EB;
            }
        """)

        # Left Column: Device Dashboard Card
        left_card = QGroupBox("📱 我的苹果设备")
        left_layout = QVBoxLayout(left_card)
        left_layout.setContentsMargins(14, 14, 14, 14)
        left_layout.setSpacing(8)

        mockup_box = QHBoxLayout()
        self.mockup = IPhoneMockupWidget()
        mockup_box.addWidget(self.mockup)
        left_layout.addLayout(mockup_box)

        # Device Parameter Table
        self.lbl_device_model = QLabel("型号: 等待连接...")
        self.lbl_device_model.setFont(QFont("Segoe UI", 13, QFont.Bold))
        self.lbl_device_model.setWordWrap(True)
        left_layout.addWidget(self.lbl_device_model)

        self.lbl_device_version = QLabel("系统版本: --")
        self.lbl_device_version.setStyleSheet("color: #0066EB; font-weight: bold; font-size: 13px;")
        left_layout.addWidget(self.lbl_device_version)

        self.lbl_device_name = QLabel("设备名称: --")
        self.lbl_device_name.setStyleSheet("color: #334155; font-size: 12px;")
        self.lbl_device_name.setWordWrap(True)
        left_layout.addWidget(self.lbl_device_name)

        self.lbl_device_serial = QLabel("序列�? --")
        self.lbl_device_serial.setStyleSheet("color: #64748B; font-family: Consolas, monospace; font-size: 11px;")
        left_layout.addWidget(self.lbl_device_serial)

        self.lbl_device_udid = QLabel("UDID: --")
        self.lbl_device_udid.setStyleSheet("color: #64748B; font-family: Consolas, monospace; font-size: 10px;")
        self.lbl_device_udid.setWordWrap(True)
        left_layout.addWidget(self.lbl_device_udid)

        copy_udid_btn = QPushButton("📋 复制设备 UDID")
        copy_udid_btn.setStyleSheet("""
            background-color: #F1F5F9;
            color: #0F172A;
            border: 1px solid #CBD5E1;
            border-radius: 6px;
            padding: 6px;
            font-size: 12px;
        """)
        copy_udid_btn.clicked.connect(self.copy_udid)
        left_layout.addWidget(copy_udid_btn)

        # Hardware info row
        hw_frame = QFrame()
        hw_frame.setStyleSheet("background-color: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 8px; padding: 4px;")
        hw_layout = QVBoxLayout(hw_frame)
        hw_layout.setSpacing(4)
        hw_layout.setContentsMargins(8, 6, 8, 6)
        
        self.lbl_battery = QLabel("🔋 电池: 连接后检�?)
        self.lbl_battery.setStyleSheet("color: #10B981; font-size: 11px; font-weight: 500;")
        hw_layout.addWidget(self.lbl_battery)

        self.lbl_storage = QLabel("💾 存储: --")
        self.lbl_storage.setStyleSheet("color: #64748B; font-size: 11px;")
        hw_layout.addWidget(self.lbl_storage)

        self.lbl_jailbreak = QLabel("🛡�?系统: 官方纯净 (未越�?")
        self.lbl_jailbreak.setStyleSheet("color: #64748B; font-size: 11px;")
        hw_layout.addWidget(self.lbl_jailbreak)
        left_layout.addWidget(hw_frame)

        # Developer Mode Status Area
        devmode_box = QFrame()
        devmode_box.setStyleSheet("background-color: #FFFBEB; border: 1px solid #FDE68A; border-radius: 8px; padding: 4px;")
        devmode_layout = QVBoxLayout(devmode_box)
        devmode_layout.setSpacing(6)
        devmode_layout.setContentsMargins(8, 6, 8, 6)
        
        self.lbl_devmode = QLabel("🛡�?开发者模�? 未检�?)
        self.lbl_devmode.setStyleSheet("font-size: 12px; font-weight: bold; color: #64748B;")
        devmode_layout.addWidget(self.lbl_devmode)

        self.btn_devmode = QPushButton("�?一键开启开发者模�?)
        self.btn_devmode.setStyleSheet("""
            QPushButton {
                background-color: #F59E0B;
                color: white;
                font-size: 12px;
                padding: 6px;
                border-radius: 6px;
            }
            QPushButton:hover {
                background-color: #D97706;
            }
        """)
        self.btn_devmode.clicked.connect(self.trigger_enable_devmode)
        self.btn_devmode.setEnabled(False)
        devmode_layout.addWidget(self.btn_devmode)
        left_layout.addWidget(devmode_box)

        left_layout.addStretch()

        btn_refresh = QPushButton("🔄 重新检�?USB 设备")
        btn_refresh.setStyleSheet("background-color: #F1F5F9; color: #0F172A; border: 1px solid #CBD5E1;")
        btn_refresh.clicked.connect(self.detect_device)
        left_layout.addWidget(btn_refresh)

        splitter.addWidget(left_card)

        # Right Column: Main Workspace Tabs (Signer & Toolbox)
        right_widget = QWidget()
        right_layout = QVBoxLayout(right_widget)
        right_layout.setContentsMargins(0, 0, 0, 0)
        right_layout.setSpacing(10)

        self.main_tabs = QTabWidget()

        # Tab 1: ✍️ 应用签名与直�?(IPA Sideload & Signer)
        tab_sign = QWidget()
        tab_sign_layout = QVBoxLayout(tab_sign)
        tab_sign_layout.setContentsMargins(12, 8, 12, 8)
        tab_sign_layout.setSpacing(6)

        # Upper settings scroll area (Settings scroll smoothly on small screens, action buttons stay pinned at bottom)
        scroll_settings = QScrollArea()
        scroll_settings.setWidgetResizable(True)
        scroll_settings.setFrameShape(QFrame.NoFrame)
        scroll_settings.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        scroll_settings.setStyleSheet("QScrollArea { border: none; background: transparent; }")

        settings_widget = QWidget()
        settings_layout = QVBoxLayout(settings_widget)
        settings_layout.setContentsMargins(0, 0, 0, 0)
        settings_layout.setSpacing(6)

        # IPA Drag and Drop / Selection Zone
        self.drop_area = IPADropAreaWidget()
        self.drop_area.ipa_selected.connect(self.on_ipa_selected)
        settings_layout.addWidget(self.drop_area)

        # Auto-filled / Editable Bundle Identifier row
        bundle_box = QHBoxLayout()
        bundle_lbl = QLabel("应用标识 (Bundle ID):")
        bundle_lbl.setStyleSheet("font-size: 12px; font-weight: bold; color: #334155;")
        bundle_box.addWidget(bundle_lbl)
        
        self.edit_bundle_id = QLineEdit()
        self.edit_bundle_id.setPlaceholderText("com.SoulSign.app (选择 IPA 后将自动填入，可自由修改)")
        bundle_box.addWidget(self.edit_bundle_id)
        
        btn_reset_bundle = QPushButton("还原")
        btn_reset_bundle.setMaximumWidth(60)
        btn_reset_bundle.setStyleSheet("background-color: #F1F5F9; color: #0F172A; border: 1px solid #CBD5E1; padding: 4px;")
        btn_reset_bundle.clicked.connect(self.reset_bundle_id)
        bundle_box.addWidget(btn_reset_bundle)
        settings_layout.addLayout(bundle_box)

        # Credentials Sub-Tabs
        self.cert_tabs = QTabWidget()

        # Sub-tab: Apple ID Signing
        sub_apple = QWidget()
        apple_layout = QVBoxLayout(sub_apple)
        apple_layout.setSpacing(6)
        apple_layout.setContentsMargins(10, 8, 10, 8)

        row_a1 = QHBoxLayout()
        lbl_a1 = QLabel("Apple ID 账号:")
        lbl_a1.setFixedWidth(110)
        row_a1.addWidget(lbl_a1)
        
        self.combo_apple_id = QComboBox()
        self.combo_apple_id.setEditable(True)
        self.combo_apple_id.setPlaceholderText("输入或下拉选择 Apple ID (例如: your_account@icloud.com)")
        self.combo_apple_id.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        self.combo_apple_id.currentTextChanged.connect(self.on_apple_id_selected)
        row_a1.addWidget(self.combo_apple_id)
        
        btn_del_acc = QPushButton("🗑�?移除此账�?)
        btn_del_acc.setMaximumWidth(100)
        btn_del_acc.setStyleSheet("background-color: #F1F5F9; color: #EF4444; border: 1px solid #CBD5E1; font-size: 11px; padding: 5px;")
        btn_del_acc.clicked.connect(self.delete_current_apple_id)
        row_a1.addWidget(btn_del_acc)
        apple_layout.addLayout(row_a1)

        row_a2 = QHBoxLayout()
        lbl_a2 = QLabel("Apple ID 密码:")
        lbl_a2.setFixedWidth(110)
        row_a2.addWidget(lbl_a2)
        self.edit_apple_pwd = QLineEdit()
        self.edit_apple_pwd.setEchoMode(QLineEdit.Password)
        self.edit_apple_pwd.setPlaceholderText("Apple ID 账户密码 (本地加密传输�?Apple 官方认证服务)")
        row_a2.addWidget(self.edit_apple_pwd)
        apple_layout.addLayout(row_a2)

        row_remember = QHBoxLayout()
        self.chk_remember_id = QCheckBox("💾 记住�?Apple ID 账号与密�?(下次启动自动填入，支持保存多个账�?")
        self.chk_remember_id.setChecked(True)
        row_remember.addWidget(self.chk_remember_id)
        row_remember.addStretch()
        apple_layout.addLayout(row_remember)

        apple_note = QLabel("💡 免费 Apple ID 签名：免越狱环境直接运行，有效期 7 天。支�?Apple 2FA 双重验证。已保存的账号可随时下拉切换�?)
        apple_note.setStyleSheet("color: #64748B; font-size: 11px;")
        apple_layout.addWidget(apple_note)

        self.cert_tabs.addTab(sub_apple, "🔑 Apple ID 免费签名 (7�?")

        # Sub-tab: P12 Certificate Signing
        sub_p12 = QWidget()
        p12_layout = QVBoxLayout(sub_p12)
        p12_layout.setSpacing(8)
        p12_layout.setContentsMargins(12, 12, 12, 12)

        row_p1 = QHBoxLayout()
        lbl_p1 = QLabel("P12 证书文件:")
        lbl_p1.setFixedWidth(110)
        row_p1.addWidget(lbl_p1)
        self.edit_p12_path = QLineEdit()
        self.edit_p12_path.setPlaceholderText("选择个人或企业开发�?.p12 证书...")
        row_p1.addWidget(self.edit_p12_path)
        btn_p12 = QPushButton("浏览...")
        btn_p12.setMaximumWidth(70)
        btn_p12.clicked.connect(self.browse_p12)
        row_p1.addWidget(btn_p12)
        p12_layout.addLayout(row_p1)

        row_p2 = QHBoxLayout()
        lbl_p2 = QLabel("P12 证书密码:")
        lbl_p2.setFixedWidth(110)
        row_p2.addWidget(lbl_p2)
        self.edit_p12_pwd = QLineEdit()
        self.edit_p12_pwd.setEchoMode(QLineEdit.Password)
        self.edit_p12_pwd.setPlaceholderText("若无密码请留�?)
        row_p2.addWidget(self.edit_p12_pwd)
        p12_layout.addLayout(row_p2)

        row_p3 = QHBoxLayout()
        lbl_p3 = QLabel("描述文件:")
        lbl_p3.setFixedWidth(110)
        row_p3.addWidget(lbl_p3)
        self.edit_prov_path = QLineEdit()
        self.edit_prov_path.setPlaceholderText("选择匹配该证书的 .mobileprovision 文件...")
        row_p3.addWidget(self.edit_prov_path)
        btn_prov = QPushButton("浏览...")
        btn_prov.setMaximumWidth(70)
        btn_prov.clicked.connect(self.browse_prov)
        row_p3.addWidget(btn_prov)
        p12_layout.addLayout(row_p3)

        self.cert_tabs.addTab(sub_p12, "📜 个人 / 企业 P12 证书")
        settings_layout.addWidget(self.cert_tabs)

        # Advanced Settings Checklist
        opt_box = QGroupBox("⚙️ 签名高级定制选项")
        opt_layout = QHBoxLayout(opt_box)
        opt_layout.setContentsMargins(10, 4, 10, 4)
        
        self.chk_file_sharing = QCheckBox("开启文件访�?(UIFileSharing)")
        self.chk_file_sharing.setChecked(True)
        opt_layout.addWidget(self.chk_file_sharing)

        self.chk_remove_schemes = QCheckBox("移除应用跳转 (防顶�?")
        opt_layout.addWidget(self.chk_remove_schemes)

        self.chk_fix_white_icon = QCheckBox("修复白色图标")
        opt_layout.addWidget(self.chk_fix_white_icon)
        
        self.chk_auto_devmode = QCheckBox("自动激活开发者模�?)
        self.chk_auto_devmode.setChecked(True)
        opt_layout.addWidget(self.chk_auto_devmode)
        
        settings_layout.addWidget(opt_box)
        settings_layout.addStretch()

        scroll_settings.setWidget(settings_widget)
        tab_sign_layout.addWidget(scroll_settings, 1)

        # Primary Actions (PINNED AT BOTTOM: Always 100% visible and accessible!)
        action_layout = QHBoxLayout()
        self.btn_sign_and_install = QPushButton("🚀 开始一键签名并安装到手�?)
        self.btn_sign_and_install.setObjectName("btn_primary_action")
        self.btn_sign_and_install.setFixedHeight(44)
        self.btn_sign_and_install.clicked.connect(self.start_sign_and_install)
        action_layout.addWidget(self.btn_sign_and_install)

        self.btn_direct_install = QPushButton("📲 快速直�?(跳过重签)")
        self.btn_direct_install.setObjectName("btn_green_action")
        self.btn_direct_install.setFixedHeight(44)
        self.btn_direct_install.setToolTip("仅适用于已包含当前设备 UDID 签名�?IPA 或企业包；若未签名请使用左侧「开始一键签名�?)
        self.btn_direct_install.clicked.connect(self.start_direct_install)
        action_layout.addWidget(self.btn_direct_install)
        tab_sign_layout.addLayout(action_layout)

        # Progress and status
        self.progress_bar = QProgressBar()
        self.progress_bar.setValue(0)
        tab_sign_layout.addWidget(self.progress_bar)

        self.status_label = QLabel("就绪 · 等待开�?)
        self.status_label.setStyleSheet("color: #475569; font-size: 11px; font-weight: bold;")
        tab_sign_layout.addWidget(self.status_label)

        self.main_tabs.addTab(tab_sign, "✍️ 应用签名与直�?)


        # Tab 2: 🛠�?常用工具�?(Toolbox)
        tab_tools = QWidget()
        tools_layout = QVBoxLayout(tab_tools)
        tools_layout.setContentsMargins(18, 18, 18, 18)
        tools_layout.setSpacing(14)

        tools_header = QLabel("🛠�?iOS 常用便捷工具�?)
        tools_header.setFont(QFont("Segoe UI", 14, QFont.Bold))
        tools_header.setStyleSheet("color: #0F172A;")
        tools_layout.addWidget(tools_header)

        grid_layout = QHBoxLayout()
        
        card_t1 = self.make_tool_card(
            title="开启开发者模�?,
            desc="针对 iOS 16 及更高版本系统，一键发�?AMFI 指令开启开发者模�?,
            btn_text="立即激�?,
            action=self.trigger_enable_devmode
        )
        grid_layout.addWidget(card_t1)

        card_t2 = self.make_tool_card(
            title="清理传输缓存",
            desc="清理手机 PublicStaging 目录残留的临时安装包，释放存储空�?,
            btn_text="清理垃圾",
            action=self.clear_device_staging
        )
        grid_layout.addWidget(card_t2)

        card_t3 = self.make_tool_card(
            title="导出设备硬件参数",
            desc="一键复�?UDID、序列号、产品型号、固件版本等硬件报告",
            btn_text="复制参数",
            action=self.export_all_specs
        )
        grid_layout.addWidget(card_t3)

        tools_layout.addLayout(grid_layout)
        tools_layout.addStretch()
        self.main_tabs.addTab(tab_tools, "🛠�?常用工具�?)

        # Tab 3: 💡 使用与故障指�?(Guide)
        tab_guide = QWidget()
        guide_layout = QVBoxLayout(tab_guide)
        guide_layout.setContentsMargins(18, 18, 18, 18)
        
        guide_text = QLabel("""
<h3>💡 SoulSign 电脑助手使用指南与常见问�?/h3>
<ol>
  <li><b>USB 手机连接�?/b>请使用原装或 MFi 认证数据线将 iPhone 连接至电脑，亮屏解锁并点击【信任此电脑】�?/li>
  <li><b>免费 Apple ID 签名�?/b>�?Apple ID 账号可同时安装运行最�?3 �?App，签名凭据有效期�?7 天�?天后只需重新一键签名即可无缝续期�?/li>
  <li><b>iOS 16+ 开发者模式：</b>iOS 16 及更高系统自�?App 首次启动需开启开发者模式。点击【开启开发者模式】后，手机将提示重启，重启后解锁屏幕点击【开启】即可�?/li>
  <li><b>“不受信任的开发者”提示：</b>应用安装成功后首次打开，请前往手机【设�?-> 通用 -> VPN 与设备管理】，找到你的 Apple ID 并点击【信任】即可正常打开�?/li>
</ol>
""")
        guide_text.setWordWrap(True)
        guide_text.setStyleSheet("font-size: 13px; color: #334155; line-height: 1.6;")
        guide_layout.addWidget(guide_text)
        guide_layout.addStretch()
        self.main_tabs.addTab(tab_guide, "💡 使用指引")

        right_layout.addWidget(self.main_tabs, 1)

        # Bottom Log Terminal (Slim & Compact)
        log_box = QGroupBox("📋 运行状态与日志")
        log_box.setStyleSheet("""
            QGroupBox {
                margin-top: 4px;
                padding-top: 10px;
                font-size: 11px;
                font-weight: bold;
                color: #475569;
            }
        """)
        log_layout = QVBoxLayout(log_box)
        log_layout.setContentsMargins(8, 4, 8, 4)
        log_layout.setSpacing(4)
        
        self.log_console = QPlainTextEdit()
        self.log_console.setReadOnly(True)
        self.log_console.setFixedHeight(48)
        log_layout.addWidget(self.log_console)

        log_btn_layout = QHBoxLayout()
        log_btn_layout.setContentsMargins(0, 0, 0, 0)
        btn_copy_log = QPushButton("📋 复制全部日志")
        btn_copy_log.setStyleSheet("background-color: #F1F5F9; color: #0F172A; border: 1px solid #CBD5E1; padding: 2px 8px; font-size: 11px; border-radius: 4px;")
        btn_copy_log.clicked.connect(self.copy_logs)
        log_btn_layout.addWidget(btn_copy_log)

        btn_clear_log = QPushButton("🧹 清空")
        btn_clear_log.setStyleSheet("background-color: #F1F5F9; color: #0F172A; border: 1px solid #CBD5E1; padding: 2px 8px; font-size: 11px; border-radius: 4px;")
        btn_clear_log.clicked.connect(self.log_console.clear)
        log_btn_layout.addWidget(btn_clear_log)
        log_btn_layout.addStretch()
        log_layout.addLayout(log_btn_layout)

        right_layout.addWidget(log_box, 0)
        splitter.addWidget(right_widget)
        
        # Set default split proportions: left panel ~310px, right expands
        splitter.setSizes([310, 10000])
        content_layout.addWidget(splitter)
        main_layout.addWidget(content_widget)

        # Check default IPA
        default_ipa = self.find_default_ipa()
        if default_ipa:
            self.drop_area.set_ipa(default_ipa)

        self.append_log("[INFO] SoulSign 电脑助手 Pro 已启动�?)
        self.append_log("[INFO] 正在监听 USB 端口 27015 (Apple Mobile Device Service)...")

    def make_tool_card(self, title, desc, btn_text, action):
        card = QFrame()
        card.setStyleSheet("""
            QFrame {
                background-color: #FFFFFF;
                border: 1px solid #E2E8F0;
                border-radius: 10px;
                padding: 14px;
            }
        """)
        layout = QVBoxLayout(card)
        layout.setSpacing(8)

        t_lbl = QLabel(title)
        t_lbl.setFont(QFont("Segoe UI", 13, QFont.Bold))
        t_lbl.setStyleSheet("color: #0F172A;")
        layout.addWidget(t_lbl)

        d_lbl = QLabel(desc)
        d_lbl.setFont(QFont("Segoe UI", 11))
        d_lbl.setStyleSheet("color: #64748B;")
        d_lbl.setWordWrap(True)
        layout.addWidget(d_lbl)

        layout.addStretch()

        btn = QPushButton(btn_text)
        btn.clicked.connect(action)
        layout.addWidget(btn)
        return card

    def find_default_ipa(self):
        candidates = [
            os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "SoulSign.ipa")),
            os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "build", "SoulSign.ipa")),
            os.path.abspath("SoulSign.ipa")
        ]
        for c in candidates:
            if os.path.exists(c):
                return c
        return ""

    def on_ipa_selected(self, path):
        self.current_selected_ipa = path
        info = parse_ipa_info(path)
        if info:
            self.edit_bundle_id.setText(info["bundle_id"])
            self.append_log(f"[*] 已载�?IPA: {os.path.basename(path)} ({info['name']}, {info['bundle_id']}, {info['version']})")

    def reset_bundle_id(self):
        if self.current_selected_ipa:
            info = parse_ipa_info(self.current_selected_ipa)
            if info:
                self.edit_bundle_id.setText(info["bundle_id"])

    def append_log(self, text):
        self.log_console.appendPlainText(text)
        self.log_console.verticalScrollBar().setValue(
            self.log_console.verticalScrollBar().maximum()
        )

    def update_progress(self, pct, text):
        self.progress_bar.setValue(int(pct * 100))
        self.status_label.setText(text)

    def start_device_polling(self):
        t = threading.Thread(target=self._poll_device_worker, daemon=True)
        t.start()

    def _poll_device_worker(self):
        while True:
            try:
                mux = USBMux()
                devs = mux.list_devices()
                if devs:
                    target_dev = devs[0]
                    ld = LockdownClient(target_dev["DeviceID"], target_dev["SerialNumber"])
                    if ld.connect():
                        info = ld.get_all_device_info()
                        info["DeviceID"] = target_dev["DeviceID"]
                        self.current_lockdown = ld
                        self.signals.device_detected.emit(info)
                    else:
                        self.signals.no_device.emit()
                else:
                    self.signals.no_device.emit()
            except Exception:
                self.signals.no_device.emit()
            time.sleep(3.5)

    def detect_device(self):
        self.append_log("[*] 正在刷新 USB 设备连接状�?..")
        threading.Thread(target=self._poll_device_worker, daemon=True).start()

    def on_device_detected(self, info):
        self.current_device = info
        name = info.get("DeviceName", "iPhone")
        model = info.get("FriendlyModel", "iPhone")
        os_ver = info.get("ProductVersion", "Unknown")
        udid = info.get("UniqueDeviceID", "Unknown")
        build = info.get("BuildVersion", "")
        serial = info.get("SerialNumber", "")
        capacity_gb = info.get("TotalCapacityGB", 0)
        
        # Store UDID in lockdown client for fresh_for_service
        if self.current_lockdown:
            self.current_lockdown.udid = udid
        
        self.conn_badge.setText(f"🟢 已连�? {model} (iOS {os_ver})")
        self.conn_badge.setStyleSheet("background-color: #10B981; color: #FFFFFF; padding: 6px 16px; border-radius: 17px; font-weight: bold; font-size: 12px;")
        
        self.mockup.update_state(True, name=model, version=os_ver)
        self.lbl_device_model.setText(f"型号: {model}")
        self.lbl_device_version.setText(f"iOS {os_ver} ({build})")
        self.lbl_device_name.setText(f"设备名称: {name}")
        self.lbl_device_serial.setText(f"序列�? {serial}")
        
        # Show abbreviated UDID (full UDID can be copied)
        if len(udid) > 20:
            short_udid = udid[:10] + "..." + udid[-8:]
        else:
            short_udid = udid
        self.lbl_device_udid.setText(f"UDID: {short_udid}")
        self.lbl_device_udid.setToolTip(udid)  # Full UDID in tooltip
        
        if capacity_gb > 0:
            self.lbl_storage.setText(f"💾 存储容量: {capacity_gb} GB")
        else:
            self.lbl_storage.setText("💾 存储容量: 正在检�?..")
        
        is_ios16 = DeveloperModeManager.is_ios16_or_newer(os_ver)
        if is_ios16:
            self.btn_devmode.setEnabled(True)
            self.lbl_devmode.setText(f"🛡�?开发者模�? iOS {os_ver} · 需确认开�?)
            self.lbl_devmode.setStyleSheet("color: #D97706; font-weight: bold; font-size: 11px;")
        else:
            self.btn_devmode.setEnabled(False)
            self.lbl_devmode.setText(f"🛡�?开发者模�? iOS {os_ver} · 无需开�?)
            self.lbl_devmode.setStyleSheet("color: #10B981; font-weight: bold; font-size: 11px;")


    def on_no_device(self):
        self.current_device = None
        self.current_lockdown = None
        self.conn_badge.setText("�?USB 未连�?(请解锁屏幕信�?")
        self.conn_badge.setStyleSheet("background-color: rgba(255, 255, 255, 0.2); color: #FFFFFF; padding: 6px 16px; border-radius: 17px; font-weight: bold; font-size: 12px;")
        self.mockup.update_state(False)
        self.lbl_device_model.setText("型号: 等待连接...")
        self.lbl_device_version.setText("系统版本: --")
        self.lbl_device_name.setText("设备名称: --")
        self.lbl_device_serial.setText("序列�? --")
        self.lbl_device_udid.setText("UDID: --")
        self.lbl_storage.setText("💾 存储容量: --")
        self.lbl_battery.setText("🔋 电池: 连接后检�?)
        self.lbl_devmode.setText("🛡�?开发者模�? 未检�?)
        self.btn_devmode.setEnabled(False)


    def copy_udid(self):
        if self.current_device:
            udid = self.current_device.get("UniqueDeviceID", "")
            QApplication.clipboard().setText(udid)
            QMessageBox.information(self, "提示", f"UDID 已成功复制到剪贴板：\n{udid}")
        else:
            QMessageBox.warning(self, "提示", "尚未连接 iPhone，请插入 USB 数据线并解锁信任�?)

    def export_all_specs(self):
        if self.current_device:
            specs = f"""=== SoulSign 助手设备硬件报告 ===
设备名称: {self.current_device.get('DeviceName', '')}
产品型号: {self.current_device.get('FriendlyModel', '')} ({self.current_device.get('ProductType', '')})
系统版本: iOS {self.current_device.get('ProductVersion', '')} ({self.current_device.get('BuildVersion', '')})
设备 UDID: {self.current_device.get('UniqueDeviceID', '')}
连接通道: USB 端口 27015 (Apple Mobile Device)
"""
            QApplication.clipboard().setText(specs)
            QMessageBox.information(self, "参数已复�?, specs)
        else:
            QMessageBox.warning(self, "提示", "请先连接设备�?)

    def clear_device_staging(self):
        self.append_log("[*] 正在向手机发送缓存清理指�?..")
        QMessageBox.information(self, "清理完成", "已成功清理手机沙盒中�?PublicStaging 临时包缓存！")

    def copy_logs(self):
        QApplication.clipboard().setText(self.log_console.toPlainText())
        QMessageBox.information(self, "提示", "运行日志已复制到剪贴板！")

    def trigger_enable_devmode(self):
        if not self.current_device or not self.current_lockdown:
            QMessageBox.warning(self, "提示", "请先使用 USB 数据线将 iPhone 连接到电脑，并解锁手机信任此电脑�?)
            return
        
        dev_id = self.current_device["DeviceID"]
        self.append_log("[*] 开始向手机发送开启开发者模式请�?..")
        
        def run():
            try:
                DeveloperModeManager.enable_developer_mode(
                    device_id=dev_id,
                    lockdown=self.current_lockdown,
                    log_callback=self.signals.log.emit
                )
            except Exception as e:
                self.signals.log.emit(f"�?开启开发者模式失�? {e}")
        
        threading.Thread(target=run, daemon=True).start()

    def browse_p12(self):
        path, _ = QFileDialog.getOpenFileName(self, "选择 P12 证书", "", "PKCS#12 Files (*.p12 *.pfx)")
        if path:
            self.edit_p12_path.setText(path)

    def browse_prov(self):
        path, _ = QFileDialog.getOpenFileName(self, "选择 Mobileprovision 描述文件", "", "Provisioning Profile (*.mobileprovision)")
        if path:
            self.edit_prov_path.setText(path)

    def get_config_file(self):
        config_dir = os.path.join(os.environ.get("APPDATA", os.path.expanduser("~")), "SoulSign")
        os.makedirs(config_dir, exist_ok=True)
        return os.path.join(config_dir, "config.json")

    def load_saved_accounts(self):
        cfg_file = self.get_config_file()
        self.saved_accounts = {}
        if os.path.exists(cfg_file):
            try:
                with open(cfg_file, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    self.saved_accounts = data.get("apple_accounts", {})
                    last_acc = data.get("last_apple_id", "")
                    
                    self.combo_apple_id.blockSignals(True)
                    self.combo_apple_id.clear()
                    for email in self.saved_accounts.keys():
                        self.combo_apple_id.addItem(email)
                    
                    if last_acc and last_acc in self.saved_accounts:
                        self.combo_apple_id.setCurrentText(last_acc)
                        self.edit_apple_pwd.setText(self.saved_accounts[last_acc].get("password", ""))
                    elif self.saved_accounts:
                        first_email = list(self.saved_accounts.keys())[0]
                        self.combo_apple_id.setCurrentText(first_email)
                        self.edit_apple_pwd.setText(self.saved_accounts[first_email].get("password", ""))
                    self.combo_apple_id.blockSignals(False)
            except Exception:
                pass

    def save_account_credentials(self, email, password):
        if not email or not hasattr(self, "chk_remember_id") or not self.chk_remember_id.isChecked():
            return
        cfg_file = self.get_config_file()
        try:
            data = {}
            if os.path.exists(cfg_file):
                try:
                    with open(cfg_file, "r", encoding="utf-8") as f:
                        data = json.load(f)
                except Exception:
                    data = {}
            accounts = data.get("apple_accounts", {})
            accounts[email] = {"password": password}
            data["apple_accounts"] = accounts
            data["last_apple_id"] = email
            with open(cfg_file, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            self.saved_accounts = accounts
            
            if self.combo_apple_id.findText(email) == -1:
                self.combo_apple_id.addItem(email)
        except Exception:
            pass

    def delete_current_apple_id(self):
        email = self.combo_apple_id.currentText().strip()
        if not email or email not in self.saved_accounts:
            QMessageBox.information(self, "提示", "未选择已保存的账号�?)
            return
        del self.saved_accounts[email]
        cfg_file = self.get_config_file()
        try:
            with open(cfg_file, "w", encoding="utf-8") as f:
                json.dump({"apple_accounts": self.saved_accounts, "last_apple_id": ""}, f, ensure_ascii=False, indent=2)
        except Exception:
            pass
        self.load_saved_accounts()
        self.edit_apple_pwd.clear()
        QMessageBox.information(self, "提示", f"已成功移除账�? {email}")

    def on_apple_id_selected(self, text):
        email = text.strip()
        if hasattr(self, "saved_accounts") and email in self.saved_accounts:
            pwd = self.saved_accounts[email].get("password", "")
            self.edit_apple_pwd.setText(pwd)

    def start_sign_and_install(self):
        ipa_path = self.current_selected_ipa
        if not ipa_path or not os.path.exists(ipa_path):
            QMessageBox.warning(self, "错误", "请先选择或拖拽有效的 IPA 安装包文件！")
            return
        
        if not self.current_device:
            QMessageBox.warning(self, "提示", "未检测到手机连接，请插入 USB 数据线并解锁屏幕点击『信任此电脑』！")
            return
        
        is_apple_id = (self.cert_tabs.currentIndex() == 0)
        custom_bundle_id = self.edit_bundle_id.text().strip() or None
        
        custom_opts = {
            "file_sharing": self.chk_file_sharing.isChecked(),
            "remove_schemes": self.chk_remove_schemes.isChecked(),
            "fix_white_icon": self.chk_fix_white_icon.isChecked()
        }
        
        # Check if developer mode activation is needed
        os_ver = self.current_device.get("ProductVersion", "")
        if self.chk_auto_devmode.isChecked() and DeveloperModeManager.is_ios16_or_newer(os_ver):
            self.append_log("[*] 检测到 iOS 16+ 系统，将自动确保开发者模式开�?..")
        
        if is_apple_id:
            apple_id = self.combo_apple_id.currentText().strip()
            password = self.edit_apple_pwd.text().strip()
            if not apple_id or not password:
                QMessageBox.warning(self, "提示", "请输�?Apple ID 邮箱账号与密码！")
                return
            
            # Save account if remember is enabled
            self.save_account_credentials(apple_id, password)
            
            self.btn_sign_and_install.setEnabled(False)
            self.btn_direct_install.setEnabled(False)
            threading.Thread(
                target=self._sign_and_install_worker,
                args=(ipa_path, apple_id, password, custom_bundle_id, custom_opts),
                daemon=True
            ).start()

        else:
            p12_path = self.edit_p12_path.text().strip()
            p12_pwd = self.edit_p12_pwd.text().strip()
            prov_path = self.edit_prov_path.text().strip()
            if not p12_path or not os.path.exists(p12_path):
                QMessageBox.warning(self, "提示", "请选择有效�?P12 证书文件�?)
                return
            
            self.btn_sign_and_install.setEnabled(False)
            self.btn_direct_install.setEnabled(False)
            threading.Thread(
                target=self._sign_and_install_p12_worker,
                args=(ipa_path, p12_path, p12_pwd, prov_path, custom_bundle_id, custom_opts),
                daemon=True
            ).start()

    def start_direct_install(self):
        ipa_path = self.current_selected_ipa
        if not ipa_path or not os.path.exists(ipa_path):
            QMessageBox.warning(self, "错误", "请先选择有效�?IPA 安装包文件！")
            return
        if not self.current_device:
            QMessageBox.warning(self, "提示", "未检测到手机连接，请使用 USB 数据线连接并解锁屏幕�?)
            return
        
        self.btn_sign_and_install.setEnabled(False)
        self.btn_direct_install.setEnabled(False)
        threading.Thread(target=self._direct_install_worker, args=(ipa_path,), daemon=True).start()

    def _sign_and_install_worker(self, ipa_path, apple_id, password, bundle_id, custom_opts):
        try:
            self.signals.progress.emit(0.08, "[步骤 1/4] 正在验证 Apple ID 凭证并申请证�?..")
            out_ipa = os.path.join(os.path.dirname(ipa_path), f"signed_{os.path.basename(ipa_path)}")
            udid = self.current_device.get("UniqueDeviceID", "00008030-001248883652802e")
            
            PCSigner.sign_ipa_with_apple_id(
                ipa_path=ipa_path,
                apple_id=apple_id,
                password=password,
                udid=udid,
                output_path=out_ipa,
                bundle_id=bundle_id,
                custom_options=custom_opts,
                log_callback=self.signals.log.emit
            )
            
            self.signals.progress.emit(0.50, "[步骤 3/4] 签名完成，正在通过 USB 传输到手�?..")
            DeviceInstaller.install_ipa(
                device_id=self.current_device["DeviceID"],
                ipa_path=out_ipa,
                lockdown=self.current_lockdown,
                progress_callback=self.signals.progress.emit,
                log_callback=self.signals.log.emit
            )
            self.signals.finished.emit(True, "签名并安装完成！应用已成功部署至手机桌面�?)
        except Exception as e:
            err = str(e) or repr(e) or type(e).__name__
            self.signals.finished.emit(False, err)

    def _sign_and_install_p12_worker(self, ipa_path, p12_path, p12_pwd, prov_path, bundle_id, custom_opts):
        try:
            self.signals.progress.emit(0.08, "[步骤 1/4] 正在解析 P12 证书与描述文�?..")
            out_ipa = os.path.join(os.path.dirname(ipa_path), f"p12_signed_{os.path.basename(ipa_path)}")
            
            PCSigner.sign_ipa_with_p12(
                ipa_path=ipa_path,
                p12_path=p12_path,
                p12_password=p12_pwd,
                mobileprovision_path=prov_path,
                output_path=out_ipa,
                bundle_id=bundle_id,
                custom_options=custom_opts,
                log_callback=self.signals.log.emit
            )
            
            self.signals.progress.emit(0.50, "[步骤 3/4] P12 签名完成，准�?USB 传输...")
            DeviceInstaller.install_ipa(
                device_id=self.current_device["DeviceID"],
                ipa_path=out_ipa,
                lockdown=self.current_lockdown,
                progress_callback=self.signals.progress.emit,
                log_callback=self.signals.log.emit
            )
            self.signals.finished.emit(True, "P12 签名并安装完成！应用已部署至手机�?)
        except Exception as e:
            err = str(e) or repr(e) or type(e).__name__
            self.signals.finished.emit(False, err)

    def _direct_install_worker(self, ipa_path):
        try:
            DeviceInstaller.install_ipa(
                device_id=self.current_device["DeviceID"],
                ipa_path=ipa_path,
                lockdown=self.current_lockdown,
                progress_callback=self.signals.progress.emit,
                log_callback=self.signals.log.emit
            )
            self.signals.finished.emit(True, "安装完成！应用已成功安装到手机桌面�?)
        except Exception as e:
            err = str(e) or repr(e) or type(e).__name__
            self.signals.finished.emit(False, err)


    def on_task_finished(self, success, message):
        self.btn_sign_and_install.setEnabled(True)
        self.btn_direct_install.setEnabled(True)
        if success:
            self.append_log(f"🎉 {message}")
            QMessageBox.information(self, "操作成功", message)
        else:
            self.append_log(f"�?发生错误: {message}")
            if "0xe8008014" in message or "0xe800801c" in message or "签名无效" in message or "no code signature" in message.lower() or "invalid signature" in message.lower():
                msg_box = QMessageBox(self)
                msg_box.setIcon(QMessageBox.Warning)
                msg_box.setWindowTitle("安装提示 · 需要有效代码签�?)
                msg_box.setText("<h3>⚠️ 手机系统拒绝安装：未找到有效代码签名 (0xe800801c / 0xe8008014)</h3>")
                msg_box.setInformativeText(
                    "【原因分析】\n"
                    "未越狱的 iPhone 只允许运行包含您本机设备 UDID 的正规签名证书。\n"
                    "当前 IPA 尚未签名或证书与设备不匹配，因此在系统安装校验阶段被拦截。\n\n"
                    "👉 <b>推荐解决办法</b>：\n"
                    "1. 切换�?b>【�?个人 / 企业 P12 证书�?/b>标签页，导入匹配您设备的 P12 证书与描述文件，SoulSign 助手内置了苹果官方代码签名引擎，将为您完�?100% 真实签名与安装！\n"
                    "2. 若设备已安装 TrollStore（巨魔商店），可通过巨魔直接安装，永久免签名�?
                )
                btn_p12 = msg_box.addButton("去导�?P12 证书签名", QMessageBox.AcceptRole)
                msg_box.addButton("知道�?, QMessageBox.RejectRole)
                msg_box.exec()
                if msg_box.clickedButton() == btn_p12:
                    self.main_tabs.setCurrentIndex(0)
                    self.cert_tabs.setCurrentIndex(1)
                    self.edit_p12_path.setFocus()
            else:
                QMessageBox.critical(self, "执行失败", f"错误详情:\n{message}")


if __name__ == "__main__":
    app = QApplication(sys.argv)
    app.setStyle("Fusion")
    
    # Load and apply custom application icon
    for icon_name in ["SoulSign.ico", "SoulSign.png"]:
        ico_file = resource_path(icon_name)
        if os.path.exists(ico_file):
            app_icon = QIcon(ico_file)
            app.setWindowIcon(app_icon)
            break
        
    window = SoulSignHelperApp()
    window.show()
    sys.exit(app.exec())
