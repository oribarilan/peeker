import AppKit
import os

/// Recovered text that can't go back into a document this launch (its file is gone, or its view can't edit it). Every
/// such text stays on the clipboard together, so a later one doesn't replace an earlier one.
final class RecoveryClipboard {
    private let pasteboard: NSPasteboard
    private let store: RecoveryStore
    /// A record's edits as plain text, from its plugin; nil when they have none.
    private let text: (RecoveryRecord) -> String?
    private var entries: [(path: String, text: String)] = []
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "dev.peeker", category: "recovery")

    init(pasteboard: NSPasteboard, store: RecoveryStore, text: @escaping (RecoveryRecord) -> String?) {
        self.pasteboard = pasteboard
        self.store = store
        self.text = text
    }

    /// Adds the text of records that have one and writes everything collected so far in one write, each text under its file's path
    /// when there are several. The records are removed only once the write succeeded; false when it didn't.
    func add(_ records: [RecoveryRecord]) -> Bool {
        let added = records.compactMap { record -> (id: String, path: String, text: String)? in
            text(record).map { (record.id, record.url.path, $0) }
        }
        guard !added.isEmpty else { return true }
        let all = entries + added.map { ($0.path, $0.text) }
        let joined = all.count == 1 ? all[0].text : all.map { "\($0.path)\n\($0.text)" }.joined(separator: "\n\n")
        pasteboard.clearContents()
        guard pasteboard.setString(joined, forType: .string) else {
            Self.log.error("can't copy recovered text to the clipboard; keeping its records")
            return false
        }
        entries = all
        added.forEach { store.remove(id: $0.id) }
        return true
    }
}
