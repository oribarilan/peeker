import AppKit
import Testing

@Suite struct RecoveryStoreTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: "peeker-recovery-\(UUID().uuidString)")
    var store: RecoveryStore { RecoveryStore(directory: directory) }
    let record = RecoveryRecord(id: "r1", url: URL(filePath: "/tmp/a.txt"), pluginID: "text", fileModified: Date(timeIntervalSince1970: 1), edits: .text("unsaved"))

    @Test func writeThenReadBack() throws {
        try store.write(record)
        #expect(store.all() == [record])
    }

    @Test func rewriteReplacesTheRecord() throws {
        try store.write(record)
        try store.write(RecoveryRecord(id: "r1", url: record.url, pluginID: "text", fileModified: nil, edits: .text("newer")))
        #expect(store.all().map(\.edits) == [.text("newer")])
    }

    @Test func removeDeletesIt() throws {
        try store.write(record)
        store.remove(id: "r1")
        #expect(store.all().isEmpty)
    }

    @Test func corruptFilesAreSkipped() throws {
        try store.write(record)
        try Data("{".utf8).write(to: directory.appending(path: "junk.json"))
        #expect(store.all() == [record])
    }

    @Test func missingDirectoryHasNoRecords() {
        #expect(store.all().isEmpty)
        store.remove(id: "r1")
    }

    @Test func newestRecordComesFirst() throws {
        let older = RecoveryRecord(id: "old", url: record.url, pluginID: "text", fileModified: nil, edits: .text("old"))
        try store.write(older)
        try store.write(record)
        try FileManager.default.setAttributes([.modificationDate: Date.now.addingTimeInterval(-60)], ofItemAtPath: directory.appending(path: "old.json").path)
        #expect(store.all().map(\.id) == ["r1", "old"])
    }

    @Test func idsThatAreNotPlainFileNamesAreRefused() throws {
        for id in ["../escape", "a/b", "", ".", "..", ".hidden"] {
            let bad = RecoveryRecord(id: id, url: record.url, pluginID: "text", fileModified: nil, edits: .text("x"))
            #expect(throws: (any Error).self) { try store.write(bad) }
        }
        #expect(!FileManager.default.fileExists(atPath: directory.deletingLastPathComponent().appending(path: "escape.json").path))
        #expect(store.all().isEmpty)
    }

    @Test func onlyTheOwnerCanReadRecords() throws {
        try store.write(record)
        let manager = FileManager.default
        #expect(try manager.attributesOfItem(atPath: directory.path)[.posixPermissions] as? Int == 0o700)
        #expect(try manager.attributesOfItem(atPath: directory.appending(path: "r1.json").path)[.posixPermissions] as? Int == 0o600)
    }

    @Test func pdfHighlightsRoundTrip() throws {
        let highlight = Highlight(page: 2, rect: CGRect(x: 1.5, y: 2, width: 3, height: 4), color: RGBA(red: 1, green: 0.8, blue: 0, alpha: 1))
        let pdf = RecoveryRecord(id: "p1", url: URL(filePath: "/tmp/a.pdf"), pluginID: "pdf", fileModified: Date(timeIntervalSince1970: 1_700_000_000.123456789), edits: .pdfHighlights([highlight]))
        try store.write(pdf)
        #expect(store.all() == [pdf])
    }
}

@Suite struct RecoveryClipboardTests {
    @Test func laterTextsJoinEarlierOnesAndRecordsGoOnlyOnceCopied() throws {
        let store = RecoveryStore(directory: FileManager.default.temporaryDirectory.appending(path: "peeker-recovery-\(UUID().uuidString)"))
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("peeker-test-\(UUID().uuidString)"))   // never the user's clipboard
        defer { pasteboard.releaseGlobally() }
        let clipboard = RecoveryClipboard(pasteboard: pasteboard, store: store)
        let a = RecoveryRecord(id: "a", url: URL(filePath: "/tmp/a.txt"), pluginID: "text", fileModified: nil, edits: .text("text of a"))
        let b = RecoveryRecord(id: "b", url: URL(filePath: "/tmp/b.txt"), pluginID: "text", fileModified: nil, edits: .text("text of b"))
        try store.write(a)
        try store.write(b)

        #expect(clipboard.add([a]))
        #expect(pasteboard.string(forType: .string) == "text of a")
        #expect(store.all() == [b])

        #expect(clipboard.add([b]))
        #expect(pasteboard.string(forType: .string) == "/tmp/a.txt\ntext of a\n\n/tmp/b.txt\ntext of b")
        #expect(store.all().isEmpty)
    }

    @Test func highlightRecordsAreLeftAlone() throws {
        let store = RecoveryStore(directory: FileManager.default.temporaryDirectory.appending(path: "peeker-recovery-\(UUID().uuidString)"))
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("peeker-test-\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        let pdf = RecoveryRecord(id: "p", url: URL(filePath: "/tmp/a.pdf"), pluginID: "pdf", fileModified: nil, edits: .pdfHighlights([]))
        try store.write(pdf)
        #expect(RecoveryClipboard(pasteboard: pasteboard, store: store).add([pdf]))
        #expect(store.all() == [pdf])
    }
}
