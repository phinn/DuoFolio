import Foundation
import Compression

/// 零依赖 zip 读取器:只实现读 EPUB 需要的最小集 ——
/// central directory 遍历 + stored/deflate 解压 + 按文件名取数据。
/// 全部内存内完成,EPUB 通常 < 20MB,无需落盘中间产物。
enum MiniZip {

    struct Entry {
        let name: String
        let offset: UInt64   // local header 起始
        let compressedSize: UInt64
        let uncompressedSize: UInt64
        let method: UInt16   // 0 stored, 8 deflate
        let crc32: UInt32
    }

    struct Archive {
        let data: Data
        let entries: [String: Entry]

        func read(_ name: String) -> Data? {
            guard let e = entries[name] ?? entries[normalize(name)] else { return nil }
            return MiniZip.inflate(data: data, entry: e)
        }

        /// 目录前缀归一(有的 epub 内部路径带 "OEBPS/" 前缀差异)
        private func normalize(_ name: String) -> String {
            // 尝试用小写匹配
            let lower = name.lowercased()
            for k in entries.keys where k.lowercased() == lower { return k }
            return name
        }
    }

    enum ZipError: Error {
        case notZip, noCentralDirectory, corrupt(String)
    }

    static func open(data: Data) throws -> Archive {
        guard data.count > 22 else { throw ZipError.notZip }
        // 1. 定位 EOCD(从尾部找 0x06054b50,允许最多 64KB 注释)
        var eocdOffset = -1
        let scanStart = max(0, data.count - 66_000)
        var i = data.count - 22
        while i >= scanStart {
            if data[data.startIndex + i] == 0x50, data[data.startIndex + i + 1] == 0x4b,
               data[data.startIndex + i + 2] == 0x05, data[data.startIndex + i + 3] == 0x06 {
                eocdOffset = i
                break
            }
            i -= 1
        }
        guard eocdOffset >= 0 else { throw ZipError.noCentralDirectory }
        let base = data.startIndex

        let cdCount = Int(readLE16(data, base + eocdOffset + 10))
        var cdSize = Int(readLE32(data, base + eocdOffset + 12))
        var cdOffset = Int(readLE32(data, base + eocdOffset + 16))

        // 2. ZIP64 EOCD locator(EPUB 可能超 4G?不会。但防御性处理 locator 存在时)
        if cdOffset == 0xFFFF_FFFF || cdSize == 0xFFFF_FFFF || cdCount == 0xFFFF {
            // 找 zip64 end of central directory locator (0x07064b50)
            var j = eocdOffset - 20
            if j >= 0,
               data[base + j] == 0x50, data[base + j + 1] == 0x4b,
               data[base + j + 2] == 0x06, data[base + j + 3] == 0x07 {
                let z64Offset = Int(readLE64(data, base + j + 8))
                // zip64 EOCD: sig(4) sizes(8) ver(2+2) disk(4+4) count(8+8) size(8) offset(8)
                let cnt = Int(readLE64(data, base + z64Offset + 32))
                cdSize = Int(readLE64(data, base + z64Offset + 40))
                cdOffset = Int(readLE64(data, base + z64Offset + 48))
                _ = cnt
            }
        }

        // 3. 遍历 central directory entries
        var entries: [String: Entry] = [:]
        var p = cdOffset
        for _ in 0..<cdCount {
            guard p + 46 <= data.count,
                  readLE32(data, base + p) == 0x0201_4b50 else { break }
            let method = readLE16(data, base + p + 10)
            let crc = readLE32(data, base + p + 16)
            let cSize = UInt64(readLE32(data, base + p + 20))
            let uSize = UInt64(readLE32(data, base + p + 24))
            let nameLen = Int(readLE16(data, base + p + 28))
            let extraLen = Int(readLE16(data, base + p + 30))
            let commentLen = Int(readLE16(data, base + p + 32))
            let lho = UInt64(readLE32(data, base + p + 42))
            let nameData = data.subdata(in: (base + p + 46)..<(base + p + 46 + nameLen))
            let name = String(data: nameData, encoding: .utf8) ?? ""

            // ZIP64 extra field 处理(超大文件)
            var c = cSize, u = uSize, off = lho
            var ep = p + 46 + nameLen
            let extraEnd = ep + extraLen
            while ep + 4 <= extraEnd {
                let hid = readLE16(data, base + ep)
                let hsz = Int(readLE16(data, base + ep + 2))
                if hid == 0x0001 {
                    var q = ep + 4
                    if uSize == 0xFFFF_FFFF, q + 8 <= extraEnd { u = readLE64(data, base + q); q += 8 }
                    if cSize == 0xFFFF_FFFF, q + 8 <= extraEnd { c = readLE64(data, base + q); q += 8 }
                    if lho == 0xFFFF_FFFF, q + 8 <= extraEnd { off = readLE64(data, base + q); q += 8 }
                }
                ep += 4 + hsz
            }

            if !name.isEmpty {
                entries[name] = Entry(name: name, offset: off,
                                      compressedSize: c, uncompressedSize: u,
                                      method: method, crc32: crc)
            }
            p += 46 + nameLen + extraLen + commentLen
        }
        return Archive(data: data, entries: entries)
    }

    static func inflate(data: Data, entry: Entry) -> Data? {        // local header: sig(4) ver(2) flag(2) method(2) ... nameLen(2)@26 extraLen(2)@28
        let base = data.startIndex + Int(entry.offset)
        guard data.count > Int(entry.offset) + 30,
              readLE32(data, base) == 0x0403_4b50 else { return nil }
        let nameLen = Int(readLE16(data, base + 26))
        let extraLen = Int(readLE16(data, base + 28))
        let dataStart = base + 30 + nameLen + extraLen
        let dataEnd = dataStart + Int(entry.compressedSize)
        guard dataEnd <= data.count else { return nil }
        let raw = data.subdata(in: dataStart..<dataEnd)

        switch entry.method {
        case 0:
            return raw
        case 8:
            var stream = raw
            let dest = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(entry.uncompressedSize))
            defer { dest.deallocate() }
            var dstLen = Int(entry.uncompressedSize)
            let ok = stream.withUnsafeMutableBytes { (src: UnsafeMutableRawBufferPointer) -> Bool in
                let sp = UnsafeMutablePointer<UInt8>(mutating: src.baseAddress?.assumingMemoryBound(to: UInt8.self) ?? dest)
                let r = compression_decode_buffer(dest, dstLen, sp, raw.count,
                                                  nil, COMPRESSION_ZLIB)
                return r > 0
            }
            _ = ok
            if !ok { return nil }
            let out = Data(bytes: dest, count: dstLen)
            return out
        default:
            return nil
        }
    }

    private static func readLE16(_ d: Data, _ at: Int) -> UInt16 {
        UInt16(d[d.startIndex + at]) | (UInt16(d[d.startIndex + at + 1]) << 8)
    }
    private static func readLE32(_ d: Data, _ at: Int) -> UInt32 {
        UInt32(readLE16(d, at)) | (UInt32(readLE16(d, at + 2)) << 16)
    }
    private static func readLE64(_ d: Data, _ at: Int) -> UInt64 {
        UInt64(readLE32(d, at)) | (UInt64(readLE32(d, at + 4)) << 32)
    }
}
