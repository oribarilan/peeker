import Foundation
import Testing

@Suite struct TextPluginTests {
    let plugin = TextPlugin()

    @Test func unchangedSaveLeavesMixedLineEndingsAlone() throws {
        let bytes = Data("a\nb\r\nc\n".utf8)
        let file = try TempFile.make(bytes)
        let text = try open(file)
        _ = try save(text)
        #expect(try Data(contentsOf: file) == bytes)
    }

    @Test func editSavesInTheOriginalEncodingAndBOM() throws {
        let bom = Data([0xEF, 0xBB, 0xBF])
        let file = try TempFile.make(bom + Data("a\r\nb\r\n".utf8))
        _ = try open(file)
        _ = try save("x\ny\n")
        #expect(try Data(contentsOf: file) == bom + Data("x\r\ny\r\n".utf8))
    }

    @Test func convertToUTF8WritesUTF8WithoutBOM() throws {
        let file = try TempFile.make(Data([0x63, 0x61, 0x66, 0xE9]))   // "café" in Windows-1252
        _ = try open(file)
        _ = try save("🙂", convertToUTF8: true)
        #expect(try Data(contentsOf: file) == Data("🙂".utf8))
    }

    @Test func refusesToSaveReadOnlyFile() throws {
        let bytes = Data("keep\n".utf8)
        let file = try TempFile.make(bytes)
        try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: file.path)
        _ = try open(file)
        let error = #expect(throws: PluginFailure.self) { try save("edited\n") }
        #expect(error == PluginFailure("You don't have permission to save “f.txt”.", code: .notWritable))
        #expect(try Data(contentsOf: file) == bytes)
    }

    @Test func savingThroughSymlinkWritesTarget() throws {
        let target = try TempFile.make(Data("old\n".utf8), name: "target.txt")
        let link = target.deletingLastPathComponent().appending(path: "link.txt")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        _ = try open(link)
        _ = try save("new\n")
        #expect(try Data(contentsOf: target) == Data("new\n".utf8))
        #expect(try FileManager.default.attributesOfItem(atPath: link.path)[.type] as? FileAttributeType == .typeSymbolicLink)
    }

    @Test func saveAfterTheFileWasDeletedCreatesItAgain() throws {
        let file = try TempFile.make(Data("old\n".utf8))
        _ = try open(file)
        try FileManager.default.removeItem(at: file)
        _ = try save("new\n")
        #expect(try Data(contentsOf: file) == Data("new\n".utf8))
        let mask = umask(0)
        umask(mask)
        #expect(try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? Int == Int(0o644 & ~mask))
        #expect(try FileManager.default.contentsOfDirectory(atPath: file.deletingLastPathComponent().path) == ["f.txt"])
    }

    @Test func saveAfterTheFolderWasDeletedFailsClearly() throws {
        let file = try TempFile.make(Data("old\n".utf8))
        _ = try open(file)
        try FileManager.default.removeItem(at: file.deletingLastPathComponent())
        let error = #expect(throws: PluginFailure.self) { try save("new\n") }
        #expect(error?.message == "“f.txt” can't be saved because its folder no longer exists.")
    }

    @Test func saveThroughALinkWhoseTargetIsGoneFailsAndKeepsTheLink() throws {
        let target = try TempFile.make(Data("old\n".utf8), name: "target.txt")
        let link = target.deletingLastPathComponent().appending(path: "link.txt")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        _ = try open(link)
        try FileManager.default.removeItem(at: target)
        let error = #expect(throws: PluginFailure.self) { try save("new\n") }
        #expect(error?.message == "“link.txt” can't be saved because the file its link points to no longer exists.")
        #expect(try FileManager.default.attributesOfItem(atPath: link.path)[.type] as? FileAttributeType == .typeSymbolicLink)
    }

    @Test(arguments: [(String.Encoding.utf16LittleEndian, [UInt8]([0xFF, 0xFE])), (.utf16BigEndian, [0xFE, 0xFF])])
    func editedUTF16WithBOMSavesInTheSameEncoding(_ encoding: String.Encoding, _ bom: [UInt8]) throws {
        let file = try TempFile.make(Data(bom) + "a\r\nb\r\n".data(using: encoding)!)
        #expect(try open(file) == "a\r\nb\r\n")
        _ = try save("x\ny é\n")
        #expect(try Data(contentsOf: file) == Data(bom) + "x\r\ny é\r\n".data(using: encoding)!)
        #expect(try open(file) == "x\r\ny é\r\n")
    }

    @Test func keepsPermissions() throws {
        let file = try TempFile.make(Data("a\n".utf8))
        try FileManager.default.setAttributes([.posixPermissions: 0o640], ofItemAtPath: file.path)
        _ = try open(file)
        _ = try save("b\n")
        #expect(try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? Int == 0o640)
    }

    /// A second save compares against the first save's text, not the text at open, and each document keeps its own.
    @Test func eachSaveBecomesTheDocumentsNewBaseline() throws {
        let file = try TempFile.make(Data("a".utf8))
        let other = try TempFile.make(Data("a".utf8))
        _ = try open(file)
        _ = try open(other, as: "e")
        _ = try save("b")
        _ = try save("c", in: "e")
        _ = try save("a")
        #expect(try Data(contentsOf: file) == Data("a".utf8))
        #expect(try Data(contentsOf: other) == Data("c".utf8))
    }

    @Test func largeFilesOpenReadOnly() throws {
        let file = try TempFile.make(Data((0...TextLimits.editableBytes).map { $0 % 100 == 99 ? 0x0A : 0x61 }))   // short lines
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let reply = try plugin.open("d", path: file.path, maxPixels: 0)
        guard case .text(let shared) = reply.view else { Issue.record("not text"); return }
        SharedFile.discard(shared.file)
        #expect(!shared.editable)
        #expect(shared.note == "Read-only: files over 10 MB open for viewing only.")
    }

    @Test func hugeFilesAreTruncatedAtALineBreak() throws {
        let line = Data((String(repeating: "x", count: 99) + "\n").utf8)
        var bytes = Data(capacity: TextLimits.displayBytes + 2 * 1_048_576)
        while bytes.count <= TextLimits.displayBytes + 1_048_576 { bytes.append(line) }
        let file = try TempFile.make(bytes)
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let reply = try plugin.open("d", path: file.path, maxPixels: 0)
        guard case .text(let shared) = reply.view else { Issue.record("not text"); return }
        let shown = try SharedFile.withMapped(shared.file) { Data($0) }
        #expect(shown.count <= TextLimits.displayBytes && shown.count > TextLimits.displayBytes - line.count)
        #expect(shown.last == 0x0A && bytes.starts(with: shown))
        let size = ByteCountFormatter.string(fromByteCount: Int64(bytes.count), countStyle: .file)
        #expect(shared.note == "Showing the first 16 MB of \(size). Read-only.")
        #expect(!shared.editable)
        guard case .info(let rows) = reply.sidebar?.first else { Issue.record("no info"); return }
        #expect(rows.first { $0.label == "Size" }?.value == size)
        #expect(rows.first { $0.label == "Lines" }?.value == (bytes.count / line.count).formatted())
    }

    /// 9 MB of "€" in Windows-1252 (3 UTF-8 bytes each, or 2 as Mac Roman "Ä") is within the edit limit on disk but
    /// over the display limit decoded. Saving its first 16 MB would cut the file short.
    @Test func legacyFileTruncatedOnlyWhenDecodedIsNotEditable() throws {
        let line = Data(repeating: 0x80, count: 99) + Data([0x0A])
        var bytes = Data(capacity: 9 * 1_048_576)
        while bytes.count + line.count <= 9 * 1_048_576 { bytes.append(line) }
        let file = try TempFile.make(bytes)
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let reply = try plugin.open("d", path: file.path, maxPixels: 0)
        guard case .text(let shared) = reply.view else { Issue.record("not text"); return }
        SharedFile.discard(shared.file)
        #expect(!shared.editable)
        #expect(shared.note?.hasPrefix("Showing the first 16 MB of ") == true)
        #expect(throws: PluginFailure.self) { try save("short\n") }
        #expect(try Data(contentsOf: file) == bytes)
    }

    @Test func hugeSingleLineIsCutBeforeASplitCharacter() throws {
        let bytes = Data(repeating: 0x61, count: TextLimits.longLineDisplayBytes - 1) + Data("é".utf8) + Data(repeating: 0x62, count: 10)
        let file = try TempFile.make(bytes)
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let reply = try plugin.open("d", path: file.path, maxPixels: 0)
        guard case .text(let shared) = reply.view else { Issue.record("not text"); return }
        #expect(try SharedFile.withMapped(shared.file) { $0.count } == TextLimits.longLineDisplayBytes - 1)
    }

    /// TextKit lays out a line in one piece, so a file with a line over 1 MB shows only its first 4 MB.
    @Test(arguments: [UInt8(0x0A), 0x0D])
    func fileWithAVeryLongLineShowsLess(_ lineBreak: UInt8) throws {
        let shortLines = Data(repeating: 0x61, count: 99) + Data([lineBreak])
        var bytes = Data(capacity: 6 * 1_048_576)
        for _ in 0..<1000 { bytes.append(shortLines) }
        bytes.append(Data(repeating: 0x62, count: 5 * 1_048_576))
        let file = try TempFile.make(bytes)
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let reply = try plugin.open("d", path: file.path, maxPixels: 0)
        guard case .text(let shared) = reply.view else { Issue.record("not text"); return }
        #expect(try SharedFile.withMapped(shared.file) { $0.count } == 1000 * shortLines.count)
        #expect(!shared.editable)
        #expect(shared.note == "Showing the first 4 MB of \(ByteCountFormatter.string(fromByteCount: Int64(bytes.count), countStyle: .file)). Read-only.")
    }

    @Test func longLineFirstStillCutsAtTheLastBreakBeforeTheLimit() throws {
        let shortLine = Data(repeating: 0x61, count: 99) + Data([0x0A])
        var bytes = Data(repeating: 0x62, count: 1_572_864) + Data([0x0A])
        while bytes.count < 6 * 1_048_576 { bytes.append(shortLine) }
        let file = try TempFile.make(bytes)
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let reply = try plugin.open("d", path: file.path, maxPixels: 0)
        guard case .text(let shared) = reply.view else { Issue.record("not text"); return }
        let shown = try SharedFile.withMapped(shared.file) { Data($0) }
        #expect(shown.count <= TextLimits.longLineDisplayBytes && shown.count > TextLimits.longLineDisplayBytes - shortLine.count)
        #expect(shown.last == 0x0A && bytes.starts(with: shown))
    }

    @Test func linesJustUnderTheLongLineLimitShowInFull() throws {
        let line = Data(repeating: 0x61, count: TextLimits.longLineBytes) + Data([0x0D, 0x0A])
        var bytes = Data(capacity: 5 * line.count)
        for _ in 0..<5 { bytes.append(line) }
        let file = try TempFile.make(bytes)
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let reply = try plugin.open("d", path: file.path, maxPixels: 0)
        guard case .text(let shared) = reply.view else { Issue.record("not text"); return }
        #expect(try SharedFile.withMapped(shared.file) { $0.count } == bytes.count)
        #expect(shared.editable && shared.note == nil)
    }

    @Test func replyListsTheViewCommands() throws {
        let reply = try plugin.open("d", path: try TempFile.make(Data("a\n".utf8)).path, maxPixels: 0)
        if case .text(let shared) = reply.view { SharedFile.discard(shared.file) }
        #expect(reply.commands?.map { [$0.title, $0.shortcut, $0.verb] } == [
            ["Zoom In", "cmd+=", "zoom-in"], ["Zoom Out", "cmd+-", "zoom-out"], ["Wrap Lines", "opt+cmd+w", "toggle-wrap"],
        ])
    }

    /// Opens `file` as document `doc` and returns the text the host would show.
    private func open(_ file: URL, as doc: DocumentID = "d") throws -> String {
        let reply = try plugin.open(doc, path: file.path, maxPixels: 0)
        guard case .text(let shared) = reply.view else { throw PluginFailure("not text") }
        return try SharedFile.withMapped(shared.file) { String(decoding: $0, as: UTF8.self) }
    }

    private func save(_ text: String, in doc: DocumentID = "d", convertToUTF8: Bool = false) throws -> Reply {
        try plugin.save(doc, .text(try SharedFile.create(Data(text.utf8)), convertToUTF8: convertToUTF8))
    }
}
