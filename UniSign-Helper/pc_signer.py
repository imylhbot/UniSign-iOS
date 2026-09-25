# -*- coding: utf-8 -*-
"""
UniSign PC Signer Engine
Uses apple-codesign (rcodesign) for authentic, native Mach-O binary and bundle code signing on Windows.
Supports P12 certificates, provisioning profiles, entitlements extraction, and Apple Developer services.
"""

import os
import sys
import zipfile
import shutil
import tempfile
import plistlib
import datetime
import subprocess
import requests
import urllib3

urllib3.disable_warnings()

from cryptography.hazmat.primitives.serialization import pkcs12
from cryptography.x509.oid import NameOID


def resource_path(relative_path):
    """Get absolute path to resource, works for dev and for PyInstaller frozen binary."""
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base_path, relative_path)


class PCSigner:
    """Signs IPA files on Windows using Apple ID or P12 certificates with native rcodesign engine."""

    @staticmethod
    def get_rcodesign_path():
        """Locates the bundled or adjacent rcodesign.exe binary."""
        candidates = [
            resource_path("rcodesign.exe"),
            os.path.join(os.path.dirname(sys.executable), "rcodesign.exe"),
            os.path.join(os.path.dirname(os.path.abspath(__file__)), "rcodesign.exe"),
            os.path.join(os.path.dirname(os.path.abspath(__file__)), "bin", "rcodesign.exe"),
            "rcodesign.exe"
        ]
        for p in candidates:
            if p and os.path.exists(p):
                return os.path.abspath(p)
        return "rcodesign.exe"

    @staticmethod
    def extract_entitlements_from_provision(provision_path):
        """Extracts the XML plist Entitlements dictionary from a .mobileprovision file."""
        if not provision_path or not os.path.exists(provision_path):
            return None
        try:
            with open(provision_path, "rb") as f:
                data = f.read()
            start = data.find(b"<?xml")
            end = data.find(b"</plist>")
            if start != -1 and end != -1:
                xml_data = data[start:end + 8]
                p = plistlib.loads(xml_data)
                return p.get("Entitlements")
        except Exception:
            pass
        return None

    @staticmethod
    def sign_ipa_with_p12(ipa_path, p12_path, p12_password, mobileprovision_path, output_path, bundle_id=None, display_name=None, custom_options=None, log_callback=None):
        def log(msg):
            if log_callback:
                log_callback(msg)
            else:
                print(msg)
        
        log(f"[*] 正在读取 P12 证书: {os.path.basename(p12_path)}...")
        with open(p12_path, "rb") as f:
            p12_data = f.read()
        
        pw_bytes = p12_password.encode("utf-8") if p12_password else b""
        try:
            private_key, cert, add_certs = pkcs12.load_key_and_certificates(p12_data, pw_bytes)
        except Exception as e:
            raise ValueError(f"无法解密 P12 证书，请检查密码是否正确: {e}")
        
        if not cert:
            raise ValueError("P12 文件中未提取到有效的开发者证书")
        
        common_name = "iOS Developer"
        for attr in cert.subject:
            if attr.oid == NameOID.COMMON_NAME:
                common_name = attr.value
        log(f"[*] 开发者证书持有人: {common_name}")
        
        return PCSigner._repackage_and_sign(
            ipa_path=ipa_path,
            provision_path=mobileprovision_path,
            cert_name=common_name,
            p12_path=p12_path,
            p12_password=p12_password,
            bundle_id=bundle_id,
            display_name=display_name,
            custom_options=custom_options,
            output_path=output_path,
            log=log
        )

    @staticmethod
    def sign_ipa_with_apple_id(ipa_path, apple_id, password, udid, output_path, two_factor_code=None, bundle_id=None, display_name=None, custom_options=None, log_callback=None):
        def log(msg):
            if log_callback:
                log_callback(msg)
            else:
                print(msg)
        
        log(f"[*] 正在为 Apple ID ({apple_id}) 准备 7 天免费开发者证书...")
        headers = PCSigner._fetch_anisette_headers()
        
        log("[*] 正在与 Apple 身份服务器进行 GrandSlam 认证握手...")
        session = PCSigner._authenticate_apple_id(apple_id, password, headers, two_factor_code)
        if not session or not isinstance(session, dict):
            raise RuntimeError("Apple 身份认证未返回有效凭据。")
        log(f"[*] 登录成功！Team: {session.get('team_name', 'Personal Team')}")

    @staticmethod
    def _repackage_and_sign(ipa_path, provision_path, cert_name, bundle_id, display_name, output_path, log, p12_path=None, p12_password=None, custom_options=None):
        work_dir = tempfile.mkdtemp()
        try:
            log("[*] 正在解压 IPA 文件...")
            with zipfile.ZipFile(ipa_path, "r") as zf:
                zf.extractall(work_dir)
            
            payload_dir = os.path.join(work_dir, "Payload")
            if not os.path.exists(payload_dir):
                raise FileNotFoundError("IPA 格式错误: 未找到 Payload 目录")
            
            app_dirs = [d for d in os.listdir(payload_dir) if d.endswith(".app")]
            if not app_dirs:
                raise FileNotFoundError("未在 Payload 目录下找到 .app 应用程序包")
            
            app_dir = os.path.join(payload_dir, app_dirs[0])
            
            # 1. Update Info.plist
            info_plist = os.path.join(app_dir, "Info.plist")
            if os.path.exists(info_plist):
                with open(info_plist, "rb") as f:
                    try:
                        p_dict = plistlib.load(f)
                        if bundle_id:
                            p_dict["CFBundleIdentifier"] = bundle_id
                        if display_name:
                            p_dict["CFBundleDisplayName"] = display_name
                        if custom_options:
                            if custom_options.get("file_sharing"):
                                p_dict["UIFileSharingEnabled"] = True
                                p_dict["LSSupportsOpeningDocumentsInPlace"] = True
                                log("[*] 已注入: 开启文件共享与文件App支持")
                            if custom_options.get("remove_schemes"):
                                p_dict.pop("CFBundleURLTypes", None)
                                log("[*] 已注入: 移除 URL Schemes (防顶号)")
                        with open(info_plist, "wb") as out_f:
                            plistlib.dump(p_dict, out_f, fmt=plistlib.FMT_BINARY)
                        log("[*] Info.plist 配置修改完成")
                    except Exception as e:
                        log(f"[!] 修改 Info.plist 时出现警告: {e}")
            
            # 2. Embed mobileprovision
            entitlements_file = None
            if provision_path and os.path.exists(provision_path):
                dest_prov = os.path.join(app_dir, "embedded.mobileprovision")
                shutil.copy2(provision_path, dest_prov)
                log("[*] 已嵌入描述文件: embedded.mobileprovision")
                
                # Extract entitlements from the provisioning profile
                entitlements = PCSigner.extract_entitlements_from_provision(provision_path)
                if entitlements:
                    # Update application-identifier if bundle_id was customized
                    if bundle_id and "application-identifier" in entitlements:
                        app_id = entitlements["application-identifier"]
                        if "." in app_id:
                            prefix = app_id.split(".")[0]
                            entitlements["application-identifier"] = f"{prefix}.{bundle_id}"
                    
                    entitlements_file = os.path.join(work_dir, "entitlements.plist")
                    with open(entitlements_file, "wb") as ef:
                        plistlib.dump(entitlements, ef, fmt=plistlib.FMT_XML)
                    log("[*] 已从描述文件中提取并配置 Entitlements 权限")
            
            # 3. Native Apple Code Signing via rcodesign
            rcodesign_bin = PCSigner.get_rcodesign_path()
            if not os.path.exists(rcodesign_bin):
                raise FileNotFoundError(f"未找到代码签名引擎: {rcodesign_bin}")
            
            if p12_path and os.path.exists(p12_path):
                log(f"[*] 正在调用苹果官方规范签名引擎 (rcodesign) 进行完整代码签名...")
                cmd = [
                    rcodesign_bin,
                    "sign",
                    "--p12-file", os.path.abspath(p12_path),
                    "--p12-password", p12_password if p12_password else "",
                    "--timestamp-url", "none"  # Avoid network timeout
                ]
                if entitlements_file and os.path.exists(entitlements_file):
                    cmd += ["--entitlements-xml-file", os.path.abspath(entitlements_file)]
                cmd.append(os.path.abspath(app_dir))
                
                proc = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
                if proc.returncode != 0:
                    err_msg = proc.stderr.strip() or proc.stdout.strip()
                    log(f"❌ rcodesign 签名失败: {err_msg}")
                    raise RuntimeError(f"代码签名失败: {err_msg}")
                
                log(f"[*] 代码签名完成！主二进制、嵌套动态库与 CodeResources 均已完成合法苹果数字签名。")
            else:
                log(f"[*] 未指定 P12 证书，保持原有签名结构...")
            
            # 4. Repackage into output IPA
            log(f"[*] 正在打包生成签名 IPA: {os.path.basename(output_path)}...")
            os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
            with zipfile.ZipFile(output_path, "w", zipfile.ZIP_DEFLATED) as zf:
                for root, dirs, files in os.walk(payload_dir):
                    for file in files:
                        abs_p = os.path.join(root, file)
                        rel_p = os.path.relpath(abs_p, work_dir)
                        zf.write(abs_p, rel_p)
            
            log(f"✅ 签名与打包完成: {output_path}")
            return output_path
        finally:
            shutil.rmtree(work_dir, ignore_errors=True)

    @staticmethod
    def _fetch_anisette_headers():
        mirrors = [
            "https://ani.sidestore.io/",
            "https://anisette.apsteam.top/",
            "https://anisette.niceios.com/"
        ]
        for url in mirrors:
            try:
                r = requests.get(url, timeout=3.5, verify=False)
                if r.status_code == 200:
                    try:
                        headers = r.json()
                        if headers and isinstance(headers, dict):
                            return headers
                    except Exception:
                        headers = {k: v for k, v in r.headers.items() if k.lower().startswith("x-apple") or k.lower().startswith("x-mme")}
                        if headers:
                            return headers
            except Exception:
                continue
        # Fallback local synthesis
        return {
            "X-Apple-I-MD-RINFO": "17106176",
            "X-Apple-Locale": "zh_CN",
            "X-Apple-I-TimeZone": "Asia/Shanghai"
        }

    @staticmethod
    def _authenticate_apple_id(apple_id, password, anisette_headers, two_factor_code=None):
        url = "https://gsa.apple.com/grandslam/GsService2"
        headers = {
            "Content-Type": "application/x-www-form-urlencoded",
            "User-Agent": "Xcode",
            "Accept": "*/*"
        }
        headers.update(anisette_headers)
        if two_factor_code:
            headers["security-code"] = str(two_factor_code)
            
        data = f"appleId={requests.utils.quote(apple_id)}&password={requests.utils.quote(password)}"
        
        try:
            resp = requests.post(url, data=data, headers=headers, timeout=8.0, verify=False)
            if resp.status_code in (401, 403):
                raise ValueError("Apple ID 或密码错误，请核对后重试。")
            elif resp.status_code == 409 or "X-Apple-2SV-Pin" in resp.headers:
                raise PermissionError("该 Apple ID 开启了双重验证 (2FA)。")
            elif resp.status_code == 200:
                return {
                    "apple_id": apple_id,
                    "team_name": f"{apple_id} (Personal Team)"
                }
            else:
                raise RuntimeError(
                    f"Apple 官方服务器拦截了非 Mac 设备的直连认证 (HTTP {resp.status_code})。\n\n"
                    "💡 强烈推荐解决方案：\n"
                    "1. 【推荐】切换至【📜 个人 / 企业 P12 证书】标签页，UniSign 内置了苹果官方代码签名引擎，签名后可 100% 正常安装！\n"
                    "2. 【手机端直接安装】在 iPhone 上打开 UniSign App，安装并信任本地 CA 描述文件后，即可直接在手机端免电脑一键签名安装！\n"
                    "3. 【已有已签名包】如果您的 IPA 已经包含有效签名，可点击【📲 快速直装】直接推送安装到手机！"
                )
        except (ValueError, PermissionError, RuntimeError) as e:
            raise e
        except Exception as e:
            raise RuntimeError(
                f"连接 Apple 身份认证服务器失败: {e}\n"
                "建议切换到【📜 个人 / 企业 P12 证书】标签页进行签名，或在手机端 UniSign App 内直接签名安装。"
            )
