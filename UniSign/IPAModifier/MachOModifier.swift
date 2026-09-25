import Foundation

/// Pure Swift Mach-O manipulation utility for injecting and removing LC_LOAD_DYLIB
public class MachOModifier {
    
    public enum MachOError: LocalizedError {
        case fileNotFound
        case invalidMachOHeader
        case unsupportedArchitecture
        case insufficientHeaderPadding
        case dylibAlreadyInjected
        case dylibNotFound
        case writeFailed
        
        public var errorDescription: String? {
            switch self {
            case .fileNotFound: return "Mach-O binary file not found."
            case .invalidMachOHeader: return "Invalid Mach-O magic header."
            case .unsupportedArchitecture: return "Unsupported Mach-O architecture (requires 64-bit arm64)."
            case .insufficientHeaderPadding: return "Not enough header padding space to insert LC_LOAD_DYLIB command."
            case .dylibAlreadyInjected: return "Target dynamic library is already injected in Mach-O."
            case .dylibNotFound: return "Target dynamic library was not found in Mach-O load commands."
            case .writeFailed: return "Failed to write modified Mach-O binary to disk."
            }
        }
    }
    
    // Mach-O constants
    private static let MH_MAGIC_64: UInt32 = 0xfeedfacf
    private static let MH_CIGAM_64: UInt32 = 0xcffaedfe
    private static let FAT_MAGIC: UInt32 = 0xcafebabe
    private static let FAT_CIGAM: UInt32 = 0xbebafeca
    
    private static let LC_LOAD_DYLIB: UInt32 = 0x0c
    private static let LC_LOAD_WEAK_DYLIB: UInt32 = 0x80000018
    private static let LC_REQ_DYLD: UInt32 = 0x80000000
    
    /// Scans the Mach-O binary and returns a list of loaded dylib paths
    public static func listLoadedDylibs(binaryURL: URL) throws -> [String] {
        let data = try Data(contentsOf: binaryURL)
        return try listLoadedDylibs(from: data)
    }
    
    public static func listLoadedDylibs(from data: Data) throws -> [String] {
        var dylibs: [String] = []
        let slices = try parseSlices(data: data)
        
        for slice in slices {
            let offset = slice.offset
            guard slice.size > 32 else { continue }
            
            let magic = data.readUInt32(at: offset)
            guard magic == MH_MAGIC_64 else { continue }
            
            let ncmds = Int(data.readUInt32(at: offset + 16))
            var curOffset = offset + 32 // sizeof(mach_header_64)
            
            for _ in 0..<ncmds {
                guard curOffset + 8 <= offset + slice.size else { break }
                let cmd = data.readUInt32(at: curOffset)
                let cmdsize = Int(data.readUInt32(at: curOffset + 4))
                
                if cmd == LC_LOAD_DYLIB || cmd == LC_LOAD_WEAK_DYLIB {
                    let strOffset = Int(data.readUInt32(at: curOffset + 8))
                    if strOffset < cmdsize && curOffset + strOffset < data.count {
                        let pathStart = curOffset + strOffset
                        let pathMaxLen = cmdsize - strOffset
                        let pathData = data.subdata(in: pathStart..<(pathStart + pathMaxLen))
                        if let nullIndex = pathData.firstIndex(of: 0) {
                            if let str = String(data: pathData[..<nullIndex], encoding: .utf8) {
                                if !dylibs.contains(str) {
                                    dylibs.append(str)
                                }
                            }
                        }
                    }
                }
                curOffset += cmdsize
            }
        }
        return dylibs
    }
    
    /// Injects LC_LOAD_DYLIB command into the Mach-O binary for the given dylib path
    /// Example path: "@executable_path/Frameworks/MyTweak.dylib"
    public static func injectDylib(binaryURL: URL, dylibPath: String, weak: Bool = false) throws {
        var data = try Data(contentsOf: binaryURL)
        let slices = try parseSlices(data: data)
        
        for slice in slices {
            try injectDylibIntoSlice(data: &data, sliceOffset: slice.offset, sliceSize: slice.size, dylibPath: dylibPath, weak: weak)
        }
        
        try data.write(to: binaryURL, options: .atomic)
    }
    
