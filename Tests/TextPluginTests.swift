import Foundation
import PeekerKit
@testable import PeekerText
import Testing

/// Opens `file` as an editable document.
private func open(_ file: URL) async throws -> TextDocument {
    try #require(try await TextPlugin.open(file, context: OpenContext(maxPixels: 0, allowsEditing: true)) as? TextDocument)
}

/// Saves `text` as `document`'s new contents, accepting the UTF-8 offer when `utf8` is set.
private func save(_ text: String, in document: TextDocument, utf8: Bool = false) async throws {
    try await document.save(UnsavedEdits(TextEdits.text(text)), accepting: utf8 ? TextPlugin.saveAsUTF8 : nil)
}

private func failure(_ body: () async throws -> Void) async -> PluginError? {
    do {
        try await body()
        return nil
    } catch {
        return error as? PluginError
    }
}

@Suite struct TextPluginSaving {
    @Test func unchangedSaveLeavesMixedLineEndingsAlone() async throws {
        let bytes = Data("a\nb\r\nc\n".utf8)
        let file = try TempFile.make(bytes)
        let document = try await open(file)
        try await save(document.text, in: document)
        #expect(try Data(contentsOf: file) == bytes)
    }

    @Test func editSavesInTheOriginalEncodingAndBOM() async throws {
        let bom = Data([0xEF, 0xBB, 0xBF])
        let file = try TempFile.make(bom + Data("a\r\nb\r\n".utf8))
        try await save("x\ny\n", in: try await open(file))
        #expect(try Data(contentsOf: file) == bom + Data("x\r\ny\r\n".utf8))
    }

    @Test func unrepresentableTextOffersUTF8() async throws {
        let file = try TempFile.make(Data([0x63, 0x61, 0x66, 0xE9]))   // "café" in Windows-1252
        let document = try await open(file)
        let error = await failure { try await save("🙂", in: document) }
        #expect(error?.code == .cannotEncode && error?.offer == TextPlugin.saveAsUTF8)
        try await save("🙂", in: document, utf8: true)
        #expect(try Data(contentsOf: file) == Data("🙂".utf8))
    }

