import struct
import os

class AFCClient:
    """Lightweight Apple File Conduit (AFC) client for staging files onto the iOS device."""
    
    MAGIC = b"CFA6LPAA"
    
    # Official Apple AFC Protocol Opcodes (libimobiledevice / pymobiledevice3)
    OP_STATUS = 1          # 0x01
    OP_DATA = 2            # 0x02
    OP_READ_DIR = 3        # 0x03
    OP_READ_FILE = 4       # 0x04
    OP_WRITE_FILE = 5      # 0x05
    OP_MAKE_DIR = 9        # 0x09
    OP_GET_FILE_INFO = 10  # 0x0A
    OP_FILE_OPEN = 13      # 0x0D (FileRefOpen)
    OP_FILE_OPEN_RES = 14  # 0x0E (FileRefOpenResult)
    OP_FILE_READ = 15      # 0x0F (FileRefRead)
    OP_FILE_WRITE = 16     # 0x10 (FileRefWrite)
    OP_FILE_SEEK = 17      # 0x11
    OP_FILE_TELL = 18      # 0x12
    OP_FILE_CLOSE = 20     # 0x14 (FileRefClose)
    
    def __init__(self, sock):
        self.sock = sock
        self.packet_num = 0

    def _send_packet(self, operation, data=b""):
        self.packet_num += 1
        header_len = 40
        entire_len = header_len + len(data)
        hdr = struct.pack("<8sQQQQ", self.MAGIC, entire_len, header_len, self.packet_num, operation)
        self.sock.sendall(hdr + data)

    def _recv_packet(self):
        hdr = self._read_exact(40)
        if not hdr or len(hdr) < 40:
            return None, b""
        magic, entire_len, this_len, pkt_num, op = struct.unpack("<8sQQQQ", hdr)
        if magic != self.MAGIC:
            return None, b""
        if entire_len < 40 or entire_len > 10 * 1024 * 1024:
            return None, b""
        payload_len = entire_len - this_len
        if payload_len < 0 or payload_len > 10 * 1024 * 1024:
            return None, b""
        payload = self._read_exact(payload_len) if payload_len > 0 else b""
        return op, payload

    def _read_exact(self, count):
        if count <= 0 or count > 10 * 1024 * 1024:
            return b""
        buf = bytearray()
        while len(buf) < count:
            try:
                chunk = self.sock.recv(count - len(buf))
                if not chunk:
                    break
                buf.extend(chunk)
            except Exception:
                break
        return bytes(buf)

    def make_directory(self, path):
        data = path.encode("utf-8") + b"\x00"
        self._send_packet(self.OP_MAKE_DIR, data)
        op, payload = self._recv_packet()
        return True

    def file_open(self, path, mode=3):
        """mode 3 = read/write create/truncate (O_RDWR | O_CREAT | O_TRUNC)"""
        mode_data = struct.pack("<Q", mode)
        path_data = path.encode("utf-8") + b"\x00"
        self._send_packet(self.OP_FILE_OPEN, mode_data + path_data)
        op, payload = self._recv_packet()
        if op is None:
            raise ConnectionError("AFC 文件服务通信中断 (未能收到手机响应，可能 USB 数据线松动或未完成 SSL 握手)")
        if payload and len(payload) >= 8:
            handle = struct.unpack("<Q", payload[:8])[0]
            return handle
        return None

    def file_write(self, handle, data):
        self.packet_num += 1
        header_len = 40
        this_len = header_len + 8  # 40 bytes header + 8 bytes handle
        entire_len = this_len + len(data)
        hdr = struct.pack("<8sQQQQ", self.MAGIC, entire_len, this_len, self.packet_num, self.OP_FILE_WRITE)
        handle_data = struct.pack("<Q", handle)
        self.sock.sendall(hdr + handle_data + data)
        op, payload = self._recv_packet()
        if op is None:
            raise ConnectionError("AFC 文件写入通信中断")
        return op == self.OP_STATUS

    def file_close(self, handle):
        handle_data = struct.pack("<Q", handle)
        self._send_packet(self.OP_FILE_CLOSE, handle_data)
        op, payload = self._recv_packet()
        return True

    def upload_file(self, local_path, remote_path, progress_callback=None):
        """Uploads a local file to the remote device path."""
        file_size = os.path.getsize(local_path)
        handle = self.file_open(remote_path, mode=3)
        if not handle:
            raise IOError(f"AFC 文件打开失败: 无法在手机建立写入句柄 ({remote_path})")
        
        chunk_size = 64 * 1024
        uploaded = 0
        with open(local_path, "rb") as f:
            while True:
                chunk = f.read(chunk_size)
                if not chunk:
                    break
                self.file_write(handle, chunk)
                uploaded += len(chunk)
                if progress_callback:
                    pct = uploaded / max(1, file_size)
                    progress_callback(pct, uploaded, file_size)
        
        self.file_close(handle)
        return True