    /// Removes an injected LC_LOAD_DYLIB command matching the given path
    public static func removeDylib(binaryURL: URL, dylibNameOrPath: String) throws {
        var data = try Data(contentsOf: binaryURL)
        let slices = try parseSlices(data: data)
        
        var removedAny = false
        for slice in slices {
            if try removeDylibFromSlice(data: &data, sliceOffset: slice.offset, sliceSize: slice.size, dylibNameOrPath: dylibNameOrPath) {
                removedAny = true
            }
        }
        
        if !removedAny {
            throw MachOError.dylibNotFound
        }
        
        try data.write(to: binaryURL, options: .atomic)
    }
    
    // MARK: - Private Parsing & Injection Helpers
    
    private struct MachOSlice {
        let offset: Int
        let size: Int
    }
    
    private static func parseSlices(data: Data) throws -> [MachOSlice] {
        guard data.count >= 8 else { throw MachOError.invalidMachOHeader }
        let magic = data.readUInt32(at: 0)
        
        if magic == MH_MAGIC_64 {
            return [MachOSlice(offset: 0, size: data.count)]
        } else if magic == FAT_MAGIC || magic == FAT_CIGAM {
            // Universal / Fat binary
            let isSwap = (magic == FAT_CIGAM)
            let nfat_arch = Int(isSwap ? data.readUInt32(at: 4).byteSwapped : data.readUInt32(at: 4))
            var slices: [MachOSlice] = []
            
            for i in 0..<nfat_arch {
                let archOffset = 8 + i * 20
                guard archOffset + 20 <= data.count else { break }
                let offset = Int(isSwap ? data.readUInt32(at: archOffset + 8).byteSwapped : data.readUInt32(at: archOffset + 8))
                let size = Int(isSwap ? data.readUInt32(at: archOffset + 12).byteSwapped : data.readUInt32(at: archOffset + 12))
                slices.append(MachOSlice(offset: offset, size: size))
            }
            return slices
        } else {
            throw MachOError.invalidMachOHeader
        }
    }
    
    private static func injectDylibIntoSlice(data: inout Data, sliceOffset: Int, sliceSize: Int, dylibPath: String, weak: Bool) throws {
        let magic = data.readUInt32(at: sliceOffset)
        guard magic == MH_MAGIC_64 else {
            throw MachOError.unsupportedArchitecture
        }
        
        let ncmdsOffset = sliceOffset + 16
        let sizeofcmdsOffset = sliceOffset + 20
        
        let ncmds = Int(data.readUInt32(at: ncmdsOffset))
        let sizeofcmds = Int(data.readUInt32(at: sizeofcmdsOffset))
        
        let headerSize = 32 // mach_header_64
        let endOfCommands = sliceOffset + headerSize + sizeofcmds
        
        // Check if already injected
        var curOffset = sliceOffset + headerSize
        for _ in 0..<ncmds {
            let cmd = data.readUInt32(at: curOffset)
            let cmdsize = Int(data.readUInt32(at: curOffset + 4))
            if cmd == LC_LOAD_DYLIB || cmd == LC_LOAD_WEAK_DYLIB {
                let strOffset = Int(data.readUInt32(at: curOffset + 8))
                let pathStart = curOffset + strOffset
                let pathLen = cmdsize - strOffset
                if pathStart + pathLen <= data.count {
                    let pathData = data.subdata(in: pathStart..<(pathStart + pathLen))
                    if let nullIdx = pathData.firstIndex(of: 0),
                       let existingPath = String(data: pathData[..<nullIdx], encoding: .utf8),
                       existingPath == dylibPath {
                        // Already exists, skip
                        return
                    }
                }
            }
            curOffset += cmdsize
        }
        
        // Build new LC_LOAD_DYLIB load command
        guard let pathBytes = dylibPath.data(using: .utf8) else { return }
        let dylibCmdStructSize = 24 // sizeof(struct dylib_command)
        let rawCmdSize = dylibCmdStructSize + pathBytes.count + 1
        // Align to 8 bytes (64-bit boundary)
        let alignedCmdSize = (rawCmdSize + 7) & ~7
        
        // Verify available padding before the first section
        guard endOfCommands + alignedCmdSize <= data.count else {
            throw MachOError.insufficientHeaderPadding
        }
        
        // Check if padding is actually zeroed
        for i in endOfCommands..<(endOfCommands + alignedCmdSize) {
            if data[i] != 0 {
                throw MachOError.insufficientHeaderPadding
            }
        }
        
        // Construct dylib_command buffer
        var newCmd = Data(count: alignedCmdSize)
        let cmdType: UInt32 = weak ? LC_LOAD_WEAK_DYLIB : LC_LOAD_DYLIB
        newCmd.writeUInt32(cmdType, at: 0)
        newCmd.writeUInt32(UInt32(alignedCmdSize), at: 4)
        newCmd.writeUInt32(UInt32(dylibCmdStructSize), at: 8) // name.offset
        newCmd.writeUInt32(2, at: 12) // timestamp
        newCmd.writeUInt32(0x00010000, at: 16) // current_version (1.0.0)
        newCmd.writeUInt32(0x00010000, at: 20) // compatibility_version (1.0.0)
        
        // Write path string
        newCmd.replaceSubrange(dylibCmdStructSize..<(dylibCmdStructSize + pathBytes.count), with: pathBytes)
        newCmd[dylibCmdStructSize + pathBytes.count] = 0 // null terminator
        
        // Append into Mach-O padding space
        data.replaceSubrange(endOfCommands..<(endOfCommands + alignedCmdSize), with: newCmd)
        
        // Update header ncmds and sizeofcmds
        data.writeUInt32(UInt32(ncmds + 1), at: ncmdsOffset)
        data.writeUInt32(UInt32(sizeofcmds + alignedCmdSize), at: sizeofcmdsOffset)
    }
    
