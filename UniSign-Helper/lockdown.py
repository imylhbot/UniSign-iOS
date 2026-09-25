import struct
import plistlib
import ssl
import socket
import os
import glob
from usbmux import USBMux

LOCKDOWN_PORT = 62078

class LockdownClient:
    """Client for communicating with the iOS lockdown service (port 62078)."""
    
    def __init__(self, device_id, udid=None):
        self.device_id = device_id
        self.udid = udid
        self.sock = None
        self.ssl_sock = None
        self.session_id = None
        self.pair_record = None

    def connect(self):
        mux = USBMux()
        self.sock = mux.connect_device_port(self.device_id, LOCKDOWN_PORT)
        return True

    def close(self):
        if self.ssl_sock:
            try:
                self.ssl_sock.close()
            except Exception:
                pass
            self.ssl_sock = None
        if self.sock:
            try:
                self.sock.close()
            except Exception:
                pass
            self.sock = None

    def _active_sock(self):
        return self.ssl_sock if self.ssl_sock else self.sock

    def send_plist(self, req_dict):
        s = self._active_sock()
        if not s:
            raise ConnectionError("Lockdown socket is not connected")
        
        data = plistlib.dumps(req_dict, fmt=plistlib.FMT_XML)
        header = struct.pack(">I", len(data))
        s.sendall(header + data)

    def recv_plist(self, timeout=6.0):
        s = self._active_sock()
        if not s:
            return None
        s.settimeout(timeout)
        
        # 4 bytes big endian length
        hdr = self._read_exact(s, 4)
        if not hdr:
            return None
        
        length = struct.unpack(">I", hdr)[0]
        body = self._read_exact(s, length)
        if not body:
            return None
        
        return plistlib.loads(body)

    def _read_exact(self, s, num_bytes):
        buf = bytearray()
        while len(buf) < num_bytes:
            chunk = s.recv(num_bytes - len(buf))
            if not chunk:
                break
            buf.extend(chunk)
        return bytes(buf)

    def query_type(self):
        self.send_plist({"Request": "QueryType"})
        return self.recv_plist()

    def get_value(self, domain=None, key=None):
        req = {"Request": "GetValue"}
        if domain:
            req["Domain"] = domain
        if key:
            req["Key"] = key
        self.send_plist(req)
        resp = self.recv_plist()
        if resp and resp.get("Request") == "GetValue":
            return resp.get("Value")
        return None

    def get_all_device_info(self):
        """Retrieves comprehensive device details."""
        name = self.get_value(key="DeviceName") or "iPhone"
        prod_type = self.get_value(key="ProductType") or "iPhone"
        os_version = self.get_value(key="ProductVersion") or "Unknown"
        udid = self.get_value(key="UniqueDeviceID") or self.udid or "Unknown"
        build = self.get_value(key="BuildVersion") or ""
        
        # Human readable mapping
        model_names = {
            "iPhone16,1": "iPhone 15 Pro",
            "iPhone16,2": "iPhone 15 Pro Max",
            "iPhone15,4": "iPhone 15",
            "iPhone15,5": "iPhone 15 Plus",
            "iPhone15,2": "iPhone 14 Pro",
            "iPhone15,3": "iPhone 14 Pro Max",
            "iPhone14,7": "iPhone 14",
            "iPhone14,8": "iPhone 14 Plus",
            "iPhone14,2": "iPhone 13 Pro",
            "iPhone14,3": "iPhone 13 Pro Max",
            "iPhone14,5": "iPhone 13",
            "iPhone14,4": "iPhone 13 mini",
            "iPhone13,2": "iPhone 12",
            "iPhone13,3": "iPhone 12 Pro",
            "iPhone13,4": "iPhone 12 Pro Max",
            "iPhone12,1": "iPhone 11",
            "iPhone12,3": "iPhone 11 Pro",
            "iPhone12,5": "iPhone 11 Pro Max",
            "iPhone11,2": "iPhone XS",
            "iPhone11,6": "iPhone XS Max",
            "iPhone11,8": "iPhone XR",
            "iPhone10,3": "iPhone X",
            "iPhone10,6": "iPhone X"
        }
        friendly_model = model_names.get(prod_type, prod_type)
        
        return {
            "DeviceName": name,
            "ProductType": prod_type,
            "FriendlyModel": friendly_model,
            "ProductVersion": os_version,
            "UniqueDeviceID": udid,
            "BuildVersion": build
        }

    def load_pair_record(self):
        """Finds and loads the pair record for this device from the host system."""
        if not self.udid:
            self.udid = self.get_value(key="UniqueDeviceID")
        
        possible_dirs = [
            os.path.join(os.environ.get("ALLUSERSPROFILE", "C:\\ProgramData"), "Apple", "Lockdown"),
            os.path.join(os.environ.get("APPDATA", ""), "Apple Computer", "Lockdown"),
            "/var/db/lockdown"
        ]
        
        for pdir in possible_dirs:
            if not os.path.exists(pdir):
                continue
            candidates = glob.glob(os.path.join(pdir, f"*{self.udid}*.plist"))
            if candidates:
                try:
                    with open(candidates[0], "rb") as f:
                        self.pair_record = plistlib.load(f)
                        return self.pair_record
                except Exception:
                    pass
        return None

    def start_service(self, service_name):
        """Requests lockdown to start a named service and returns (port, enable_ssl)."""
        req = {
            "Request": "StartService",
            "Service": service_name
        }
        self.send_plist(req)
        resp = self.recv_plist(timeout=10.0)
        if resp and "Port" in resp:
            return resp["Port"], resp.get("EnableServiceSSL", False)
        
        err = resp.get("Error") if resp else "timeout"
        raise ConnectionError(f"Failed to start service {service_name}: {err}")
