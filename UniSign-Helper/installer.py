import os
import struct
import plistlib
import time
from usbmux import USBMux
from lockdown import LockdownClient
from afc_client import AFCClient

class DeviceInstaller:
    """Installs IPA applications directly onto connected iOS devices over USB."""
    
    @staticmethod
    def install_ipa(device_id, ipa_path, lockdown: LockdownClient, progress_callback=None, log_callback=None):
        def log(msg):
            if log_callback:
                log_callback(msg)
            else:
                print(msg)
        
        def update_progress(pct, step):
            if progress_callback:
                progress_callback(pct, step)
        
        if not os.path.exists(ipa_path):
            raise FileNotFoundError(f"IPA 文件不存在: {ipa_path}")
        
        filename = os.path.basename(ipa_path)
        log(f"[*] 准备安装应用: {filename} ({round(os.path.getsize(ipa_path)/(1024*1024), 2)} MB)")
        
        # 1. Connect to AFC service to upload IPA
        update_progress(0.10, "正在连接手机文件传输服务 (AFC)...")
        log("[*] 请求启动 com.apple.afc 手机文件传输服务...")
        afc_port, _ = lockdown.start_service("com.apple.afc")
        
        mux = USBMux()
        afc_sock = mux.connect_device_port(device_id, afc_port)
        afc = AFCClient(afc_sock)
        
        # Ensure PublicStaging directory exists
        afc.make_directory("PublicStaging")
        remote_path = f"PublicStaging/{filename}"
        
        log(f"[*] 正在将 IPA 通过 USB 传输至手机缓存 ({remote_path})...")
        def on_upload_progress(pct, cur, total):
            update_progress(0.10 + pct * 0.40, f"正在传输至手机... {int(pct*100)}%")
        
        afc.upload_file(ipa_path, remote_path, progress_callback=on_upload_progress)
        afc_sock.close()
        log("✅ IPA 文件传输完成！")
        
        # 2. Connect to Installation Proxy
        update_progress(0.55, "正在启动应用安装服务 (Installation Proxy)...")
        log("[*] 请求启动 com.apple.mobile.installation_proxy 应用安装服务...")
        inst_port, _ = lockdown.start_service("com.apple.mobile.installation_proxy")
        
        inst_sock = mux.connect_device_port(device_id, inst_port)
        
        install_req = {
            "Command": "Install",
            "ClientOptions": {
                "PackageType": "Developer"
            },
            "PackagePath": remote_path
        }
        
        req_data = plistlib.dumps(install_req, fmt=plistlib.FMT_XML)
        hdr = struct.pack(">I", len(req_data))
        inst_sock.sendall(hdr + req_data)
        
        log("[*] 正在等待手机系统完成校验与安装解包...")
        
        while True:
            # Read 4 bytes length
            hdr_data = inst_sock.recv(4)
            if not hdr_data or len(hdr_data) < 4:
                break
            
            p_len = struct.unpack(">I", hdr_data)[0]
            buf = bytearray()
            while len(buf) < p_len:
                chunk = inst_sock.recv(p_len - len(buf))
                if not chunk:
                    break
                buf.extend(chunk)
            
            if not buf:
                break
            
            try:
                resp = plistlib.loads(buf)
                status = resp.get("Status")
                pct = resp.get("PercentComplete", 0)
                
                if status:
                    log(f"[*] 安装进度: {status} ({pct}%)")
                    update_progress(0.55 + (pct / 100.0) * 0.40, f"正在安装: {status} ({pct}%)")
                
                if status == "Complete":
                    log("🎉 安装成功！UniSign 已成功部署到手机桌面。")
                    update_progress(1.0, "安装完成！")
                    inst_sock.close()
                    return True
                
                if "Error" in resp:
                    err_msg = resp.get("ErrorDescription", resp["Error"])
                    log(f"❌ 安装失败: {err_msg}")
                    inst_sock.close()
                    raise RuntimeError(f"安装失败: {err_msg}")
                    
            except Exception as e:
                if "安装失败" in str(e):
                    raise
                pass
        
        inst_sock.close()
        log("✅ 安装指令已执行完成！请检查手机桌面。")
        update_progress(1.0, "安装成功！")
        return True