    private static func removeDylibFromSlice(data: inout Data, sliceOffset: Int, sliceSize: Int, dylibNameOrPath: String) throws -> Bool {
        let magic = data.readUInt32(at: sliceOffset)
        guard magic == MH_MAGIC_64 else { return false }
        
        let ncmdsOffset = sliceOffset + 16
        let sizeofcmdsOffset = sliceOffset + 20
        
        let ncmds = Int(data.readUInt32(at: ncmdsOffset))
        let sizeofcmds = Int(data.readUInt32(at: sizeofcmdsOffset))
        let headerSize = 32
        
        var curOffset = sliceOffset + headerSize
        for _ in 0..<ncmds {
            let cmd = data.readUInt32(at: curOffset)
            let cmdsize = Int(data.readUInt32(at: curOffset + 4))
            
            if cmd == LC_LOAD_DYLIB || cmd == LC_LOAD_WEAK_DYLIB {
                let strOffset = Int(data.readUInt32(at: curOffset + 8))
                let pathStart = curOffset + strOffset
                let pathLen = cmdsize - strOffset
                if pathStart + pathLen <= data.count {
                    let pathData = data.subdata(in: pathStart..<(pathStart + pathLen))
                    if let nullIdx = pathData.firstIndex(of: 0),
                       let existingPath = String(data: pathData[..<nullIdx], encoding: .utf8) {
                        if existingPath.contains(dylibNameOrPath) {
                            // Found target dylib. Zero out the command or convert to LC_ID_DYLIB / no-op
                            // To safely keep offsets intact without breaking segments, zero out or replace cmd with 0x0
                            let zeroData = Data(count: cmdsize)
                            data.replaceSubrange(curOffset..<(curOffset + cmdsize), with: zeroData)
                            return true
                        }
                    }
                }
            }
            curOffset += cmdsize
        }
        return false
    }
}

// MARK: - Data Byte Helpers
private extension Data {
    func readUInt32(at offset: Int) -> UInt32 {
        return self.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: offset, as: UInt32.self)
        }
    }
    
    mutating func writeUInt32(_ value: UInt32, at offset: Int) {
        var v = value
        withUnsafeBytes(of: &v) { bytes in
            self.replaceSubrange(offset..<(offset + 4), with: bytes)
        }
    }
}
