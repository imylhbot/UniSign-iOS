import struct
import plistlib
from usbmux import USBMux
from lockdown import LockdownClient

class DeveloperModeManager:
    """Manages iOS 16+ Developer Mode detection and activation via AMFI service."""
    
    @staticmethod
    def is_ios16_or_newer(product_version):
        try:
            major = int(product_version.split(".")[0])
            return major >= 16
        except Exception:
            return False

    @staticmethod
    def check_developer_mode_status(lockdown: LockdownClient):
        """Checks whether Developer Mode is currently enabled."""
        try:
            status = lockdown.get_value("com.apple.security.mac.amfi", "DeveloperModeStatus")
            if status is not None:
                return bool(status)
        except Exception:
            pass
        return None

    @staticmethod
    def enable_developer_mode(device_id, lockdown: LockdownClient, log_callback=None):
        """
        Interacts with the iOS com.apple.amfi.lockdown service to trigger Developer Mode activation.
        On success, iOS will prompt the user to reboot into Developer Mode.
        """
        def log(msg):
            if log_callback:
                log_callback(msg)
            else:
                print(msg)
        
        info = lockdown.get_all_device_info()
        os_ver = info.get("ProductVersion", "0")
        
        if not DeveloperModeManager.is_ios16_or_newer(os_ver):
            log(f"[*] 当前设备 iOS 版本为 {os_ver}（低于 iOS 16），无需开启开发者模式即可直接运行签名应用。")
            return True, "iOS < 16, Developer Mode not required."
        
        log(f"[*] 检测到 iOS {os_ver} 设备，正在检查开发者模式状态...")
        current_status = DeveloperModeManager.check_developer_mode_status(lockdown)
        if current_status is True:
            log("✅ 设备已开启开发者模式！可直接安装并运行签名应用。")
            return True, "Developer Mode is already active."
        
        log("[*] 正在建立专用服务会话以激活 AMFI...")
        try:
            # Create fresh session for service calls
            fresh_ld = LockdownClient.fresh_for_service(device_id, lockdown.udid)
        except Exception:
            fresh_ld = lockdown
        
        log("[*] 正在请求启动 com.apple.amfi.lockdown 安全完整性服务...")
        try:
            port, enable_ssl = fresh_ld.start_service("com.apple.amfi.lockdown")
            log(f"[*] AMFI 服务已在端口 {port} 启动，正在建立通信通道...")
            
            mux = USBMux()
            amfi_sock = mux.connect_device_port(device_id, port)
            amfi_sock.settimeout(10.0)
            
            # Action 1 triggers Developer Mode enable request in AMFI
            req_data = plistlib.dumps({"action": 1}, fmt=plistlib.FMT_XML)
            hdr = struct.pack(">I", len(req_data))
            amfi_sock.sendall(hdr + req_data)
            
            # Read response
            resp_hdr = amfi_sock.recv(4)
            if resp_hdr and len(resp_hdr) == 4:
                resp_len = struct.unpack(">I", resp_hdr)[0]
                resp_body = amfi_sock.recv(resp_len)
                resp_plist = plistlib.loads(resp_body)
                log(f"[*] AMFI 服务响应: {resp_plist}")
            
            amfi_sock.close()
            try:
                fresh_ld.stop_session()
                fresh_ld.close()
            except Exception:
                pass
            
            log("📲 开启指令已成功发送至手机！")
            log("👉 请查看手机屏幕：点击提示框中的『重新启动』，重启后解锁手机并点击『开启』，输入手机锁屏密码即可成功开启开发者模式！")
            return True, "Prompted on device"
            
        except Exception as e:
            log(f"⚠️ 通过 AMFI 服务开启开发者模式遇到异常: {e}")
            log("ℹ️ 您也可以直接在手机上手动开启：打开手机『设置』->『隐私与安全性』-> 滑到最底部点击『开发者模式』并开启。")
            return False, str(e)

