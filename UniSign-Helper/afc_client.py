import struct
import os

class AFCClient:
    """Lightweight Apple File Conduit (AFC) client for staging files onto the iOS device."""
    
    MAGIC = b"CFA6LPAA"
    
    # Operations
    OP_STATUS = 1
    OP_FILE_CLOSE = 2
    OP_FILE_WRITE = 3
    OP_GET_FILE_INFO = 10
    OP_FILE_OPEN = 13
    OP_MAKE_DIR = 9
    
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
        if not hdr:
            return None, b""
        magic, entire_len, this_len, pkt_num, op = struct.unpack("<8sQQQQ", hdr)
        payload_len = entire_len - this_len
        payload = self._read_exact(payload_len) if payload_len > 0 else b""
        return op, payload

    def _read_exact(self, count):
        buf = bytearray()
        while len(buf) < count:
            chunk = self.sock.recv(count - len(buf))
            if not chunk:
                break
            buf.extend(chunk)
        return bytes(buf)

    def make_directory(self, path):
        data = path.encode("utf-8") + b"\x00"
        self._send_packet(self.OP_MAKE_DIR, data)
        op, payload = self._recv_packet()
        return True

    def file_open(self, path, mode=3):
        """mode 3 = read/write create/truncate"""
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
        handle_data = struct.pack("<Q", handle)
        self._send_packet(self.OP_FILE_WRITE, handle_data + data)
        op, payload = self._recv_packet()
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
            raise IOError(f"Failed to open remote path {remote_path} for writing on iOS device")
        
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
