import struct
import plistlib
import ssl
import socket
import os
import glob
import tempfile
from usbmux import USBMux

LOCKDOWN_PORT = 62078

class LockdownClient:
    """Client for communicating with the iOS lockdown service (port 62078).
    
    IMPORTANT: The lockdown connection used for device polling is a plain
    (non-SSL) connection. Calling StartService requires an *active* lockdown
    session, which means we need a fresh connection + StartSession with SSL.
    
    For each install/service call, always call fresh_connect_for_service() to
    get a dedicated, session-aware LockdownClient rather than reusing the
    polling connection (which may have gone SessionInactive).
    """
    
    def __init__(self, device_id, udid=None):
        self.device_id = device_id
        self.udid = udid
        self.sock = None
        self.ssl_sock = None
        self.session_id = None
        self.pair_record = None

    def connect(self):
        """Connect a plain (non-SSL) lockdown socket for basic queries."""
        mux = USBMux()
        self.sock = mux.connect_device_port(self.device_id, LOCKDOWN_PORT)
        self.sock.settimeout(8.0)
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

    def recv_plist(self, timeout=8.0):
        s = self._active_sock()
        if not s:
            return None
        s.settimeout(timeout)
        
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
        serial = self.get_value(key="SerialNumber") or ""
        capacity = self.get_value(key="TotalDiskCapacity") or 0
        color = self.get_value(key="DeviceColor") or ""
        
        model_names = {
            "iPhone17,1": "iPhone 16 Pro",
            "iPhone17,2": "iPhone 16 Pro Max",
            "iPhone17,3": "iPhone 16",
            "iPhone17,4": "iPhone 16 Plus",
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
            "iPhone13,1": "iPhone 12 mini",
            "iPhone12,1": "iPhone 11",
            "iPhone12,3": "iPhone 11 Pro",
            "iPhone12,5": "iPhone 11 Pro Max",
            "iPhone11,2": "iPhone XS",
            "iPhone11,6": "iPhone XS Max",
            "iPhone11,8": "iPhone XR",
            "iPhone10,3": "iPhone X",
            "iPhone10,6": "iPhone X",
            "iPad13,18": "iPad Pro 12.9\" (6th gen)",
            "iPad13,19": "iPad Pro 12.9\" (6th gen)",
            "iPad13,16": "iPad Pro 11\" (4th gen)",
            "iPad13,17": "iPad Pro 11\" (4th gen)",
        }
        friendly_model = model_names.get(prod_type, prod_type)
        
        capacity_gb = 0
        if isinstance(capacity, int) and capacity > 0:
            capacity_gb = round(capacity / (1024 ** 3))
        
        return {
            "DeviceName": name,
            "ProductType": prod_type,
            "FriendlyModel": friendly_model,
            "ProductVersion": os_version,
            "UniqueDeviceID": udid,
            "BuildVersion": build,
            "SerialNumber": serial,
            "TotalCapacityGB": capacity_gb,
            "DeviceColor": color,
        }

    def load_pair_record(self):
        """Finds and loads the pairing record (.plist) for this device from the host file system."""
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

    def start_session(self, pair_record):
        """Initiates an SSL-authenticated lockdown session using the device pair record.
        
        This is required before calling StartService for most services.
        Returns True on success.
        """
        # 1. Send StartSession
        req = {
            "Request": "StartSession",
            "HostID": pair_record.get("HostID", ""),
            "SystemBUID": pair_record.get("SystemBUID", ""),
        }
        self.send_plist(req)
        resp = self.recv_plist(timeout=10.0)
        
        if not resp:
            raise ConnectionError("StartSession: no response from device")
        
        if resp.get("Error"):
            raise ConnectionError(f"StartSession failed: {resp['Error']}")
        
        self.session_id = resp.get("SessionID")
        uses_ssl = resp.get("EnableSessionSSL", False)
        
        if uses_ssl:
            # 2. Upgrade plain socket to SSL using pair record credentials
            host_cert_pem = pair_record.get("HostCertificate")
            host_key_pem = pair_record.get("HostPrivateKey")
            root_cert_pem = pair_record.get("RootCertificate")
            
            if not host_cert_pem or not host_key_pem:
                raise ConnectionError("StartSession: pair record missing host certificate/key")
            
            # Write temp PEM files for ssl.wrap_socket
            tmp_dir = tempfile.mkdtemp()
            try:
                cert_file = os.path.join(tmp_dir, "host.crt")
                key_file = os.path.join(tmp_dir, "host.key")
                ca_file = os.path.join(tmp_dir, "ca.crt")
                
                with open(cert_file, "wb") as f:
                    f.write(host_cert_pem if isinstance(host_cert_pem, bytes) else host_cert_pem.encode())
                with open(key_file, "wb") as f:
                    f.write(host_key_pem if isinstance(host_key_pem, bytes) else host_key_pem.encode())
                if root_cert_pem:
                    with open(ca_file, "wb") as f:
                        f.write(root_cert_pem if isinstance(root_cert_pem, bytes) else root_cert_pem.encode())
                
                ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
                ctx.check_hostname = False
                ctx.verify_mode = ssl.CERT_NONE
                ctx.load_cert_chain(cert_file, key_file)
                self.ssl_context = ctx
                
                raw_sock = self.sock
                self.ssl_sock = ctx.wrap_socket(raw_sock, server_side=False)
                self.sock = None  # SSL now owns the raw socket
            finally:
                import shutil
                shutil.rmtree(tmp_dir, ignore_errors=True)
        
        return True

    def wrap_service_socket(self, raw_sock):
        """Wraps a service socket with SSL using the session's SSLContext if enabled."""
        if hasattr(self, "ssl_context") and self.ssl_context:
            return self.ssl_context.wrap_socket(raw_sock, server_side=False)
        return raw_sock

    def stop_session(self):
        """Ends the current lockdown session."""
        if self.session_id:
            try:
                self.send_plist({"Request": "StopSession", "SessionID": self.session_id})
                self.recv_plist(timeout=3.0)
            except Exception:
                pass
            self.session_id = None


    def start_service(self, service_name):
        """Requests lockdown to start a named service and returns (port, enable_ssl).
        
        NOTE: Requires an active session (call start_session first if pairing is needed).
        """
        req = {
            "Request": "StartService",
            "Service": service_name
        }
        self.send_plist(req)
        resp = self.recv_plist(timeout=12.0)
        if resp and "Port" in resp:
            return resp["Port"], resp.get("EnableServiceSSL", False)
        
        err = resp.get("Error") if resp else "timeout"
        raise ConnectionError(f"Failed to start service {service_name}: {err}")

    @classmethod
    def fresh_for_service(cls, device_id, udid):
        """Creates a fresh LockdownClient, loads the pair record, and establishes
        a full SSL session - ready to call start_service() for AFC, installation proxy, etc.
        
        This is the correct way to call services that require an active lockdown session.
        The device polling connection goes stale (SessionInactive) over time, so service
        calls should always use a brand new connection via this method.
        """
        ld = cls(device_id, udid)
        ld.connect()
        
        pair_record = ld.load_pair_record()
        if pair_record:
            try:
                ld.start_session(pair_record)
                return ld
            except Exception as e:
                # If SSL session fails, still return the plain connection
                # (some services work without SSL on older iOS versions)
                pass
        
        return ld
