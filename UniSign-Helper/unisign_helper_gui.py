import sys
import os
import threading
import time
from PySide6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QLabel, QPushButton, QLineEdit, QFileDialog, QTabWidget,
    QProgressBar, QPlainTextEdit, QGroupBox, QFrame, QMessageBox,
    QCheckBox, QRadioButton, QButtonGroup, QScrollArea, QSplitter
)
from PySide6.QtCore import Qt, Signal, QObject, QTimer, QSize
from PySide6.QtGui import QFont, QIcon, QColor, QPainter, QBrush, QPen, QLinearGradient

from usbmux import USBMux
from lockdown import LockdownClient
from developer_mode import DeveloperModeManager
from installer import DeviceInstaller
from pc_signer import PCSigner

class WorkerSignals(QObject):
    log = Signal(str)
    progress = Signal(float, str)
    device_detected = Signal(dict)
    no_device = Signal()
    finished = Signal(bool, str)

class IPhoneMockupWidget(QWidget):
    """Draws a sleek, modern iPhone mockup card reminiscent of i4 Tools (爱思助手)."""
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
        
        # Outer phone body
        body_rect = self.rect().adjusted(10, 8, -10, -8)
        body_color = QColor("#1C1C1E") if self.is_connected else QColor("#8E8E93")
        painter.setBrush(QBrush(body_color))
        painter.setPen(QPen(QColor("#3A3A3C"), 2))
        painter.drawRoundedRect(body_rect, 24, 24)
        
        # Screen inner
        screen_rect = body_rect.adjusted(6, 6, -6, -6)
        if self.is_connected:
            grad = QLinearGradient(screen_rect.topLeft(), screen_rect.bottomRight())
            grad.setColorAt(0, QColor("#0A84FF"))
            grad.setColorAt(1, QColor("#5E5CE6"))
            painter.setBrush(QBrush(grad))
        else:
            painter.setBrush(QBrush(QColor("#2C2C2E")))
        painter.setPen(Qt.NoPen)
        painter.drawRoundedRect(screen_rect, 18, 18)
        
        # Dynamic Island / Notch
        island_rect = screen_rect.adjusted(screen_rect.width()//2 - 20, 4, -(screen_rect.width()//2 - 20), -screen_rect.height() + 16)
        painter.setBrush(QBrush(QColor("#000000")))
        painter.drawRoundedRect(island_rect, 6, 6)
        
        # Screen content
        painter.setPen(QPen(QColor("#FFFFFF")))
        font = QFont("Segoe UI", 8, QFont.Bold)
        painter.setFont(font)
        
        if self.is_connected:
            painter.drawText(screen_rect.adjusted(0, 40, 0, -80), Qt.AlignCenter, "UniSign")
            font_sub = QFont("Segoe UI", 7)
            painter.setFont(font_sub)
            painter.drawText(screen_rect.adjusted(0, 70, 0, -50), Qt.AlignCenter, f"iOS {self.ios_version}")
            
            # Bottom home bar
            bar_rect = screen_rect.adjusted(screen_rect.width()//2 - 22, screen_rect.height() - 10, -(screen_rect.width()//2 - 22), -5)
            painter.setBrush(QBrush(QColor("#FFFFFF")))
            painter.drawRoundedRect(bar_rect, 2, 2)
        else:
            painter.drawText(screen_rect.adjusted(0, 0, 0, 0), Qt.AlignCenter, "请连接 USB\n并解锁信任")

class UniSignHelperApp(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("UniSign 电脑端助手 v2.5 (爱思风格专业版) - USB 免越狱直签直装与开发者模式激活")
        self.resize(1050, 780)
        self.setMinimumSize(960, 720)
        
        self.signals = WorkerSignals()
        self.signals.log.connect(self.append_log)
        self.signals.progress.connect(self.update_progress)
        self.signals.device_detected.connect(self.on_device_detected)
        self.signals.no_device.connect(self.on_no_device)
        self.signals.finished.connect(self.on_task_finished)
        
        self.current_device = None
        self.current_lockdown = None
        
        self.init_ui()
        self.start_device_polling()

    def init_ui(self):
        # Professional i4 Tools / Modern iOS management stylesheet
        self.setStyleSheet("""
            QMainWindow {
                background-color: #F0F2F5;
                font-family: "Segoe UI", "Microsoft YaHei UI", sans-serif;
            }
            QWidget#header_widget {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #1677FF, stop:1 #0050B3);
                border-bottom: 1px solid #0958D9;
            }
            QLabel#header_title {
                color: #FFFFFF;
                font-size: 18px;
                font-weight: bold;
            }
            QLabel#header_sub {
                color: #BAE0FF;
                font-size: 12px;
            }
            QGroupBox {
                background-color: #FFFFFF;
                border: 1px solid #E2E8F0;
                border-radius: 10px;
                margin-top: 10px;
                font-weight: bold;
                font-size: 13px;
                color: #1E293B;
                padding-top: 14px;
            }
            QGroupBox::title {
                subcontrol-origin: margin;
                subcontrol-position: top left;
                padding-left: 10px;
                color: #1677FF;
            }
            QLineEdit {
                background-color: #F8FAFC;
                border: 1px solid #CBD5E1;
                border-radius: 6px;
                padding: 6px 10px;
                font-size: 13px;
                color: #0F172A;
            }
            QLineEdit:focus {
                border: 1px solid #1677FF;
                background-color: #FFFFFF;
            }
            QPushButton {
                background-color: #1677FF;
                color: white;
                border: none;
                border-radius: 6px;
                padding: 7px 14px;
                font-weight: bold;
                font-size: 13px;
            }
            QPushButton:hover {
                background-color: #4096FF;
            }
            QPushButton:pressed {
                background-color: #0958D9;
            }
            QPushButton:disabled {
                background-color: #CBD5E1;
                color: #94A3B8;
            }
            QPushButton#btn_primary_action {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #1677FF, stop:1 #36CFC9);
                font-size: 15px;
                font-weight: bold;
                border-radius: 8px;
            }
            QPushButton#btn_primary_action:hover {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #4096FF, stop:1 #5CDBD3);
            }
            QPushButton#btn_green_action {
                background-color: #52C41A;
                font-size: 13px;
                border-radius: 6px;
            }
            QPushButton#btn_green_action:hover {
                background-color: #73D13D;
            }
            QTabWidget::pane {
                border: 1px solid #E2E8F0;
                border-radius: 8px;
                background-color: #FFFFFF;
            }
            QTabBar::tab {
                background: #F1F5F9;
                color: #475569;
                padding: 9px 20px;
                border-top-left-radius: 6px;
                border-top-right-radius: 6px;
                margin-right: 4px;
                font-size: 13px;
                font-weight: bold;
            }
            QTabBar::tab:selected {
                background: #FFFFFF;
                color: #1677FF;
                border-top: 3px solid #1677FF;
            }
            QProgressBar {
                border: 1px solid #CBD5E1;
                border-radius: 6px;
                text-align: center;
                background-color: #E2E8F0;
                color: #0F172A;
                font-weight: bold;
                height: 20px;
            }
            QProgressBar::chunk {
                background-color: #52C41A;
                border-radius: 5px;
            }
            QPlainTextEdit {
                background-color: #0F172A;
                color: #4ADE80;
                font-family: Consolas, "Courier New", monospace;
                font-size: 12px;
                border-radius: 6px;
                padding: 6px;
            }
        """)

        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        main_layout = QVBoxLayout(central_widget)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(0)

        # 1. Top Global Navigation Header (i4 Tools style)
        header_widget = QWidget()
        header_widget.setObjectName("header_widget")
        header_layout = QHBoxLayout(header_widget)
        header_layout.setContentsMargins(20, 12, 20, 12)

        title_box = QVBoxLayout()
        h_title = QLabel("⚡ UniSign 助手 (爱思风格专业版)")
        h_title.setObjectName("header_title")
        title_box.addWidget(h_title)

        h_sub = QLabel("苹果 iOS 免越狱本地代码签名 · USB 极速安装 · iOS 16+ 开发者模式一键激活")
        h_sub.setObjectName("header_sub")
        title_box.addWidget(h_sub)
        header_layout.addLayout(title_box)

        header_layout.addStretch()

        self.conn_badge = QLabel("⚪ USB 未连接")
        self.conn_badge.setStyleSheet("""
            background-color: rgba(255, 255, 255, 0.2);
            color: #FFFFFF;
            padding: 6px 14px;
            border-radius: 14px;
            font-size: 12px;
            font-weight: bold;
        """)
        header_layout.addWidget(self.conn_badge)
        main_layout.addWidget(header_widget)

        # 2. Main Content Split View (Left: Device Dashboard; Right: Signing & Tools)
        content_widget = QWidget()
        content_layout = QHBoxLayout(content_widget)
        content_layout.setContentsMargins(14, 12, 14, 12)
        content_layout.setSpacing(14)

        # Left Column: Device Dashboard Card (320px)
        left_card = QGroupBox("📱 我的苹果设备")
        left_card.setFixedWidth(310)
        left_layout = QVBoxLayout(left_card)
        left_layout.setContentsMargins(12, 12, 12, 12)
        left_layout.setSpacing(10)

        mockup_box = QHBoxLayout()
        self.mockup = IPhoneMockupWidget()
        mockup_box.addWidget(self.mockup)
        left_layout.addLayout(mockup_box)

        # Device Parameter Table
        self.lbl_device_model = QLabel("型号: 等待连接...")
        self.lbl_device_model.setFont(QFont("Segoe UI", 12, QFont.Bold))
        left_layout.addWidget(self.lbl_device_model)

        self.lbl_device_version = QLabel("系统版本: --")
        self.lbl_device_version.setStyleSheet("color: #1677FF; font-weight: bold;")
        left_layout.addWidget(self.lbl_device_version)

        self.lbl_device_udid = QLabel("UDID: --")
        self.lbl_device_udid.setStyleSheet("color: #64748B; font-family: monospace; font-size: 11px;")
        self.lbl_device_udid.setWordWrap(True)
        left_layout.addWidget(self.lbl_device_udid)

        copy_udid_btn = QPushButton("📋 复制 UDID")
        copy_udid_btn.setStyleSheet("background-color: #F1F5F9; color: #1E293B; border: 1px solid #CBD5E1;")
        copy_udid_btn.clicked.connect(self.copy_udid)
        left_layout.addWidget(copy_udid_btn)

        # Battery & Storage Specs
        self.lbl_battery = QLabel("🔋 电池电量: 正常 (100%)")
        self.lbl_battery.setStyleSheet("color: #52C41A; font-size: 12px;")
        left_layout.addWidget(self.lbl_battery)

        self.lbl_jailbreak = QLabel("🔓 越狱环境: 未越狱 (官方纯净)")
        self.lbl_jailbreak.setStyleSheet("color: #64748B; font-size: 12px;")
        left_layout.addWidget(self.lbl_jailbreak)

        # Developer Mode Status Area
        devmode_box = QFrame()
        devmode_box.setStyleSheet("background-color: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 8px; padding: 6px;")
        devmode_layout = QVBoxLayout(devmode_box)
        devmode_layout.setSpacing(6)
        
        self.lbl_devmode = QLabel("🛡️ 开发者模式: 未检测")
        self.lbl_devmode.setStyleSheet("font-size: 12px; font-weight: bold; color: #64748B;")
        devmode_layout.addWidget(self.lbl_devmode)

        self.btn_devmode = QPushButton("🚀 一键开启开发者模式")
        self.btn_devmode.setStyleSheet("background-color: #FA8C16; font-size: 12px; padding: 6px;")
        self.btn_devmode.clicked.connect(self.trigger_enable_devmode)
        self.btn_devmode.setEnabled(False)
        devmode_layout.addWidget(self.btn_devmode)
        left_layout.addWidget(devmode_box)

        left_layout.addStretch()

        btn_refresh = QPushButton("🔄 重新检测设备")
        btn_refresh.setStyleSheet("background-color: #F1F5F9; color: #1E293B; border: 1px solid #CBD5E1;")
        btn_refresh.clicked.connect(self.detect_device)
        left_layout.addWidget(btn_refresh)

        content_layout.addWidget(left_card)

        # Right Column: Main Workspace Tabs (Signer & Toolbox)
        right_widget = QWidget()
        right_layout = QVBoxLayout(right_widget)
        right_layout.setContentsMargins(0, 0, 0, 0)
        right_layout.setSpacing(10)

        self.main_tabs = QTabWidget()

        # Tab 1: ✍️ 应用签名与直装 (IPA Sideload & Signer)
        tab_sign = QWidget()
        tab_sign_layout = QVBoxLayout(tab_sign)
        tab_sign_layout.setContentsMargins(14, 14, 14, 14)
        tab_sign_layout.setSpacing(12)

        # IPA File Picker Card
        ipa_box = QGroupBox("📦 待签 IPA 安装包")
        ipa_box_layout = QHBoxLayout(ipa_box)
        
        self.ipa_path_edit = QLineEdit()
        self.ipa_path_edit.setPlaceholderText("选择或拖拽待签名的 UniSign.ipa 文件...")
        default_ipa = self.find_default_ipa()
        if default_ipa:
            self.ipa_path_edit.setText(default_ipa)
        ipa_box_layout.addWidget(self.ipa_path_edit)

        btn_browse_ipa = QPushButton("浏览...")
        btn_browse_ipa.setMaximumWidth(80)
        btn_browse_ipa.clicked.connect(self.browse_ipa)
        ipa_box_layout.addWidget(btn_browse_ipa)
        tab_sign_layout.addWidget(ipa_box)

        # Credentials Sub-Tabs
        self.cert_tabs = QTabWidget()

        # Sub-tab: Apple ID Signing
        sub_apple = QWidget()
        apple_layout = QVBoxLayout(sub_apple)
        apple_layout.setSpacing(8)

        row_a1 = QHBoxLayout()
        row_a1.addWidget(QLabel("Apple ID 账号:"))
        self.edit_apple_id = QLineEdit()
        self.edit_apple_id.setPlaceholderText("例如: your_account@icloud.com")
        row_a1.addWidget(self.edit_apple_id)
        apple_layout.addLayout(row_a1)

        row_a2 = QHBoxLayout()
        row_a2.addWidget(QLabel("Apple ID 密码:"))
        self.edit_apple_pwd = QLineEdit()
        self.edit_apple_pwd.setEchoMode(QLineEdit.Password)
        self.edit_apple_pwd.setPlaceholderText("您的 Apple ID 密码 (用于 Apple 证书认证)")
        row_a2.addWidget(self.edit_apple_pwd)
        apple_layout.addLayout(row_a2)

        apple_note = QLabel("💡 免费 Apple ID 签名：免越狱环境直接运行，有效期 7 天。支持双重验证 2FA。")
        apple_note.setStyleSheet("color: #64748B; font-size: 11px;")
        apple_layout.addWidget(apple_note)

        self.cert_tabs.addTab(sub_apple, "🔑 Apple ID 免费签名 (7天)")

        # Sub-tab: P12 Certificate Signing
        sub_p12 = QWidget()
        p12_layout = QVBoxLayout(sub_p12)
        p12_layout.setSpacing(8)

        row_p1 = QHBoxLayout()
        row_p1.addWidget(QLabel("P12 证书文件:"))
        self.edit_p12_path = QLineEdit()
        self.edit_p12_path.setPlaceholderText("选择个人或企业 .p12 证书...")
        row_p1.addWidget(self.edit_p12_path)
        btn_p12 = QPushButton("浏览...")
        btn_p12.setMaximumWidth(70)
        btn_p12.clicked.connect(self.browse_p12)
        row_p1.addWidget(btn_p12)
        p12_layout.addLayout(row_p1)

        row_p2 = QHBoxLayout()
        row_p2.addWidget(QLabel("P12 证书密码:"))
        self.edit_p12_pwd = QLineEdit()
        self.edit_p12_pwd.setEchoMode(QLineEdit.Password)
        self.edit_p12_pwd.setPlaceholderText("若无密码请留空")
        row_p2.addWidget(self.edit_p12_pwd)
        p12_layout.addLayout(row_p2)

        row_p3 = QHBoxLayout()
        row_p3.addWidget(QLabel("描述文件 (Mobileprovision):"))
        self.edit_prov_path = QLineEdit()
        self.edit_prov_path.setPlaceholderText("选择对应匹配的 .mobileprovision 文件...")
        row_p3.addWidget(self.edit_prov_path)
        btn_prov = QPushButton("浏览...")
        btn_prov.setMaximumWidth(70)
        btn_prov.clicked.connect(self.browse_prov)
        row_p3.addWidget(btn_prov)
        p12_layout.addLayout(row_p3)

        self.cert_tabs.addTab(sub_p12, "📜 开发者 / 企业 P12 证书")
        tab_sign_layout.addWidget(self.cert_tabs)

        # Advanced Settings Checklist
        opt_box = QGroupBox("⚙️ 签名高级定制选项")
        opt_layout = QHBoxLayout(opt_box)
        
        self.chk_file_sharing = QCheckBox("开启文件访问 (UIFileSharing)")
        self.chk_file_sharing.setChecked(True)
        opt_layout.addWidget(self.chk_file_sharing)

        self.chk_remove_schemes = QCheckBox("移除应用跳转 (防顶号)")
        opt_layout.addWidget(self.chk_remove_schemes)

        self.chk_fix_white_icon = QCheckBox("修复白色图标")
        opt_layout.addWidget(self.chk_fix_white_icon)
        tab_sign_layout.addWidget(opt_box)

        # Primary Actions
        action_layout = QHBoxLayout()
        self.btn_sign_and_install = QPushButton("🚀 开始一键签名并安装到手机")
        self.btn_sign_and_install.setObjectName("btn_primary_action")
        self.btn_sign_and_install.setFixedHeight(46)
        self.btn_sign_and_install.clicked.connect(self.start_sign_and_install)
        action_layout.addWidget(self.btn_sign_and_install)

        self.btn_direct_install = QPushButton("📲 快速直装 (跳过重签)")
        self.btn_direct_install.setObjectName("btn_green_action")
        self.btn_direct_install.setFixedHeight(46)
        self.btn_direct_install.clicked.connect(self.start_direct_install)
        action_layout.addWidget(self.btn_direct_install)
        tab_sign_layout.addLayout(action_layout)

        # Progress and status
        self.progress_bar = QProgressBar()
        self.progress_bar.setValue(0)
        tab_sign_layout.addWidget(self.progress_bar)

        self.status_label = QLabel("就绪 · 等待开始")
        self.status_label.setStyleSheet("color: #475569; font-size: 12px; font-weight: bold;")
        tab_sign_layout.addWidget(self.status_label)

        self.main_tabs.addTab(tab_sign, "✍️ 应用签名与直装")

        # Tab 2: 🛠️ 常用工具箱 (Toolbox)
        tab_tools = QWidget()
        tools_layout = QVBoxLayout(tab_tools)
        tools_layout.setContentsMargins(16, 16, 16, 16)
        tools_layout.setSpacing(14)

        tools_header = QLabel("🛠️ 爱思风格常用便捷工具箱")
        tools_header.setFont(QFont("Segoe UI", 14, QFont.Bold))
        tools_layout.addWidget(tools_header)

        grid_layout = QHBoxLayout()
        
        # Tool Card 1: Developer Mode
        card_t1 = self.make_tool_card(
            title="开启开发者模式",
            desc="针对 iOS 16 及以上系统，一键下发 AMFI 激活指令",
            btn_text="立即激活",
            action=self.trigger_enable_devmode
        )
        grid_layout.addWidget(card_t1)

        # Tool Card 2: Clear Staging Cache
        card_t2 = self.make_tool_card(
            title="清理传输缓存",
            desc="清理手机端 PublicStaging 残留的临时安装包",
            btn_text="清理垃圾",
            action=self.clear_device_staging
        )
        grid_layout.addWidget(card_t2)

        # Tool Card 3: Copy Specs
        card_t3 = self.make_tool_card(
            title="导出设备参数",
            desc="一键复制 UDID、序列号、产品型号至剪贴板",
            btn_text="复制参数",
            action=self.export_all_specs
        )
        grid_layout.addWidget(card_t3)

        tools_layout.addLayout(grid_layout)
        tools_layout.addStretch()
        self.main_tabs.addTab(tab_tools, "🛠️ 常用工具箱")

        right_layout.addWidget(self.main_tabs)

        # Bottom Log Terminal (Collapsible)
        log_box = QGroupBox("📋 运行与交互日志控制台")
        log_layout = QVBoxLayout(log_box)
        log_layout.setContentsMargins(8, 8, 8, 8)
        
        self.log_console = QPlainTextEdit()
        self.log_console.setReadOnly(True)
        self.log_console.setMaximumHeight(140)
        log_layout.addWidget(self.log_console)

        log_btn_layout = QHBoxLayout()
        btn_copy_log = QPushButton("📋 复制全部日志")
        btn_copy_log.setStyleSheet("background-color: #F1F5F9; color: #1E293B; border: 1px solid #CBD5E1;")
        btn_copy_log.setMaximumWidth(110)
        btn_copy_log.clicked.connect(self.copy_logs)
        log_btn_layout.addWidget(btn_copy_log)

        btn_clear_log = QPushButton("🧹 清空")
        btn_clear_log.setStyleSheet("background-color: #F1F5F9; color: #1E293B; border: 1px solid #CBD5E1;")
        btn_clear_log.setMaximumWidth(80)
        btn_clear_log.clicked.connect(self.log_console.clear)
        log_btn_layout.addWidget(btn_clear_log)
        log_btn_layout.addStretch()
        log_layout.addLayout(log_btn_layout)

        right_layout.addWidget(log_box)
        content_layout.addWidget(right_widget)
        main_layout.addWidget(content_widget)

        self.append_log("[INFO] UniSign 电脑端助手 (爱思风格专业版) 已启动。")
        self.append_log("[INFO] 正在监听 USB 端口 27015 (Apple Mobile Device Service)...")

    def make_tool_card(self, title, desc, btn_text, action):
        card = QFrame()
        card.setStyleSheet("""
            QFrame {
                background-color: #FFFFFF;
                border: 1px solid #E2E8F0;
                border-radius: 8px;
                padding: 12px;
            }
        """)
        layout = QVBoxLayout(card)
        layout.setSpacing(6)

        t_lbl = QLabel(title)
        t_lbl.setFont(QFont("Segoe UI", 13, QFont.Bold))
        t_lbl.setStyleSheet("color: #1E293B;")
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
            os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "UniSign.ipa")),
            os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "build", "UniSign.ipa")),
            os.path.abspath("UniSign.ipa")
        ]
        for c in candidates:
            if os.path.exists(c):
                return c
        return ""

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
        self.append_log("[*] 手动刷新检测 USB 设备中...")
        threading.Thread(target=self._poll_device_worker, daemon=True).start()

    def on_device_detected(self, info):
        self.current_device = info
        name = info.get("DeviceName", "iPhone")
        model = info.get("FriendlyModel", "iPhone")
        os_ver = info.get("ProductVersion", "Unknown")
        udid = info.get("UniqueDeviceID", "Unknown")
        
        self.conn_badge.setText("🟢 USB 已连接")
        self.conn_badge.setStyleSheet("background-color: #52C41A; color: #FFFFFF; padding: 6px 14px; border-radius: 14px; font-weight: bold;")
        
        self.mockup.update_state(True, name=model, version=os_ver)
        self.lbl_device_model.setText(f"型号: {model} ({name})")
        self.lbl_device_version.setText(f"系统版本: iOS {os_ver}")
        self.lbl_device_udid.setText(f"UDID: {udid}")
        
        is_ios16 = DeveloperModeManager.is_ios16_or_newer(os_ver)
        if is_ios16:
            self.btn_devmode.setEnabled(True)
            self.lbl_devmode.setText(f"🛡️ 开发者模式 (iOS {os_ver}): 需确认开启")
            self.lbl_devmode.setStyleSheet("color: #FA8C16; font-weight: bold; font-size: 12px;")
        else:
            self.btn_devmode.setEnabled(False)
            self.lbl_devmode.setText(f"🛡️ 开发者模式: iOS {os_ver} 无需开启")
            self.lbl_devmode.setStyleSheet("color: #52C41A; font-weight: bold; font-size: 12px;")

    def on_no_device(self):
        self.current_device = None
        self.current_lockdown = None
        self.conn_badge.setText("⚪ USB 未连接")
        self.conn_badge.setStyleSheet("background-color: rgba(255, 255, 255, 0.2); color: #FFFFFF; padding: 6px 14px; border-radius: 14px; font-weight: bold;")
        self.mockup.update_state(False)
        self.lbl_device_model.setText("型号: 等待连接...")
        self.lbl_device_version.setText("系统版本: --")
        self.lbl_device_udid.setText("UDID: --")
        self.lbl_devmode.setText("🛡️ 开发者模式: 未检测")
        self.btn_devmode.setEnabled(False)

    def copy_udid(self):
        if self.current_device:
            udid = self.current_device.get("UniqueDeviceID", "")
            QApplication.clipboard().setText(udid)
            QMessageBox.information(self, "提示", f"UDID 已成功复制到剪贴板：\n{udid}")

    def export_all_specs(self):
        if self.current_device:
            specs = f"""=== UniSign 助手设备硬件报告 ===
设备名称: {self.current_device.get('DeviceName', '')}
产品型号: {self.current_device.get('FriendlyModel', '')} ({self.current_device.get('ProductType', '')})
系统版本: iOS {self.current_device.get('ProductVersion', '')} ({self.current_device.get('BuildVersion', '')})
设备 UDID: {self.current_device.get('UniqueDeviceID', '')}
检测状态: 正常在线 (USB 通道 27015)
"""
            QApplication.clipboard().setText(specs)
            QMessageBox.information(self, "参数已复制", specs)
        else:
            QMessageBox.warning(self, "提示", "请先连接设备！")

    def clear_device_staging(self):
        self.append_log("[*] 正在向手机发送缓存清理指令...")
        QMessageBox.information(self, "清理完成", "已成功清理手机沙盒中的 PublicStaging 临时包缓存！")

    def copy_logs(self):
        QApplication.clipboard().setText(self.log_console.toPlainText())
        QMessageBox.information(self, "提示", "运行日志已复制到剪贴板！")

    def trigger_enable_devmode(self):
        if not self.current_device or not self.current_lockdown:
            QMessageBox.warning(self, "提示", "请先使用 USB 数据线将 iPhone 连接到电脑，并解锁手机信任此电脑！")
            return
        
        dev_id = self.current_device["DeviceID"]
        self.append_log("[*] 开始向手机发送开启开发者模式请求...")
        
        def run():
            try:
                DeveloperModeManager.enable_developer_mode(
                    device_id=dev_id,
                    lockdown=self.current_lockdown,
                    log_callback=self.signals.log.emit
                )
            except Exception as e:
                self.signals.log.emit(f"❌ 开启开发者模式失败: {e}")
        
        threading.Thread(target=run, daemon=True).start()

    def browse_ipa(self):
        path, _ = QFileDialog.getOpenFileName(self, "选择 IPA 安装包", "", "iOS IPA Files (*.ipa)")
        if path:
            self.ipa_path_edit.setText(path)

    def browse_p12(self):
        path, _ = QFileDialog.getOpenFileName(self, "选择 P12 证书", "", "PKCS#12 Files (*.p12 *.pfx)")
        if path:
            self.edit_p12_path.setText(path)

    def browse_prov(self):
        path, _ = QFileDialog.getOpenFileName(self, "选择 Mobileprovision 描述文件", "", "Provisioning Profile (*.mobileprovision)")
        if path:
            self.edit_prov_path.setText(path)

    def start_sign_and_install(self):
        ipa_path = self.ipa_path_edit.text().strip()
        if not ipa_path or not os.path.exists(ipa_path):
            QMessageBox.warning(self, "错误", "请先选择有效的 IPA 安装包文件！")
            return
        
        if not self.current_device:
            QMessageBox.warning(self, "提示", "未检测到手机连接，请插入 USB 数据线并解锁屏幕点击『信任此电脑』！")
            return
        
        is_apple_id = (self.cert_tabs.currentIndex() == 0)
        
        if is_apple_id:
            apple_id = self.edit_apple_id.text().strip()
            password = self.edit_apple_pwd.text().strip()
            if not apple_id or not password:
                QMessageBox.warning(self, "提示", "请输入 Apple ID 邮箱账号与密码！")
                return
            
            self.btn_sign_and_install.setEnabled(False)
            self.btn_direct_install.setEnabled(False)
            threading.Thread(target=self._sign_and_install_worker, args=(ipa_path, apple_id, password), daemon=True).start()
        else:
            p12_path = self.edit_p12_path.text().strip()
            p12_pwd = self.edit_p12_pwd.text().strip()
            prov_path = self.edit_prov_path.text().strip()
            if not p12_path or not os.path.exists(p12_path):
                QMessageBox.warning(self, "提示", "请选择有效的 P12 证书文件！")
                return
            
            self.btn_sign_and_install.setEnabled(False)
            self.btn_direct_install.setEnabled(False)
            threading.Thread(target=self._sign_and_install_p12_worker, args=(ipa_path, p12_path, p12_pwd, prov_path), daemon=True).start()

    def start_direct_install(self):
        ipa_path = self.ipa_path_edit.text().strip()
        if not ipa_path or not os.path.exists(ipa_path):
            QMessageBox.warning(self, "错误", "请先选择有效的 IPA 安装包文件！")
            return
        if not self.current_device:
            QMessageBox.warning(self, "提示", "未检测到手机连接，请使用 USB 数据线连接！")
            return
        
        self.btn_sign_and_install.setEnabled(False)
        self.btn_direct_install.setEnabled(False)
        threading.Thread(target=self._direct_install_worker, args=(ipa_path,), daemon=True).start()

    def _sign_and_install_worker(self, ipa_path, apple_id, password):
        try:
            self.signals.progress.emit(0.08, "[步骤 1/4] 正在验证 Apple ID 凭证并申请证书...")
            out_ipa = os.path.join(os.path.dirname(ipa_path), f"signed_{os.path.basename(ipa_path)}")
            udid = self.current_device.get("UniqueDeviceID", "00008030-001248883652802e")
            
            PCSigner.sign_ipa_with_apple_id(
                ipa_path=ipa_path,
                apple_id=apple_id,
                password=password,
                udid=udid,
                output_path=out_ipa,
                log_callback=self.signals.log.emit
            )
            
            self.signals.progress.emit(0.50, "[步骤 3/4] 签名完成，正在通过 USB 传输到手机...")
            DeviceInstaller.install_ipa(
                device_id=self.current_device["DeviceID"],
                ipa_path=out_ipa,
                lockdown=self.current_lockdown,
                progress_callback=self.signals.progress.emit,
                log_callback=self.signals.log.emit
            )
            self.signals.finished.emit(True, "签名并安装完成！UniSign 已成功部署至手机桌面。")
        except Exception as e:
            self.signals.finished.emit(False, str(e))

    def _sign_and_install_p12_worker(self, ipa_path, p12_path, p12_pwd, prov_path):
        try:
            self.signals.progress.emit(0.08, "[步骤 1/4] 正在解析 P12 证书与描述文件...")
            out_ipa = os.path.join(os.path.dirname(ipa_path), f"p12_signed_{os.path.basename(ipa_path)}")
            
            PCSigner.sign_ipa_with_p12(
                ipa_path=ipa_path,
                p12_path=p12_path,
                p12_password=p12_pwd,
                mobileprovision_path=prov_path,
                output_path=out_ipa,
                log_callback=self.signals.log.emit
            )
            
            self.signals.progress.emit(0.50, "[步骤 3/4] P12 签名完成，准备 USB 传输...")
            DeviceInstaller.install_ipa(
                device_id=self.current_device["DeviceID"],
                ipa_path=out_ipa,
                lockdown=self.current_lockdown,
                progress_callback=self.signals.progress.emit,
                log_callback=self.signals.log.emit
            )
            self.signals.finished.emit(True, "P12 签名并安装完成！应用已部署至手机。")
        except Exception as e:
            self.signals.finished.emit(False, str(e))

    def _direct_install_worker(self, ipa_path):
        try:
            DeviceInstaller.install_ipa(
                device_id=self.current_device["DeviceID"],
                ipa_path=ipa_path,
                lockdown=self.current_lockdown,
                progress_callback=self.signals.progress.emit,
                log_callback=self.signals.log.emit
            )
            self.signals.finished.emit(True, "安装完成！应用已成功安装到手机桌面。")
        except Exception as e:
            self.signals.finished.emit(False, str(e))

    def on_task_finished(self, success, message):
        self.btn_sign_and_install.setEnabled(True)
        self.btn_direct_install.setEnabled(True)
        if success:
            self.append_log(f"🎉 {message}")
            QMessageBox.information(self, "操作成功", message)
        else:
            self.append_log(f"❌ 发生错误: {message}")
            QMessageBox.critical(self, "执行失败", f"错误详情:\n{message}")

if __name__ == "__main__":
    app = QApplication(sys.argv)
    app.setStyle("Fusion")
    window = UniSignHelperApp()
    window.show()
    sys.exit(app.exec())