    @Test func refusesToSaveReadOnlyFile() async throws {
        let bytes = Data("keep\n".utf8)
        let file = try TempFile.make(bytes)
        try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: file.path)
        let document = try await open(file)
        #expect(await failure { try await save("edited\n", in: document) } == PluginError("You don't have permission to save “f.txt”.", code: .notWritable))
        #expect(try Data(contentsOf: file) == bytes)
    }

    @Test func savingThroughSymlinkWritesTarget() async throws {
        let target = try TempFile.make(Data("old\n".utf8), name: "target.txt")
        let link = target.deletingLastPathComponent().appending(path: "link.txt")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        try await save("new\n", in: try await open(link))
        #expect(try Data(contentsOf: target) == Data("new\n".utf8))
        #expect(try FileManager.default.attributesOfItem(atPath: link.path)[.type] as? FileAttributeType == .typeSymbolicLink)
    }

    @Test func saveAfterTheFileWasDeletedCreatesItAgain() async throws {
        let file = try TempFile.make(Data("old\n".utf8))
        let document = try await open(file)
        try FileManager.default.removeItem(at: file)
        try await save("new\n", in: document)
        #expect(try Data(contentsOf: file) == Data("new\n".utf8))
        let mask = umask(0)
        umask(mask)
        #expect(try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? Int == Int(0o644 & ~mask))
        #expect(try FileManager.default.contentsOfDirectory(atPath: file.deletingLastPathComponent().path) == ["f.txt"])
    }

    @Test func saveAfterTheFolderWasDeletedFailsClearly() async throws {
        let file = try TempFile.make(Data("old\n".utf8))
        let document = try await open(file)
        try FileManager.default.removeItem(at: file.deletingLastPathComponent())
        #expect(await failure { try await save("new\n", in: document) }?.message == "“f.txt” can't be saved because its folder no longer exists.")
    }

    @Test func saveThroughALinkWhoseTargetIsGoneFailsAndKeepsTheLink() async throws {
        let target = try TempFile.make(Data("old\n".utf8), name: "target.txt")
        let link = target.deletingLastPathComponent().appending(path: "link.txt")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        let document = try await open(link)
        try FileManager.default.removeItem(at: target)
        #expect(await failure { try await save("new\n", in: document) }?.message == "“link.txt” can't be saved because the file its link points to no longer exists.")
        #expect(try FileManager.default.attributesOfItem(atPath: link.path)[.type] as? FileAttributeType == .typeSymbolicLink)
    }

    @Test(arguments: [(String.Encoding.utf16LittleEndian, [UInt8]([0xFF, 0xFE])), (.utf16BigEndian, [0xFE, 0xFF])])
    func editedUTF16WithBOMSavesInTheSameEncoding(_ encoding: String.Encoding, _ bom: [UInt8]) async throws {
        let file = try TempFile.make(Data(bom) + "a\r\nb\r\n".data(using: encoding)!)
        let document = try await open(file)
        #expect(document.text == "a\r\nb\r\n")
        try await save("x\ny é\n", in: document)
        #expect(try Data(contentsOf: file) == Data(bom) + "x\r\ny é\r\n".data(using: encoding)!)
        #expect(try await open(file).text == "x\r\ny é\r\n")
    }

    @Test func keepsPermissions() async throws {
        let file = try TempFile.make(Data("a\n".utf8))
        try FileManager.default.setAttributes([.posixPermissions: 0o640], ofItemAtPath: file.path)
        try await save("b\n", in: try await open(file))
        #expect(try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? Int == 0o640)
    }

    /// A second save compares against the first save's text, not the text at open, and each document keeps its own.
    @Test func eachSaveBecomesTheDocumentsNewBaseline() async throws {
        let file = try TempFile.make(Data("a".utf8))
        let other = try TempFile.make(Data("a".utf8))
        let first = try await open(file)
        let second = try await open(other)
        try await save("b", in: first)
        try await save("c", in: second)
        try await save("a", in: first)
        #expect(try Data(contentsOf: file) == Data("a".utf8))
        #expect(try Data(contentsOf: other) == Data("c".utf8))
    }

    @Test func recoveredTextHasATextForm() throws {
        let edits = try JSONEncoder().encode(TextEdits.text("unsaved"))
        #expect(TextPlugin.recoveryText(from: edits) == "unsaved")
        #expect(TextPlugin.recoveryText(from: Data(#"{"other":1}"#.utf8)) == nil)
    }
}

@Suite struct TextPluginLimits {
    @Test func largeFilesOpenReadOnly() async throws {
        let file = try TempFile.make(Data((0...TextLimits.editableBytes).map { $0 % 100 == 99 ? 0x0A : 0x61 }))   // short lines
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let loaded = try await TextPlugin.load(file)
        #expect(!loaded.editable)
        #expect(loaded.note == "Read-only: files over 10 MB open for viewing only.")
    }

    @Test func hugeFilesAreTruncatedAtALineBreak() async throws {
        let line = Data((String(repeating: "x", count: 99) + "\n").utf8)
        var bytes = Data(capacity: TextLimits.displayBytes + 2 * 1_048_576)
        while bytes.count <= TextLimits.displayBytes + 1_048_576 { bytes.append(line) }
        let file = try TempFile.make(bytes)
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let loaded = try await TextPlugin.load(file)
        let shown = Data(loaded.text.utf8)
        #expect(shown.count <= TextLimits.displayBytes && shown.count > TextLimits.displayBytes - line.count)
        #expect(shown.last == 0x0A && bytes.starts(with: shown))
        let size = ByteCountFormatter.string(fromByteCount: Int64(bytes.count), countStyle: .file)
        #expect(loaded.note == "Showing the first 16 MB of \(size). Read-only.")
        #expect(!loaded.editable)
        #expect(loaded.info.first { $0.label == "Size" }?.value == size)
        #expect(loaded.info.first { $0.label == "Lines" }?.value == (bytes.count / line.count).formatted())
    }

