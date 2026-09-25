import Foundation
import Compression
import zlib

/// Pure Swift streaming ZIP decompression and compression engine for iOS
/// Uses native iOS Compression & zlib without third-party dependencies
public class ZipEngine {
    
    public enum ZipError: LocalizedError {
        case fileNotFound
        case invalidZipArchive
        case compressionFailed
        case decompressionFailed
        case writeFailed
        
        public var errorDescription: String? {
            switch self {
            case .fileNotFound: return "ZIP/IPA 文件不存在"
            case .invalidZipArchive: return "无效的 ZIP/IPA 压缩包格式"
            case .compressionFailed: return "文件压缩失败"
            case .decompressionFailed: return "解压文件失败"
            case .writeFailed: return "写入解压文件失败"
            }
        }
    }
    
    // MARK: - Unzip (Decompression)
    
    /// Unzips a source ZIP/IPA to the destination directory
    public static func unzip(source: URL, destination: URL, progress: ((Double, String) -> Void)? = nil) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: source.path) else {
            throw ZipError.fileNotFound
        }
        
        let fileData = try Data(contentsOf: source, options: .mappedIfSafe)
        guard fileData.count >= 22 else {
            throw ZipError.invalidZipArchive
        }
        
        // Find End of Central Directory record (signature: 0x06054b50)
        let eocdSignature: UInt32 = 0x06054b50
        var eocdOffset = -1
        let maxSearch = min(fileData.count, 65557)
        let searchStart = fileData.count - maxSearch
        
        for i in stride(from: fileData.count - 22, through: searchStart, by: -1) {
            if fileData.readUInt32LE(at: i) == eocdSignature {
                eocdOffset = i
                break
            }
        }
        
        guard eocdOffset >= 0 else {
            throw ZipError.invalidZipArchive
        }
        
        let totalEntries = Int(fileData.readUInt16LE(at: eocdOffset + 10))
        let cdSize = Int(fileData.readUInt32LE(at: eocdOffset + 12))
        let cdOffset = Int(fileData.readUInt32LE(at: eocdOffset + 16))
        
        guard cdOffset + cdSize <= fileData.count else {
            throw ZipError.invalidZipArchive
        }
        
        var curCDOffset = cdOffset
        let centralHeaderSig: UInt32 = 0x02014b50
        
        for idx in 0..<totalEntries {
            guard curCDOffset + 46 <= fileData.count,
                  fileData.readUInt32LE(at: curCDOffset) == centralHeaderSig else {
                break
            }
            
            let method = fileData.readUInt16LE(at: curCDOffset + 10)
            let compressedSize = Int(fileData.readUInt32LE(at: curCDOffset + 20))
            let uncompressedSize = Int(fileData.readUInt32LE(at: curCDOffset + 24))
            let nameLen = Int(fileData.readUInt16LE(at: curCDOffset + 28))
            let extraLen = Int(fileData.readUInt16LE(at: curCDOffset + 30))
            let commentLen = Int(fileData.readUInt16LE(at: curCDOffset + 32))
            let localHeaderOffset = Int(fileData.readUInt32LE(at: curCDOffset + 42))
            
            let nameStart = curCDOffset + 46
            guard nameStart + nameLen <= fileData.count else { break }
            let nameData = fileData.subdata(in: nameStart..<(nameStart + nameLen))
            let fileName = String(data: nameData, encoding: .utf8) ?? String(data: nameData, encoding: .ascii) ?? "file_\(idx)"
            
            // Advance CD pointer
            curCDOffset += 46 + nameLen + extraLen + commentLen
            
            // Read Local File Header (0x04034b50)
            guard localHeaderOffset + 30 <= fileData.count,
                  fileData.readUInt32LE(at: localHeaderOffset) == 0x04034b50 else {
                continue
            }
            
            let localNameLen = Int(fileData.readUInt16LE(at: localHeaderOffset + 26))
            let localExtraLen = Int(fileData.readUInt16LE(at: localHeaderOffset + 28))
            let dataOffset = localHeaderOffset + 30 + localNameLen + localExtraLen
            
            guard dataOffset + compressedSize <= fileData.count else { continue }
            let rawData = fileData.subdata(in: dataOffset..<(dataOffset + compressedSize))
            
            let destURL = destination.appendingPathComponent(fileName)
            if fileName.hasSuffix("/") {
                try? fm.createDirectory(at: destURL, withIntermediateDirectories: true, attributes: nil)
            } else {
                try? fm.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                
                let extractedData: Data
                if method == 0 {
                    // Stored (no compression)
                    extractedData = rawData
                } else if method == 8 {
                    // Deflate decompression
                    if let decompressed = inflateData(rawData, uncompressedSize: uncompressedSize) {
                        extractedData = decompressed
                    } else {
                        extractedData = rawData
                    }
                } else {
                    extractedData = rawData
                }
                
                try extractedData.write(to: destURL, options: .atomic)
            }
            
            if idx % 20 == 0 {
                let pct = Double(idx) / Double(max(1, totalEntries))
                progress?(pct, "正在解压: \(fileName.components(separatedBy: "/").last ?? fileName)")
            }
        }
    }
    
    /// Fast extraction of Info.plist dictionary directly from an IPA file without unpacking the whole archive
    public static func readInfoPlist(from sourceIPA: URL) -> [String: Any]? {
        guard let fileData = try? Data(contentsOf: sourceIPA, options: .mappedIfSafe), fileData.count >= 22 else {
            return nil
        }
        
        let eocdSignature: UInt32 = 0x06054b50
        var eocdOffset = -1
        let maxSearch = min(fileData.count, 65557)
        let searchStart = fileData.count - maxSearch
        
        for i in stride(from: fileData.count - 22, through: searchStart, by: -1) {
            if fileData.readUInt32LE(at: i) == eocdSignature {
                eocdOffset = i
                break
            }
        }
        guard eocdOffset >= 0 else { return nil }
        
        let totalEntries = Int(fileData.readUInt16LE(at: eocdOffset + 10))
        let cdSize = Int(fileData.readUInt32LE(at: eocdOffset + 12))
        let cdOffset = Int(fileData.readUInt32LE(at: eocdOffset + 16))
        guard cdOffset + cdSize <= fileData.count else { return nil }
        
        var curCDOffset = cdOffset
        let centralHeaderSig: UInt32 = 0x02014b50
        
        for _ in 0..<totalEntries {
            guard curCDOffset + 46 <= fileData.count,
                  fileData.readUInt32LE(at: curCDOffset) == centralHeaderSig else {
                break
            }
            
            let method = fileData.readUInt16LE(at: curCDOffset + 10)
            let compressedSize = Int(fileData.readUInt32LE(at: curCDOffset + 20))
            let uncompressedSize = Int(fileData.readUInt32LE(at: curCDOffset + 24))
            let nameLen = Int(fileData.readUInt16LE(at: curCDOffset + 28))
            let extraLen = Int(fileData.readUInt16LE(at: curCDOffset + 30))
            let commentLen = Int(fileData.readUInt16LE(at: curCDOffset + 32))
            let localHeaderOffset = Int(fileData.readUInt32LE(at: curCDOffset + 42))
            
            let nameStart = curCDOffset + 46
            guard nameStart + nameLen <= fileData.count else { break }
            let nameData = fileData.subdata(in: nameStart..<(nameStart + nameLen))
            let fileName = String(data: nameData, encoding: .utf8) ?? ""
            
            curCDOffset += 46 + nameLen + extraLen + commentLen
            
            // Look for Payload/xxx.app/Info.plist
            if fileName.hasPrefix("Payload/") && fileName.hasSuffix(".app/Info.plist") {
                guard localHeaderOffset + 30 <= fileData.count,
                      fileData.readUInt32LE(at: localHeaderOffset) == 0x04034b50 else {
                    continue
                }
                
                let localNameLen = Int(fileData.readUInt16LE(at: localHeaderOffset + 26))
                let localExtraLen = Int(fileData.readUInt16LE(at: localHeaderOffset + 28))
                let dataOffset = localHeaderOffset + 30 + localNameLen + localExtraLen
                
                guard dataOffset + compressedSize <= fileData.count else { continue }
                let rawData = fileData.subdata(in: dataOffset..<(dataOffset + compressedSize))
                
                let plistData: Data?
                if method == 0 {
                    plistData = rawData
                } else if method == 8 {
                    plistData = inflateData(rawData, uncompressedSize: uncompressedSize)
                } else {
                    plistData = rawData
                }
                
                if let pData = plistData,
                   let plist = try? PropertyListSerialization.propertyList(from: pData, options: [], format: nil) as? [String: Any] {
                    return plist
                }
            }
        }
        return nil
    }
    
    // MARK: - Zip (Compression)
    
    /// Compresses a directory into a standard .ipa / .zip archive
    public static func zip(sourceDir: URL, destinationIPA: URL, progress: ((Double, String) -> Void)? = nil) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: sourceDir.path) else {
            throw ZipError.fileNotFound
        }
        
        if fm.fileExists(atPath: destinationIPA.path) {
            try? fm.removeItem(at: destinationIPA)
        }
        
        guard let enumerator = fm.enumerator(at: sourceDir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            throw ZipError.writeFailed
        }
        
        var filesToZip: [(relative: String, fullURL: URL, isDir: Bool)] = []
        let basePrefix = sourceDir.path.hasSuffix("/") ? sourceDir.path : sourceDir.path + "/"
        
        for case let url as URL in enumerator {
            let path = url.path
            guard path.hasPrefix(basePrefix) else { continue }
            let rel = String(path.dropFirst(basePrefix.count))
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            filesToZip.append((relative: isDir ? rel + "/" : rel, fullURL: url, isDir: isDir))
        }
        
        var zipOutput = Data()
        var centralDirectory = Data()
        var centralDirEntries = 0
        
        for (i, entry) in filesToZip.enumerated() {
            let localHeaderOffset = UInt32(zipOutput.count)
            guard let nameBytes = entry.relative.data(using: .utf8) else { continue }
            
            let fileData = entry.isDir ? Data() : (try? Data(contentsOf: entry.fullURL)) ?? Data()
            let crc = entry.isDir ? 0 : calculateCRC32(fileData)
            let uncompressedSize = UInt32(fileData.count)
            
            // Deflate compression
            let (compressedData, method): (Data, UInt16)
            if entry.isDir || fileData.count == 0 {
                compressedData = Data()
                method = 0
            } else if let deflated = deflateData(fileData), deflated.count < fileData.count {
                compressedData = deflated
                method = 8
            } else {
                compressedData = fileData
                method = 0
            }
            let compressedSize = UInt32(compressedData.count)
            
            // 1. Write Local File Header (0x04034b50)
            zipOutput.appendUInt32LE(0x04034b50)
            zipOutput.appendUInt16LE(20) // version needed
            zipOutput.appendUInt16LE(0)  // flags
            zipOutput.appendUInt16LE(method)
            zipOutput.appendUInt16LE(0)  // mod time
            zipOutput.appendUInt16LE(0)  // mod date
            zipOutput.appendUInt32LE(crc)
            zipOutput.appendUInt32LE(compressedSize)
            zipOutput.appendUInt32LE(uncompressedSize)
            zipOutput.appendUInt16LE(UInt16(nameBytes.count))
            zipOutput.appendUInt16LE(0)  // extra len
            zipOutput.append(nameBytes)
            zipOutput.append(compressedData)
            
            // 2. Append Central Directory Record (0x02014b50)
            centralDirectory.appendUInt32LE(0x02014b50)
            centralDirectory.appendUInt16LE(20) // made by
            centralDirectory.appendUInt16LE(20) // version needed
            centralDirectory.appendUInt16LE(0)  // flags
            centralDirectory.appendUInt16LE(method)
            centralDirectory.appendUInt16LE(0)  // mod time
            centralDirectory.appendUInt16LE(0)  // mod date
            centralDirectory.appendUInt32LE(crc)
            centralDirectory.appendUInt32LE(compressedSize)
            centralDirectory.appendUInt32LE(uncompressedSize)
            centralDirectory.appendUInt16LE(UInt16(nameBytes.count))
            centralDirectory.appendUInt16LE(0)  // extra len
            centralDirectory.appendUInt16LE(0)  // comment len
            centralDirectory.appendUInt16LE(0)  // disk start
            centralDirectory.appendUInt16LE(0)  // internal attrs
            centralDirectory.appendUInt32LE(entry.isDir ? 0x10 : 0) // external attrs
            centralDirectory.appendUInt32LE(localHeaderOffset)
            centralDirectory.append(nameBytes)
            centralDirEntries += 1
            
            if i % 20 == 0 {
                let pct = Double(i) / Double(max(1, filesToZip.count))
                progress?(pct, "正在压缩: \(entry.relative.components(separatedBy: "/").last ?? "")")
            }
        }
        
        let cdOffset = UInt32(zipOutput.count)
        let cdSize = UInt32(centralDirectory.count)
        zipOutput.append(centralDirectory)
        
        // 3. Write End of Central Directory Record (0x06054b50)
        zipOutput.appendUInt32LE(0x06054b50)
        zipOutput.appendUInt16LE(0) // disk number
        zipOutput.appendUInt16LE(0) // disk where CD starts
        zipOutput.appendUInt16LE(UInt16(centralDirEntries))
        zipOutput.appendUInt16LE(UInt16(centralDirEntries))
        zipOutput.appendUInt32LE(cdSize)
        zipOutput.appendUInt32LE(cdOffset)
        zipOutput.appendUInt16LE(0) // comment len
        
        try zipOutput.write(to: destinationIPA, options: .atomic)
    }
    
    // MARK: - Native Compression Helpers
    
    private static func inflateData(_ data: Data, uncompressedSize: Int) -> Data? {
        guard uncompressedSize > 0 else { return Data() }
        var dest = Data(count: uncompressedSize)
        let sourceCount = data.count
        let decodedSize = dest.withUnsafeMutableBytes { (destPtr: UnsafeMutableRawBufferPointer) -> Int in
            guard let dstBase = destPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
            return data.withUnsafeBytes { (srcPtr: UnsafeRawBufferPointer) -> Int in
                guard let srcBase = srcPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                return compression_decode_buffer(
                    dstBase,
                    uncompressedSize,
                    srcBase,
                    sourceCount,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        if decodedSize > 0 {
            dest.count = decodedSize
            return dest
        }
        return nil
    }
    
    private static func deflateData(_ data: Data) -> Data? {
        guard !data.isEmpty else { return Data() }
        let destCapacity = data.count + 512
        var dest = Data(count: destCapacity)
        let sourceCount = data.count
        let encodedSize = dest.withUnsafeMutableBytes { (destPtr: UnsafeMutableRawBufferPointer) -> Int in
            guard let dstBase = destPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
            return data.withUnsafeBytes { (srcPtr: UnsafeRawBufferPointer) -> Int in
                guard let srcBase = srcPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                return compression_encode_buffer(
                    dstBase,
                    destCapacity,
                    srcBase,
                    sourceCount,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        if encodedSize > 0 {
            dest.count = encodedSize
            return dest
        }
        return nil
    }
    
    private static func calculateCRC32(_ data: Data) -> UInt32 {
        var crc: uLong = crc32(0, nil, 0)
        let count = uInt(data.count)
        data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            if let base = ptr.baseAddress?.assumingMemoryBound(to: Bytef.self) {
                crc = crc32(crc, base, count)
            }
        }
        return UInt32(crc)
    }
}

// MARK: - Data Little-Endian Extensions
private extension Data {
    func readUInt16LE(at offset: Int) -> UInt16 {
        guard offset + 2 <= self.count else { return 0 }
        return UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }
    
    func readUInt32LE(at offset: Int) -> UInt32 {
        guard offset + 4 <= self.count else { return 0 }
        let b0 = UInt32(self[offset])
        let b1 = UInt32(self[offset + 1]) << 8
        let b2 = UInt32(self[offset + 2]) << 16
        let b3 = UInt32(self[offset + 3]) << 24
        return b0 | b1 | b2 | b3
    }
    
    mutating func appendUInt16LE(_ val: UInt16) {
        append(UInt8(val & 0xFF))
        append(UInt8((val >> 8) & 0xFF))
    }
    
    mutating func appendUInt32LE(_ val: UInt32) {
        append(UInt8(val & 0xFF))
        append(UInt8((val >> 8) & 0xFF))
        append(UInt8((val >> 16) & 0xFF))
        append(UInt8((val >> 24) & 0xFF))
    }
}
