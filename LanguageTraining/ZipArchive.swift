import Foundation
import zlib

enum ZipArchiveError: LocalizedError {
    case invalidArchive
    case unsupportedCompression
    case failedToCompress
    case failedToDecompress

    var errorDescription: String? {
        switch self {
        case .invalidArchive:
            return "The archive file is invalid."
        case .unsupportedCompression:
            return "The archive uses an unsupported compression method."
        case .failedToCompress:
            return "Failed to create the ZIP archive."
        case .failedToDecompress:
            return "Failed to extract the ZIP archive."
        }
    }
}

enum ZipArchive {
    static func zipDirectory(_ directory: URL, rootName: String) throws -> Data {
        var entries: [(name: String, data: Data)] = []
        try collectFiles(from: directory, relativePath: rootName, into: &entries)
        return try zipEntries(entries)
    }

    static func unzip(_ data: Data, to destination: URL) throws {
        let entries = try unzipEntries(data)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        for entry in entries {
            let url = destination.appendingPathComponent(entry.name)
            if entry.name.hasSuffix("/") {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                continue
            }
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try entry.data.write(to: url, options: [.atomic])
        }
    }

    private static func collectFiles(from directory: URL, relativePath: String, into entries: inout [(name: String, data: Data)]) throws {
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        for item in contents {
            let name = relativePath + "/" + item.lastPathComponent
            let values = try item.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == true {
                try collectFiles(from: item, relativePath: name, into: &entries)
            } else {
                entries.append((name, try Data(contentsOf: item)))
            }
        }
    }

    private static func zipEntries(_ entries: [(name: String, data: Data)]) throws -> Data {
        var localFiles = Data()
        var centralDirectory = Data()
        var offset: UInt32 = 0

        for entry in entries {
            let nameData = Data(entry.name.utf8)
            let crc = CRC32.hash(entry.data)
            let payload = entry.data
            let method: UInt16 = 0

            var localHeader = Data()
            localHeader.append(contentsOf: UInt32(0x04034b50).littleEndianBytes)
            localHeader.append(contentsOf: UInt16(20).littleEndianBytes)
            localHeader.append(contentsOf: UInt16(0).littleEndianBytes)
            localHeader.append(contentsOf: method.littleEndianBytes)
            localHeader.append(contentsOf: UInt16(0).littleEndianBytes)
            localHeader.append(contentsOf: UInt16(0).littleEndianBytes)
            localHeader.append(contentsOf: crc.littleEndianBytes)
            localHeader.append(contentsOf: UInt32(payload.count).littleEndianBytes)
            localHeader.append(contentsOf: UInt32(entry.data.count).littleEndianBytes)
            localHeader.append(contentsOf: UInt16(nameData.count).littleEndianBytes)
            localHeader.append(contentsOf: UInt16(0).littleEndianBytes)
            localHeader.append(nameData)
            localHeader.append(payload)

            var central = Data()
            central.append(contentsOf: UInt32(0x02014b50).littleEndianBytes)
            central.append(contentsOf: UInt16(20).littleEndianBytes)
            central.append(contentsOf: UInt16(20).littleEndianBytes)
            central.append(contentsOf: UInt16(0).littleEndianBytes)
            central.append(contentsOf: method.littleEndianBytes)
            central.append(contentsOf: UInt16(0).littleEndianBytes)
            central.append(contentsOf: UInt16(0).littleEndianBytes)
            central.append(contentsOf: crc.littleEndianBytes)
            central.append(contentsOf: UInt32(payload.count).littleEndianBytes)
            central.append(contentsOf: UInt32(entry.data.count).littleEndianBytes)
            central.append(contentsOf: UInt16(nameData.count).littleEndianBytes)
            central.append(contentsOf: UInt16(0).littleEndianBytes)
            central.append(contentsOf: UInt16(0).littleEndianBytes)
            central.append(contentsOf: UInt16(0).littleEndianBytes)
            central.append(contentsOf: UInt16(0).littleEndianBytes)
            central.append(contentsOf: UInt32(0).littleEndianBytes)
            central.append(contentsOf: offset.littleEndianBytes)
            central.append(nameData)

            offset += UInt32(localHeader.count)
            localFiles.append(localHeader)
            centralDirectory.append(central)
        }

        var end = Data()
        end.append(contentsOf: UInt32(0x06054b50).littleEndianBytes)
        end.append(contentsOf: UInt16(0).littleEndianBytes)
        end.append(contentsOf: UInt16(0).littleEndianBytes)
        end.append(contentsOf: UInt16(entries.count).littleEndianBytes)
        end.append(contentsOf: UInt16(entries.count).littleEndianBytes)
        end.append(contentsOf: UInt32(centralDirectory.count).littleEndianBytes)
        end.append(contentsOf: UInt32(localFiles.count).littleEndianBytes)
        end.append(contentsOf: UInt16(0).littleEndianBytes)

        var zip = Data()
        zip.append(localFiles)
        zip.append(centralDirectory)
        zip.append(end)
        return zip
    }

