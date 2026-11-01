import AppKit
import Testing

/// A record whose edits are `json`, as a plugin would encode them.
private func record(_ id: String, _ json: String, url: URL = URL(filePath: "/tmp/a.txt"), plugin: String = "text",
                    fileModified: Date? = nil) throws -> RecoveryRecord {
    try RecoveryRecord(id: id, url: url, pluginID: plugin, fileModified: fileModified, edits: Data(json.utf8))
}

/// Stands in for a plugin's recovery text: edits shaped `{"text": …}` have one.
private func text(of record: RecoveryRecord) -> String? {
    (try? JSONDecoder().decode([String: String].self, from: record.editsData))?["text"]
}

@Suite struct RecoveryStoreTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: "peeker-recovery-\(UUID().uuidString)")
    var store: RecoveryStore { RecoveryStore(directory: directory) }

    @Test func writeThenReadBack() throws {
        let saved = try record("r1", #"{"text":"unsaved"}"#, fileModified: Date(timeIntervalSince1970: 1))
        try store.write(saved)
        #expect(store.all() == [saved])
    }

    @Test func rewriteReplacesTheRecord() throws {
        try store.write(try record("r1", #"{"text":"older"}"#))
        let newer = try record("r1", #"{"text":"newer"}"#)
        try store.write(newer)
        #expect(store.all() == [newer])
    }

    @Test func removeDeletesIt() throws {
        try store.write(try record("r1", #"{"text":"unsaved"}"#))
        store.remove(id: "r1")
        #expect(store.all().isEmpty)
    }

    @Test func corruptFilesAreSkipped() throws {
        let saved = try record("r1", #"{"text":"unsaved"}"#)
        try store.write(saved)
        try Data("{".utf8).write(to: directory.appending(path: "junk.json"))
        #expect(store.all() == [saved])
    }

    @Test func missingDirectoryHasNoRecords() {
        #expect(store.all().isEmpty)
        store.remove(id: "r1")
    }

    @Test func newestRecordComesFirst() throws {
        try store.write(try record("old", #"{"text":"old"}"#))
        try store.write(try record("r1", #"{"text":"new"}"#))
        try FileManager.default.setAttributes([.modificationDate: Date.now.addingTimeInterval(-60)], ofItemAtPath: directory.appending(path: "old.json").path)
        #expect(store.all().map(\.id) == ["r1", "old"])
    }

    @Test func idsThatAreNotPlainFileNamesAreRefused() throws {
        for id in ["../escape", "a/b", "", ".", "..", ".hidden"] {
            let bad = try record(id, #"{"text":"x"}"#)
            #expect(throws: (any Error).self) { try store.write(bad) }
        }
        #expect(!FileManager.default.fileExists(atPath: directory.deletingLastPathComponent().appending(path: "escape.json").path))
        #expect(store.all().isEmpty)
    }

    /// Restoring opens a record's URL as a file, so a record pointing anywhere else is skipped.
    @Test func aRecordThatDoesntPointAtAFileIsSkipped() throws {
        try store.write(try record("web", #"{"text":"unsaved"}"#, url: try #require(URL(string: "https://example.com/notes.txt"))))
        #expect(store.all().isEmpty)
    }

    @Test func onlyTheOwnerCanReadRecords() throws {
        try store.write(try record("r1", #"{"text":"unsaved"}"#))
        let manager = FileManager.default
        #expect(try manager.attributesOfItem(atPath: directory.path)[.posixPermissions] as? Int == 0o700)
        #expect(try manager.attributesOfItem(atPath: directory.appending(path: "r1.json").path)[.posixPermissions] as? Int == 0o600)
    }

    @Test func nestedEditsRoundTrip() throws {
        let edits = #"{"marks":{"list":[{"page":2,"rect":[[1.5,2],[3,4]],"color":{"red":1,"green":0.8,"blue":0,"alpha":1},"note":null,"bold":true}]}}"#
        let pdf = try record("p1", edits, url: URL(filePath: "/tmp/a.pdf"), plugin: "pdf", fileModified: Date(timeIntervalSince1970: 1_700_000_000.123456789))
        try store.write(pdf)
        let read = try #require(store.all().first)
        #expect(read == pdf)
        #expect(try JSONSerialization.jsonObject(with: read.editsData) as? NSDictionary == JSONSerialization.jsonObject(with: Data(edits.utf8)) as? NSDictionary)
    }

    @Test func editsThatAreNotJSONAreRefused() {
        #expect(throws: (any Error).self) { try record("r1", "not json") }
    }

    /// The previous version stored the host's edit enum in the same place, as JSON.
    @Test func readsRecordsWrittenBeforePluginsMovedIntoTheApp() throws {
        struct OldRecord: Encodable {
            let id: String, url: URL, pluginID: String, fileModified: Date?
            let edits: [String: [String: String]]
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let old = OldRecord(id: "r1", url: URL(filePath: "/tmp/a.txt"), pluginID: "text", fileModified: nil, edits: ["text": ["_0": "unsaved"]])
        try JSONEncoder().encode(old).write(to: directory.appending(path: "r1.json"))
        let read = try #require(store.all().first)
        #expect(read.pluginID == "text")
        #expect(try JSONDecoder().decode([String: [String: String]].self, from: read.editsData) == ["text": ["_0": "unsaved"]])
    }
}

@Suite struct RecoveryFolder {
    /// Screen tests point PEEKER_RECOVERY at their own folder, so a killed run never leaves a record the user's
    /// Peeker would restore.
    @Test func peekerRecoveryMovesTheStore() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "peeker-recovery-\(UUID().uuidString)")
        let store = RecoveryStore(directory: RecoveryStore.directory(environment: ["PEEKER_RECOVERY": folder.path]))
        let saved = try record("r1", #"{"text":"unsaved"}"#)
        try store.write(saved)
        #expect(FileManager.default.fileExists(atPath: folder.appending(path: "r1.json").path))
        #expect(store.all() == [saved])
    }

    @Test func withoutItTheStoreIsInApplicationSupport() {
        for environment in [[:], ["PEEKER_RECOVERY": ""]] {
            let directory = RecoveryStore.directory(environment: environment)
            #expect(directory.lastPathComponent == "Recovery")
            #expect(directory.path.contains("/Library/Application Support/"))
        }
    }
}

@Suite struct RecoveryClipboardTests {
    @Test func laterTextsJoinEarlierOnesAndRecordsGoOnlyOnceCopied() throws {
        let store = RecoveryStore(directory: FileManager.default.temporaryDirectory.appending(path: "peeker-recovery-\(UUID().uuidString)"))
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("peeker-test-\(UUID().uuidString)"))   // never the user's clipboard
        defer { pasteboard.releaseGlobally() }
        let clipboard = RecoveryClipboard(pasteboard: pasteboard, store: store, text: text(of:))
        let a = try record("a", #"{"text":"text of a"}"#, url: URL(filePath: "/tmp/a.txt"))
        let b = try record("b", #"{"text":"text of b"}"#, url: URL(filePath: "/tmp/b.txt"))
        try store.write(a)
        try store.write(b)

        #expect(clipboard.add([a]))
        #expect(pasteboard.string(forType: .string) == "text of a")
        #expect(store.all() == [b])

        #expect(clipboard.add([b]))
        #expect(pasteboard.string(forType: .string) == "/tmp/a.txt\ntext of a\n\n/tmp/b.txt\ntext of b")
        #expect(store.all().isEmpty)
    }

    @Test func recordsWithoutTextAreLeftAlone() throws {
        let store = RecoveryStore(directory: FileManager.default.temporaryDirectory.appending(path: "peeker-recovery-\(UUID().uuidString)"))
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("peeker-test-\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        let pdf = try record("p", "[]", url: URL(filePath: "/tmp/a.pdf"), plugin: "pdf")
        try store.write(pdf)
        #expect(RecoveryClipboard(pasteboard: pasteboard, store: store, text: text(of:)).add([pdf]))
        #expect(store.all() == [pdf])
    }
}

@Suite struct RecoveryRestoring {
    /// A file's newest record reopens; one whose file is gone keeps its text on the clipboard; one with no text form
    /// is dropped with a message. None comes back on the next launch.
    @Test func eachRecordReopensGoesToTheClipboardOrIsDroppedWithAMessage() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "peeker-recovery-\(UUID().uuidString)")
        let store = RecoveryStore(directory: directory)
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("peeker-test-\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        let file = try TempFile.make(Data("a".utf8))
        let missing = FileManager.default.temporaryDirectory.appending(path: "peeker-missing-\(UUID().uuidString)")
        try store.write(try record("old", #"{"text":"older"}"#, url: file))
        try FileManager.default.setAttributes([.modificationDate: Date.distantPast], ofItemAtPath: directory.appending(path: "old.json").path)
        try store.write(try record("new", #"{"text":"newer"}"#, url: file))
        try store.write(try record("gone", #"{"text":"lost text"}"#, url: missing.appending(path: "a.txt")))
        try store.write(try record("lost", "[]", url: missing.appending(path: "a.pdf"), plugin: "pdf"))
        var opened: [String] = [], told: [String] = []
        RecoveryRestore(store: store, clipboard: RecoveryClipboard(pasteboard: pasteboard, store: store, text: text(of:)),
                        canOpen: { $0.pluginID == "text" }, hasText: { text(of: $0) != nil },
                        open: { opened.append($0.id) }, tell: { told.append($0) }).run()
        #expect(opened == ["new"])
        #expect(pasteboard.string(forType: .string) == "lost text")
        #expect(told.count == 2, "\(told)")
        #expect(store.all().map(\.id) == ["new"])
    }
}
