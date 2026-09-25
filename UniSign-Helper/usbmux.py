import socket
import struct
import plistlib
import platform
import os
import sys

USBMUXD_SOCKET_PORT = 27015

class USBMux:
    """Pure-Python client for communicating with Apple Mobile Device Service (usbmuxd) over TCP port 27015."""
    
    def __init__(self, host="127.0.0.1", port=USBMUXD_SOCKET_PORT):
        self.host = host
        self.port = port
        self.sock = None
        self.tag = 1

    def connect(self):
        try:
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.sock.settimeout(5.0)
            self.sock.connect((self.host, self.port))
            return True
        except Exception as e:
            self.sock = None
            return False

    def close(self):
        if self.sock:
            try:
                self.sock.close()
            except Exception:
                pass
            self.sock = None

    def send_packet(self, payload_dict):
        if not self.sock:
            if not self.connect():
                raise ConnectionError(
                    "无法连接到 Apple 移动设备服务 (iTunes/Apple Mobile Device Support)\n"
                    "请确保：\n"
                    "1. iTunes 或 Apple Devices 已安装并正在运行\n"
                    "2. iPhone 已通过 USB 连接，并在手机上点击【信任此电脑】\n"
                    "3. Apple Mobile Device Service (AMDS) 服务正在运行"
                )
        
        xml_data = plistlib.dumps(payload_dict, fmt=plistlib.FMT_XML)
        length = 16 + len(xml_data)
        version = 1
        msg_type = 8  # Plist
        tag = self.tag
        self.tag += 1
        
        header = struct.pack("<IIII", length, version, msg_type, tag)
        self.sock.sendall(header + xml_data)

    def receive_packet(self, timeout=5.0):
        if not self.sock:
            return None
        self.sock.settimeout(timeout)
        
        header_data = self._read_exact(16)
        if not header_data:
            return None
        
        length, version, msg_type, tag = struct.unpack("<IIII", header_data)
        payload_len = length - 16
        if payload_len <= 0:
            return None
        
        payload_data = self._read_exact(payload_len)
        if not payload_data:
            return None
        
        try:
            return plistlib.loads(payload_data)
        except Exception:
            return None

    def _read_exact(self, num_bytes):
        buf = bytearray()
        while len(buf) < num_bytes:
            chunk = self.sock.recv(num_bytes - len(buf))
            if not chunk:
                break
            buf.extend(chunk)
        return bytes(buf)

    def list_devices(self):
        """Queries currently connected iOS devices from usbmuxd."""
        mux = USBMux(self.host, self.port)
        if not mux.connect():
            return []
        
        req = {
            "MessageType": "ListDevices",
            "ClientVersionString": "UniSignHelper-2.5",
            "ProgName": "UniSign"
        }
        devices = []
        try:
            mux.send_packet(req)
            resp = mux.receive_packet(timeout=3.0)
            if resp and "DeviceList" in resp:
                for entry in resp["DeviceList"]:
                    props = entry.get("Properties", {})
                    devices.append({
                        "DeviceID": entry.get("DeviceID", 0),
                        "MessageType": entry.get("MessageType", "Attached"),
                        "SerialNumber": props.get("SerialNumber", ""),
                        "ConnectionType": props.get("ConnectionType", "USB"),
                        "ProductID": props.get("ProductID", 0)
                    })
        except Exception:
            pass
        finally:
            mux.close()
        return devices

    def connect_device_port(self, device_id, port_number):
        """Opens a raw TCP channel to a TCP port on the target iOS device via usbmuxd."""
        mux = USBMux(self.host, self.port)
        if not mux.connect():
            raise ConnectionError("Failed to connect to usbmuxd")
        
        # Port number in usbmuxd is in network byte order
        port_be = socket.htons(port_number)
        req = {
            "MessageType": "Connect",
            "ClientVersionString": "UniSignHelper-2.5",
            "ProgName": "UniSign",
            "DeviceID": device_id,
            "PortNumber": port_be
        }
        mux.send_packet(req)
        resp = mux.receive_packet(timeout=8.0)
        if resp and resp.get("Number") == 0:
            raw_sock = mux.sock
            mux.sock = None  # Detach so close() doesn't kill it
            return raw_sock
        else:
            code = resp.get("Number") if resp else "timeout"
            mux.close()
            raise ConnectionError(
                f"无法连接设备端口 {port_number} (错误码: {code})\n"
                f"可能的原因：\n"
                f"- 手机屏幕未解锁，或锁屏超时断开了 USB 会话\n"
                f"- 数据线连接不稳定，请重新插拔\n"
                f"- iTunes 服务未正常运行，请重启 iTunes"
            )
