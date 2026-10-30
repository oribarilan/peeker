import Foundation

enum LineEnding: String, Sendable {
    case lf = "LF", crlf = "CRLF", cr = "CR"

    fileprivate var bytes: [UInt8] {
        switch self {
        case .lf: [0x0A]
        case .crlf: [0x0D, 0x0A]
        case .cr: [0x0D]
        }
    }
}

/// How a file's text was stored, so a save can write it back the same way.
struct TextFormat: Equatable, Sendable {
    let encoding: String.Encoding
    let hasBOM: Bool
    let lineEnding: LineEnding
}

enum TextLimits {
    /// Larger files open read-only.
    static let editableBytes = 10 * 1_048_576
    /// Larger texts show only their first part, which keeps the app's memory near 100 MB for a 90 MB log and
    /// find and scrolling exact.
    static let displayBytes = 16 * 1_048_576
    /// TextKit lays out a line in one piece: re-wrapping a 16 MB single line held the app for about 3 s. Texts with a
    /// line longer than `longLineBytes` show only their first `longLineDisplayBytes`.
    static let longLineBytes = 1_048_576
    static let longLineDisplayBytes = 4 * 1_048_576
}

enum TextCodec {
    static let notText = PluginFailure("This doesn't look like a text file.", code: .notText)

    private static let utf8BOM: [UInt8] = [0xEF, 0xBB, 0xBF]
    private static let utf16LEBOM: [UInt8] = [0xFF, 0xFE]
    private static let utf16BEBOM: [UInt8] = [0xFE, 0xFF]

    static func decode(_ data: Data) throws(PluginFailure) -> (text: String, format: TextFormat) {
        let (text, encoding, hasBOM) = try decodeText(data)
        return (text, TextFormat(encoding: encoding, hasBOM: hasBOM, lineEnding: breaks(in: text).dominant))
    }

    /// Writes every line break as the format's ending. Throws `.cannotEncode` rather than substituting characters.
    static func encode(_ text: String, as format: TextFormat) throws(PluginFailure) -> Data {
        let normalized = normalizingBreaks(text, to: format.lineEnding)
        var data = Data()
        if format.hasBOM { data.append(contentsOf: bom(for: format.encoding)) }
        if format.encoding == .utf8 {
            data.append(contentsOf: normalized)
        } else {
            guard let encoded = String(decoding: normalized, as: UTF8.self).data(using: format.encoding, allowLossyConversion: false) else {
                throw PluginFailure("Some characters can't be represented in \(String.localizedName(of: format.encoding)).", code: .cannotEncode)
            }
            data.append(encoded)
        }
        return data
    }

    /// Lines as a reader counts them: a final line without a break still counts, an empty text has none.
    static func lineCount(of text: String) -> Int {
        let counts = breaks(in: text)
        return counts.crlf + counts.lf + counts.cr + (counts.endsWithBreak || text.isEmpty ? 0 : 1)
    }

    private static func decodeText(_ data: Data) throws(PluginFailure) -> (String, String.Encoding, hasBOM: Bool) {
        if data.starts(with: utf8BOM) {
            guard let text = String(validating: data.dropFirst(utf8BOM.count), as: UTF8.self) else { throw notText }
            return (text, .utf8, true)
        }
        for (bom, encoding) in [(utf16LEBOM, String.Encoding.utf16LittleEndian), (utf16BEBOM, .utf16BigEndian)] where data.starts(with: bom) {
            guard let text = exactText(data.dropFirst(bom.count), encoding) else { throw notText }
            return (text, encoding, true)
        }
        // memchr, not `Data.contains`, which goes byte by byte through the iterator: 200 ms on 90 MB.
        if data.withUnsafeBytes({ $0.count > 0 && memchr($0.baseAddress, 0, $0.count) != nil }) { throw notText }
        if let text = String(validating: data, as: UTF8.self) { return (text, .utf8, false) }
        let legacy: [String.Encoding] = [.windowsCP1252, .macOSRoman]
        var converted: NSString?
        let detected = String.Encoding(rawValue: NSString.stringEncoding(for: data, encodingOptions: [.suggestedEncodingsKey: legacy.map(\.rawValue),
                                                                                                    .useOnlySuggestedEncodingsKey: true, .allowLossyKey: false],
                                                                         convertedString: &converted, usedLossyConversion: nil))
        // Foundation can name Windows-1252 for bytes it leaves undefined (0x81, say), so its pick is only tried first.
        for encoding in [detected] + legacy where legacy.contains(encoding) {
            if let text = exactText(data, encoding) { return (text, encoding, false) }
        }
        throw notText
    }

    /// The text, if it encodes back to the same bytes, so an unedited save can't change the file.
    private static func exactText(_ data: Data, _ encoding: String.Encoding) -> String? {
        guard let text = String(data: data, encoding: encoding), text.data(using: encoding, allowLossyConversion: false) == data else { return nil }
        return text
    }

    private static func bom(for encoding: String.Encoding) -> [UInt8] {
        switch encoding {
        case .utf16LittleEndian: utf16LEBOM
        case .utf16BigEndian: utf16BEBOM
        default: utf8BOM
        }
    }

    private struct BreakCounts {
        var crlf = 0, lf = 0, cr = 0
        var endsWithBreak = false

        /// The most frequent ending; LF on a tie or when there are no breaks.
        var dominant: LineEnding {
            if crlf > lf && crlf > cr { return .crlf }
            if cr > lf && cr > crlf { return .cr }
            return .lf
        }
    }

    /// Counts every LF and CR in one branch-free pass the compiler vectorizes, then finds CRLF pairs by jumping
    /// between CRs, so a 90 MB log takes about 25 ms rather than 80.
    private static func breaks(in text: String) -> BreakCounts {
        var text = text  // `withUTF8` is mutating; a native string is used in place, a bridged one (legacy encodings) is copied
        return text.withUTF8 { bytes in
            var lf = 0, cr = 0
            for byte in bytes {
                lf &+= byte == 0x0A ? 1 : 0
                cr &+= byte == 0x0D ? 1 : 0
            }
            var crlf = 0
            if cr > 0, let base = bytes.baseAddress {
                let end = base + bytes.count
                var position = base
                while position < end, let found = memchr(position, 0x0D, end - position) {
                    let next = UnsafePointer(found.assumingMemoryBound(to: UInt8.self)) + 1
                    if next < end && next.pointee == 0x0A { crlf += 1 }
                    position = next
                }
            }
            var counts = BreakCounts(crlf: crlf, lf: lf - crlf, cr: cr - crlf)
            counts.endsWithBreak = bytes.last.map { $0 == 0x0A || $0 == 0x0D } ?? false
            return counts
        }
    }

    private static func normalizingBreaks(_ text: String, to ending: LineEnding) -> [UInt8] {
        var output: [UInt8] = []
        output.reserveCapacity(text.utf8.count)
        var previousCR = false
        for byte in text.utf8 {
            switch byte {
            case 0x0A where previousCR: break  // the CR already wrote the ending
            case 0x0A, 0x0D: output.append(contentsOf: ending.bytes)
            default: output.append(byte)
            }
            previousCR = byte == 0x0D
        }
        return output
    }
}
