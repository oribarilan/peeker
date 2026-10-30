import Foundation
import PeekerKit
@testable import PeekerText
import Testing

@Suite struct TextCodecTests {
    @Test func detectsEncodingsAndBOMs() throws {
        #expect(try TextCodec.decode(Data("héllo\n".utf8)).format == TextFormat(encoding: .utf8, hasBOM: false, lineEnding: .lf))
        #expect(try TextCodec.decode(Data([0xEF, 0xBB, 0xBF]) + Data("a\r\nb\r\n".utf8)).format == TextFormat(encoding: .utf8, hasBOM: true, lineEnding: .crlf))
        #expect(try TextCodec.decode(Data([0xFF, 0xFE, 0x61, 0x00])).format.encoding == .utf16LittleEndian)
        #expect(try TextCodec.decode(Data([0xFE, 0xFF, 0x00, 0x61])).format.encoding == .utf16BigEndian)
        #expect(try TextCodec.decode(Data([0x63, 0x61, 0x66, 0xE9])).format.encoding == .windowsCP1252)   // "café" in Windows-1252
    }

    @Test(arguments: [
        ("a\r\nb\r\n\nc", LineEnding.crlf, 4), ("a\rb\rc", .cr, 3), ("a\nb\r\nc\rd", .lf, 4),
        ("a\r", .cr, 1), ("\r\n", .crlf, 1), ("x", .lf, 1), ("\n\n", .lf, 2),
    ])
    func countsLineBreaks(text: String, ending: LineEnding, lines: Int) throws {
        #expect(try TextCodec.decode(Data(text.utf8)).format.lineEnding == ending)
        #expect(TextCodec.lineCount(of: text) == lines)
    }

    @Test func emptyFileIsUTF8() throws {
        let decoded = try TextCodec.decode(Data())
        #expect(decoded.text.isEmpty && decoded.format.encoding == .utf8)
    }

    @Test func nulBytesMeanNotText() {
        #expect(throws: PluginError("This doesn't look like a text file.", code: .notText)) { try TextCodec.decode(Data([0x50, 0x4B, 0x03, 0x04, 0x00, 0x00])) }
    }

    @Test func uniformFilesRoundTripByteForByte() throws {
        for bytes in [Data("a\nb\n".utf8), Data([0xEF, 0xBB, 0xBF]) + Data("a\r\nb".utf8), Data([0x63, 0x61, 0x66, 0xE9, 0x0D])] {
            let decoded = try TextCodec.decode(bytes)
            #expect(try TextCodec.encode(decoded.text, as: decoded.format) == bytes)
        }
    }

    @Test func editsKeepTheFilesLineEnding() throws {
        let format = TextFormat(encoding: .utf8, hasBOM: false, lineEnding: .crlf)
        #expect(try TextCodec.encode("a\r\nb\nc", as: format) == Data("a\r\nb\r\nc".utf8))
    }

    @Test func invalidUTF8FallsBackAndRoundTrips() throws {
        let bytes = Data("2024-01-01 user ".utf8) + Data([0x4A, 0xF6, 0x72, 0x67]) + Data(" logged in\n".utf8)   // "Jörg" in Latin-1
        let decoded = try TextCodec.decode(bytes)
        #expect(decoded.text.contains("Jörg"))
        #expect(try TextCodec.encode(decoded.text, as: decoded.format) == bytes)
    }

    @Test func unrepresentableCharactersThrowCannotEncode() {
        let format = TextFormat(encoding: .windowsCP1252, hasBOM: false, lineEnding: .lf)
        let error = #expect(throws: PluginError.self) { try TextCodec.encode("smile 🙂", as: format) }
        #expect(error?.code == .cannotEncode)
    }
}