    /// 9 MB of "€" in Windows-1252 (3 UTF-8 bytes each, or 2 as Mac Roman "Ä") is within the edit limit on disk but
    /// over the display limit decoded. Saving its first 16 MB would cut the file short.
    @Test func legacyFileTruncatedOnlyWhenDecodedIsNotEditable() async throws {
        let line = Data(repeating: 0x80, count: 99) + Data([0x0A])
        var bytes = Data(capacity: 9 * 1_048_576)
        while bytes.count + line.count <= 9 * 1_048_576 { bytes.append(line) }
        let file = try TempFile.make(bytes)
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let document = try await open(file)
        #expect(!document.isEditable)
        #expect(document.note?.hasPrefix("Showing the first 16 MB of ") == true)
        #expect(await failure { try await save("short\n", in: document) } != nil)
        #expect(try Data(contentsOf: file) == bytes)
    }

    @Test func hugeSingleLineIsCutBeforeASplitCharacter() async throws {
        let bytes = Data(repeating: 0x61, count: TextLimits.longLineDisplayBytes - 1) + Data("é".utf8) + Data(repeating: 0x62, count: 10)
        let file = try TempFile.make(bytes)
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        #expect(try await TextPlugin.load(file).text.utf8.count == TextLimits.longLineDisplayBytes - 1)
    }

    /// TextKit lays out a line in one piece, so a file with a line over 1 MB shows only its first 4 MB.
    @Test(arguments: [UInt8(0x0A), 0x0D])
    func fileWithAVeryLongLineShowsLess(_ lineBreak: UInt8) async throws {
        let shortLines = Data(repeating: 0x61, count: 99) + Data([lineBreak])
        var bytes = Data(capacity: 6 * 1_048_576)
        for _ in 0..<1000 { bytes.append(shortLines) }
        bytes.append(Data(repeating: 0x62, count: 5 * 1_048_576))
        let file = try TempFile.make(bytes)
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let loaded = try await TextPlugin.load(file)
        #expect(loaded.text.utf8.count == 1000 * shortLines.count)
        #expect(!loaded.editable)
        #expect(loaded.note == "Showing the first 4 MB of \(ByteCountFormatter.string(fromByteCount: Int64(bytes.count), countStyle: .file)). Read-only.")
    }

    @Test func longLineFirstStillCutsAtTheLastBreakBeforeTheLimit() async throws {
        let shortLine = Data(repeating: 0x61, count: 99) + Data([0x0A])
        var bytes = Data(repeating: 0x62, count: 1_572_864) + Data([0x0A])
        while bytes.count < 6 * 1_048_576 { bytes.append(shortLine) }
        let file = try TempFile.make(bytes)
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let shown = Data(try await TextPlugin.load(file).text.utf8)
        #expect(shown.count <= TextLimits.longLineDisplayBytes && shown.count > TextLimits.longLineDisplayBytes - shortLine.count)
        #expect(shown.last == 0x0A && bytes.starts(with: shown))
    }

    @Test func linesJustUnderTheLongLineLimitShowInFull() async throws {
        let line = Data(repeating: 0x61, count: TextLimits.longLineBytes) + Data([0x0D, 0x0A])
        var bytes = Data(capacity: 5 * line.count)
        for _ in 0..<5 { bytes.append(line) }
        let file = try TempFile.make(bytes)
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let loaded = try await TextPlugin.load(file)
        #expect(loaded.text.utf8.count == bytes.count)
        #expect(loaded.editable && loaded.note == nil)
    }

    @Test func documentListsTheViewCommands() async throws {
        let document = try await open(try TempFile.make(Data("a\n".utf8)))
        #expect(document.commands.map { [$0.title, $0.shortcut] } == [["Zoom In", "cmd+="], ["Zoom Out", "cmd+-"], ["Wrap Lines", "opt+cmd+w"]])
    }
}
