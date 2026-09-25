import sys
import os
import threading
import time
from PySide6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QLabel, QPushButton, QLineEdit, QFileDialog, QTabWidget,
    QProgressBar, QPlainTextEdit, QGroupBox, QFrame, QMessageBox,
    QInputDialog
)
from PySide6.QtCore import Qt, Signal, QObject
from PySide6.QtGui import QFont, QIcon, QColor

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

class UniSignHelperApp(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("UniSign 电脑端助手 v2.0 - USB 一键签名安装与开发者模式激活")
        self.resize(800, 750)
        self.setMinimumSize(750, 680)
        
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
        # Global stylesheet
        self.setStyleSheet("""
            QMainWindow {
                background-color: #F5F5F7;
            }
            QGroupBox {
                background-color: #FFFFFF;
                border: 1px solid #E5E5EA;
                border-radius: 12px;
                margin-top: 14px;
                font-weight: bold;
                font-size: 13px;
                color: #1C1C1E;
                padding-top: 16px;
            }
            QGroupBox::title {
                subcontrol-origin: margin;
                subcontrol-position: top left;
                padding-left: 12px;
                padding-top: 2px;
                color: #007AFF;
            }
            QLineEdit {
                background-color: #F2F2F7;
                border: 1px solid #D1D1D6;
                border-radius: 8px;
                padding: 7px 10px;
                font-size: 13px;
                color: #1C1C1E;
            }
            QLineEdit:focus {
                border: 1px solid #007AFF;
                background-color: #FFFFFF;
            }
            QPushButton {
                background-color: #007AFF;
                color: white;
                border: none;
                border-radius: 8px;
                padding: 8px 16px;
                font-weight: bold;
                font-size: 13px;
            }
            QPushButton:hover {
                background-color: #0062CC;
            }
            QPushButton:pressed {
                background-color: #004FA3;
            }
            QPushButton:disabled {
                background-color: #C7C7CC;
                color: #8E8E93;
            }
            QTabWidget::pane {
                border: 1px solid #E5E5EA;
                border-radius: 8px;
                background-color: #FFFFFF;
            }
            QTabBar::tab {
                background: #E5E5EA;
                color: #3A3A3C;
                padding: 8px 18px;
                border-top-left-radius: 6px;
                border-top-right-radius: 6px;
                margin-right: 2px;
                font-size: 12px;
                font-weight: bold;
            }
            QTabBar::tab:selected {
                background: #007AFF;
                color: white;
            }
            QProgressBar {
                border: 1px solid #D1D1D6;
                border-radius: 8px;
                text-align: center;
                background-color: #E5E5EA;
                color: #1C1C1E;
                font-weight: bold;
                height: 22px;
            }
            QProgressBar::chunk {
                background-color: #34C759;
                border-radius: 7px;
            }
            QPlainTextEdit {
                background-color: #1C1C1E;
                color: #30D158;
                font-family: Consolas, "Courier New", monospace;
                font-size: 12px;
                border-radius: 8px;
                padding: 8px;
            }
        """)

        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        main_layout = QVBoxLayout(central_widget)
        main_layout.setContentsMargins(16, 12, 16, 16)
        main_layout.setSpacing(12)

        # 1. Header
        header_layout = QHBoxLayout()
        title_label = QLabel("⚡ UniSign 电脑端助手")
        title_label.setFont(QFont("Segoe UI", 16, QFont.Bold))
        title_label.setStyleSheet("color: #007AFF;")
        header_layout.addWidget(title_label)

        sub_label = QLabel("纯手机端免越狱应用桌面配套工具 · USB 一键直签直装")
        sub_label.setStyleSheet("color: #8E8E93; font-size: 12px;")
        sub_label.setAlignment(Qt.AlignRight | Qt.AlignVCenter)
        header_layout.addWidget(sub_label)
        main_layout.addLayout(header_layout)

        # 2. Device Status Group
        self.device_group = QGroupBox("📱 已连接 iOS 设备状态")
        dev_layout = QVBoxLayout(self.device_group)
        dev_layout.setSpacing(8)

        dev_info_layout = QHBoxLayout()
        self.dev_name_label = QLabel("设备: 检测中...")
        self.dev_name_label.setFont(QFont("Segoe UI", 13, QFont.Bold))
        dev_info_layout.addWidget(self.dev_name_label)

        self.dev_os_label = QLabel("iOS: --")
        self.dev_os_label.setStyleSheet("color: #007AFF; font-weight: bold;")
        dev_info_layout.addWidget(self.dev_os_label)

        self.dev_udid_label = QLabel("UDID: --")
        self.dev_udid_label.setStyleSheet("color: #8E8E93; font-family: monospace;")
        dev_info_layout.addWidget(self.dev_udid_label)

        self.btn_refresh_dev = QPushButton("🔄 刷新")
        self.btn_refresh_dev.setMaximumWidth(80)
        self.btn_refresh_dev.clicked.connect(self.detect_device)
        dev_info_layout.addWidget(self.btn_refresh_dev)

        dev_layout.addLayout(dev_info_layout)

        # Developer Mode Sub-bar
        devmode_bar = QHBoxLayout()
        self.devmode_status_label = QLabel("🛡️ 开发者模式 (iOS 16+): 检查中...")
        self.devmode_status_label.setStyleSheet("font-size: 12px; color: #3A3A3C;")
        devmode_bar.addWidget(self.devmode_status_label)

        self.btn_enable_devmode = QPushButton("🚀 一键开启开发者模式")
        self.btn_enable_devmode.setStyleSheet("background-color: #FF9500; font-size: 12px; padding: 5px 12px;")
        self.btn_enable_devmode.clicked.connect(self.trigger_enable_devmode)
        self.btn_enable_devmode.setEnabled(False)
        devmode_bar.addWidget(self.btn_enable_devmode)

        dev_layout.addLayout(devmode_bar)
        main_layout.addWidget(self.device_group)

        # 3. IPA Selection Group
        ipa_group = QGroupBox("📦 待签 IPA 安装包选择")
        ipa_layout = QHBoxLayout(ipa_group)
        
        self.ipa_path_edit = QLineEdit()
        self.ipa_path_edit.setPlaceholderText("请选择要签名并安装的 UniSign.ipa 文件...")
        default_ipa = self.find_default_ipa()
        if default_ipa:
            self.ipa_path_edit.setText(default_ipa)
        ipa_layout.addWidget(self.ipa_path_edit)

        self.btn_browse_ipa = QPushButton("浏览...")
        self.btn_browse_ipa.setMaximumWidth(80)
        self.btn_browse_ipa.clicked.connect(self.browse_ipa)
        ipa_layout.addWidget(self.btn_browse_ipa)

        main_layout.addWidget(ipa_group)

        # 4. Signing Mode Tabs
        self.tabs = QTabWidget()

        # Tab 1: Apple ID Signing
        tab_apple_id = QWidget()
        tab_apple_layout = QVBoxLayout(tab_apple_id)
        tab_apple_layout.setSpacing(10)

        row_email = QHBoxLayout()
        row_email.addWidget(QLabel("Apple ID 账号:"))
        self.apple_id_edit = QLineEdit()
        self.apple_id_edit.setPlaceholderText("例如: your_apple_id@icloud.com")
        row_email.addWidget(self.apple_id_edit)
        tab_apple_layout.addLayout(row_email)

        row_pwd = QHBoxLayout()
        row_pwd.addWidget(QLabel("Apple ID 密码:"))
        self.apple_pwd_edit = QLineEdit()
        self.apple_pwd_edit.setEchoMode(QLineEdit.Password)
        self.apple_pwd_edit.setPlaceholderText("您的 Apple ID 密码 (仅本地与 Apple 认证)")
        row_pwd.addWidget(self.apple_pwd_edit)
        tab_apple_layout.addLayout(row_pwd)

        tab_apple_desc = QLabel("💡 使用免费 Apple ID 进行签名，无需越狱，签名有效期 7 天。支持双重验证 (2FA)。")
        tab_apple_desc.setStyleSheet("color: #8E8E93; font-size: 11px;")
        tab_apple_layout.addWidget(tab_apple_desc)

        self.tabs.addTab(tab_apple_id, "🔑 Apple ID 免费签名 (7天)")

        # Tab 2: P12 Certificate Signing
        tab_p12 = QWidget()
        tab_p12_layout = QVBoxLayout(tab_p12)
        tab_p12_layout.setSpacing(10)

        row_p12 = QHBoxLayout()
        row_p12.addWidget(QLabel("P12 证书文件:"))
        self.p12_path_edit = QLineEdit()
        self.p12_path_edit.setPlaceholderText("选择 .p12 证书文件...")
        row_p12.addWidget(self.p12_path_edit)
        btn_browse_p12 = QPushButton("浏览...")
        btn_browse_p12.setMaximumWidth(70)
        btn_browse_p12.clicked.connect(self.browse_p12)
        row_p12.addWidget(btn_browse_p12)
        tab_p12_layout.addLayout(row_p12)

        row_p12_pwd = QHBoxLayout()
        row_p12_pwd.addWidget(QLabel("P12 证书密码:"))
        self.p12_pwd_edit = QLineEdit()
        self.p12_pwd_edit.setEchoMode(QLineEdit.Password)
        self.p12_pwd_edit.setPlaceholderText("若无密码可留空")
        row_p12_pwd.addWidget(self.p12_pwd_edit)
        tab_p12_layout.addLayout(row_p12_pwd)

        row_prov = QHBoxLayout()
        row_prov.addWidget(QLabel("Mobileprovision 描述文件:"))
        self.prov_path_edit = QLineEdit()
        self.prov_path_edit.setPlaceholderText("选择对应匹配的 .mobileprovision 文件...")
        row_prov.addWidget(self.prov_path_edit)
        btn_browse_prov = QPushButton("浏览...")
        btn_browse_prov.setMaximumWidth(70)
        btn_browse_prov.clicked.connect(self.browse_prov)
        row_prov.addWidget(btn_browse_prov)
        tab_p12_layout.addLayout(row_prov)

        self.tabs.addTab(tab_p12, "📜 P12 开发者/企业证书签名")
        main_layout.addWidget(self.tabs)

        # 5. Actions & Progress Bar
        action_layout = QHBoxLayout()
        self.btn_sign_and_install = QPushButton("🚀 一键签名并安装到手机")
        self.btn_sign_and_install.setFixedHeight(44)
        self.btn_sign_and_install.setStyleSheet("""
            QPushButton {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #007AFF, stop:1 #00C2FF);
                font-size: 15px;
                font-weight: bold;
            }
            QPushButton:hover {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #0062CC, stop:1 #00A3D9);
            }
        """)
        self.btn_sign_and_install.clicked.connect(self.start_sign_and_install)
        action_layout.addWidget(self.btn_sign_and_install)

        self.btn_direct_install = QPushButton("📲 仅安装 (不重签)")
        self.btn_direct_install.setFixedHeight(44)
        self.btn_direct_install.setStyleSheet("background-color: #34C759; font-size: 14px;")
        self.btn_direct_install.clicked.connect(self.start_direct_install)
        action_layout.addWidget(self.btn_direct_install)

        main_layout.addLayout(action_layout)

        self.progress_bar = QProgressBar()
        self.progress_bar.setValue(0)
        main_layout.addWidget(self.progress_bar)

        self.status_label = QLabel("就绪")
        self.status_label.setStyleSheet("color: #3A3A3C; font-size: 12px;")
        main_layout.addWidget(self.status_label)

        # 6. Real-time Log Console
        log_group = QGroupBox("📋 运行与交互日志")
        log_layout = QVBoxLayout(log_group)
        self.log_console = QPlainTextEdit()
        self.log_console.setReadOnly(True)
        log_layout.addWidget(self.log_console)
        main_layout.addWidget(log_group)

        self.append_log("[INFO] UniSign 电脑端助手已启动。")
        self.append_log("[INFO] 正在监听 USB 端口 27015 (Apple Mobile Device Service)...")

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
                    # Query lockdown
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
        self.dev_name_label.setText(f"设备: {info.get('FriendlyModel', 'iPhone')} ({info.get('DeviceName', 'iPhone')})")
        self.dev_os_label.setText(f"iOS: {info.get('ProductVersion', 'Unknown')}")
        udid = info.get("UniqueDeviceID", "Unknown")
        self.dev_udid_label.setText(f"UDID: {udid[:8]}...{udid[-6:]}" if len(udid) > 16 else f"UDID: {udid}")
        
        os_ver = info.get("ProductVersion", "0")
        is_ios16 = DeveloperModeManager.is_ios16_or_newer(os_ver)
        if is_ios16:
            self.btn_enable_devmode.setEnabled(True)
            self.devmode_status_label.setText(f"🛡️ 开发者模式 (iOS {os_ver}): 需确认开启")
            self.devmode_status_label.setStyleSheet("color: #FF9500; font-weight: bold;")
        else:
            self.btn_enable_devmode.setEnabled(False)
            self.devmode_status_label.setText(f"🛡️ 开发者模式: iOS {os_ver} 无需开启")
            self.devmode_status_label.setStyleSheet("color: #34C759; font-weight: bold;")

    def on_no_device(self):
        self.current_device = None
        self.current_lockdown = None
        self.dev_name_label.setText("设备: 未检测到连接的 iPhone")
        self.dev_os_label.setText("iOS: --")
        self.dev_udid_label.setText("UDID: --")
        self.devmode_status_label.setText("🛡️ 开发者模式: --")
        self.btn_enable_devmode.setEnabled(False)

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
            self.p12_path_edit.setText(path)

    def browse_prov(self):
        path, _ = QFileDialog.getOpenFileName(self, "选择 Mobileprovision 描述文件", "", "Provisioning Profile (*.mobileprovision)")
        if path:
            self.prov_path_edit.setText(path)

    def start_sign_and_install(self):
        ipa_path = self.ipa_path_edit.text().strip()
        if not ipa_path or not os.path.exists(ipa_path):
            QMessageBox.warning(self, "错误", "请先选择有效的 IPA 安装包文件！")
            return
        
        if not self.current_device:
            QMessageBox.warning(self, "提示", "未检测到手机连接，请插入 USB 数据线并解锁屏幕点击『信任此电脑』！")
            return
        
        is_apple_id = (self.tabs.currentIndex() == 0)
        
        if is_apple_id:
            apple_id = self.apple_id_edit.text().strip()
            password = self.apple_pwd_edit.text().strip()
            if not apple_id or not password:
                QMessageBox.warning(self, "提示", "请输入 Apple ID 邮箱账号与密码！")
                return
            
            self.btn_sign_and_install.setEnabled(False)
            self.btn_direct_install.setEnabled(False)
            threading.Thread(target=self._sign_and_install_worker, args=(ipa_path, True, apple_id, password), daemon=True).start()
        else:
            p12_path = self.p12_path_edit.text().strip()
            p12_pwd = self.p12_pwd_edit.text().strip()
            prov_path = self.prov_path_edit.text().strip()
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

    def _sign_and_install_worker(self, ipa_path, is_apple_id, apple_id, password):
        try:
            self.signals.progress.emit(0.05, "正在进行 Apple ID 签名准备...")
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
            
            self.signals.progress.emit(0.50, "签名完成，准备通过 USB 安装到手机...")
            DeviceInstaller.install_ipa(
                device_id=self.current_device["DeviceID"],
                ipa_path=out_ipa,
                lockdown=self.current_lockdown,
                progress_callback=self.signals.progress.emit,
                log_callback=self.signals.log.emit
            )
            self.signals.finished.emit(True, "签名并安装完成！应用已部署至手机桌面。")
        except Exception as e:
            self.signals.finished.emit(False, str(e))

    def _sign_and_install_p12_worker(self, ipa_path, p12_path, p12_pwd, prov_path):
        try:
            self.signals.progress.emit(0.05, "正在进行 P12 证书签名...")
            out_ipa = os.path.join(os.path.dirname(ipa_path), f"p12_signed_{os.path.basename(ipa_path)}")
            
            PCSigner.sign_ipa_with_p12(
                ipa_path=ipa_path,
                p12_path=p12_path,
                p12_password=p12_pwd,
                mobileprovision_path=prov_path,
                output_path=out_ipa,
                log_callback=self.signals.log.emit
            )
            
            self.signals.progress.emit(0.50, "签名完成，准备通过 USB 安装到手机...")
            DeviceInstaller.install_ipa(
                device_id=self.current_device["DeviceID"],
                ipa_path=out_ipa,
                lockdown=self.current_lockdown,
                progress_callback=self.signals.progress.emit,
                log_callback=self.signals.log.emit
            )
            self.signals.finished.emit(True, "P12 签名并安装完成！")
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
            self.signals.finished.emit(True, "安装完成！应用已成功安装到手机。")
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