    private static func unzipEntries(_ data: Data) throws -> [(name: String, data: Data)] {
        guard let eocd = data.range(of: Data([0x50, 0x4b, 0x05, 0x06]), options: .backwards) else {
            throw ZipArchiveError.invalidArchive
        }
        let eocdStart = eocd.lowerBound
        guard data.count >= eocdStart + 22 else { throw ZipArchiveError.invalidArchive }
        let entryCount = Int(data.uInt16(at: eocdStart + 10))
        let centralSize = Int(data.uInt32(at: eocdStart + 12))
        let centralOffset = Int(data.uInt32(at: eocdStart + 16))
        guard centralOffset + centralSize <= data.count else { throw ZipArchiveError.invalidArchive }

        var entries: [(name: String, data: Data)] = []
        var cursor = centralOffset
        for _ in 0..<entryCount {
            guard data.uInt32(at: cursor) == 0x02014b50 else { throw ZipArchiveError.invalidArchive }
            let method = data.uInt16(at: cursor + 10)
            let compressedSize = Int(data.uInt32(at: cursor + 20))
            let uncompressedSize = Int(data.uInt32(at: cursor + 24))
            let nameLength = Int(data.uInt16(at: cursor + 28))
            let extraLength = Int(data.uInt16(at: cursor + 30))
            let commentLength = Int(data.uInt16(at: cursor + 32))
            let localOffset = Int(data.uInt32(at: cursor + 42))
            let nameStart = cursor + 46
            let nameData = data.subdata(in: nameStart..<(nameStart + nameLength))
            guard let name = String(data: nameData, encoding: .utf8) else { throw ZipArchiveError.invalidArchive }

            let localNameLength = Int(data.uInt16(at: localOffset + 26))
            let localExtraLength = Int(data.uInt16(at: localOffset + 28))
            let dataStart = localOffset + 30 + localNameLength + localExtraLength
            let compressed = data.subdata(in: dataStart..<(dataStart + compressedSize))
            let fileData: Data
            if name.hasSuffix("/") || uncompressedSize == 0 {
                fileData = Data()
            } else if method == 0 {
                fileData = compressed
            } else if method == 8 {
                fileData = try inflateRaw(compressed, uncompressedSize: uncompressedSize)
            } else {
                throw ZipArchiveError.unsupportedCompression
            }
            entries.append((name, fileData))
            cursor = nameStart + nameLength + extraLength + commentLength
        }
        return entries
    }

    private static func inflateRaw(_ data: Data, uncompressedSize: Int) throws -> Data {
        guard !data.isEmpty else { return Data() }

        var stream = z_stream()
        let initStatus = data.withUnsafeBytes { buffer -> Int32 in
            guard let bytes = buffer.bindMemory(to: Bytef.self).baseAddress else { return Z_ERRNO }
            stream.next_in = UnsafeMutablePointer(mutating: bytes)
            stream.avail_in = uInt(buffer.count)
            return inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        }
        guard initStatus == Z_OK else { throw ZipArchiveError.failedToDecompress }
        defer { inflateEnd(&stream) }

        var output = Data(count: max(uncompressedSize, data.count * 4))
        let status = output.withUnsafeMutableBytes { buffer -> Int32 in
            guard let bytes = buffer.bindMemory(to: Bytef.self).baseAddress else { return Z_ERRNO }
            stream.next_out = bytes
            stream.avail_out = uInt(buffer.count)
            return zlib.inflate(&stream, Z_FINISH)
        }
        guard status == Z_STREAM_END || status == Z_OK else { throw ZipArchiveError.failedToDecompress }
        output.removeSubrange(Int(stream.total_out)..<output.count)
        return output
    }
}

private enum CRC32 {
    private static let table: [UInt32] = {
        (0..<256).map { index -> UInt32 in
            var crc = UInt32(index)
            for _ in 0..<8 {
                crc = (crc & 1) == 1 ? (0xEDB88320 ^ (crc >> 1)) : (crc >> 1)
            }
            return crc
        }
    }()

    static func hash(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFFFFFF
    }
}

private extension FixedWidthInteger {
    var littleEndianBytes: [UInt8] {
        withUnsafeBytes(of: littleEndian, Array.init)
    }
}

private extension Data {
    func uInt16(at offset: Int) -> UInt16 {
        UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }

    func uInt32(at offset: Int) -> UInt32 {
        UInt32(self[offset])
            | (UInt32(self[offset + 1]) << 8)
            | (UInt32(self[offset + 2]) << 16)
            | (UInt32(self[offset + 3]) << 24)
    }
}
