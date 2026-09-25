import os
import struct
import plistlib
import time
from usbmux import USBMux
from lockdown import LockdownClient
from afc_client import AFCClient

class DeviceInstaller:
    """Installs IPA applications directly onto connected iOS devices over USB.
    
    Key design note:
    - The 'lockdown' parameter passed in from the GUI is the polling connection,
      which is a plain non-SSL connection used for device info queries. It becomes
      'SessionInactive' when you try to use it for StartService calls after a
      period of time.
    - We now create a FRESH, fully-authenticated lockdown connection for each
      installation operation using LockdownClient.fresh_for_service(), which
      establishes a proper SSL session using the iTunes pair record.
    """
    
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
        
        udid = lockdown.udid if lockdown else None
        
        # Create a FRESH lockdown session for service calls (avoids SessionInactive)
        update_progress(0.05, "正在建立设备专用通信会话...")
        log("[*] 正在为安装操作建立专用 Lockdown 会话...")
        
        try:
            service_ld = LockdownClient.fresh_for_service(device_id, udid)
            log("[*] 设备专用会话建立成功！")
        except Exception as e:
            # Fallback: use the provided lockdown connection
            log(f"[!] 专用会话建立失败 ({e})，尝试使用现有连接...")
            service_ld = lockdown
        
        # 1. Connect to AFC service to upload IPA
        update_progress(0.10, "正在连接手机文件传输服务 (AFC)...")
        log("[*] 请求启动 com.apple.afc 手机文件传输服务...")
        
        try:
            afc_port, _ = service_ld.start_service("com.apple.afc")
        except ConnectionError as e:
            err_str = str(e)
            if "SessionInactive" in err_str or "InvalidResponse" in err_str:
                # Force a retry with a completely fresh connection
                log("[!] 会话已过期，正在重新建立连接...")
                try:
                    service_ld.close()
                except Exception:
                    pass
                service_ld = LockdownClient.fresh_for_service(device_id, udid)
                afc_port, _ = service_ld.start_service("com.apple.afc")
            else:
                raise
        
        mux = USBMux()
        afc_sock = mux.connect_device_port(device_id, afc_port)
        afc_sock.settimeout(60.0)
        afc = AFCClient(afc_sock)
        
        # Ensure PublicStaging directory exists
        afc.make_directory("PublicStaging")
        remote_path = f"PublicStaging/{filename}"
        
        log(f"[*] 正在将 IPA 通过 USB 传输至手机缓存 ({remote_path})...")
        def on_upload_progress(pct, cur, total):
            update_progress(0.10 + pct * 0.42, f"正在传输至手机... {int(pct*100)}% ({round(cur/(1024*1024), 1)} / {round(total/(1024*1024), 1)} MB)")
        
        afc.upload_file(ipa_path, remote_path, progress_callback=on_upload_progress)
        afc_sock.close()
        log("✅ IPA 文件传输完成！")
        
        # 2. Connect to Installation Proxy with the SAME fresh session
        update_progress(0.55, "正在启动应用安装服务 (Installation Proxy)...")
        log("[*] 请求启动 com.apple.mobile.installation_proxy 应用安装服务...")
        inst_port, _ = service_ld.start_service("com.apple.mobile.installation_proxy")
        
        inst_sock = mux.connect_device_port(device_id, inst_port)
        inst_sock.settimeout(120.0)
        
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
            try:
                hdr_data = self_recv_exact(inst_sock, 4)
                if not hdr_data or len(hdr_data) < 4:
                    break
                
                p_len = struct.unpack(">I", hdr_data)[0]
                buf = self_recv_exact(inst_sock, p_len)
                
                if not buf:
                    break
                
                try:
                    resp = plistlib.loads(buf)
                    status = resp.get("Status")
                    pct = resp.get("PercentComplete", 0)
                    
                    if status:
                        log(f"[*] 安装进度: {status} ({pct}%)")
                        update_progress(0.55 + (pct / 100.0) * 0.42, f"正在安装: {status} ({pct}%)")
                    
                    if status == "Complete":
                        log("🎉 安装成功！应用已成功部署到手机桌面。")
                        update_progress(1.0, "✅ 安装完成！请在手机桌面找到应用图标。")
                        inst_sock.close()
                        try:
                            service_ld.stop_session()
                            service_ld.close()
                        except Exception:
                            pass
                        return True
                    
                    if "Error" in resp:
                        err_msg = resp.get("ErrorDescription", resp["Error"])
                        log(f"❌ 安装失败: {err_msg}")
                        inst_sock.close()
                        raise RuntimeError(f"安装失败: {err_msg}")
                    
                except ValueError:
                    pass
                    
            except Exception as e:
                if "安装失败" in str(e) or "Failed" in str(e):
                    raise
                break
        
        inst_sock.close()
        try:
            service_ld.stop_session()
            service_ld.close()
        except Exception:
            pass
        
        log("✅ 安装指令执行完成！请检查手机桌面是否出现应用图标。")
        update_progress(1.0, "安装成功！")
        return True


def self_recv_exact(sock, num_bytes):
    """Read exactly num_bytes from a socket."""
    buf = bytearray()
    while len(buf) < num_bytes:
        chunk = sock.recv(num_bytes - len(buf))
        if not chunk:
            break
        buf.extend(chunk)
    return bytes(buf)
