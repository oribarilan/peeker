import AppKit

/// Puts back the documents that had unsaved edits when the app last stopped without quitting. A file's newest record
/// goes back into a window; a record that can't keeps its text on the clipboard, or is dropped with a message.
struct RecoveryRestore {
    let store: RecoveryStore
    let clipboard: RecoveryClipboard
    /// Whether an enabled plugin opens the record's file.
    let canOpen: (RecoveryRecord) -> Bool
    /// Whether the record's edits have a text form for the clipboard.
    let hasText: (RecoveryRecord) -> Bool
    let open: (RecoveryRecord) -> Void
    var tell: (String) -> Void = { message in
        let alert = NSAlert()
        alert.messageText = message
        alert.runModal()
    }

    func run() {
        var restored: Set<URL> = []
        var missingText: [RecoveryRecord] = [], unopenableText: [RecoveryRecord] = []
        for record in store.all() {   // newest first, so a file's newest record wins
            guard restored.insert(record.url.standardizedFileURL).inserted else {
                store.remove(id: record.id)
                continue
            }
            let exists = FileManager.default.fileExists(atPath: record.url.path)
            if exists, canOpen(record) {
                open(record)
                continue
            }
            // Without its file or an enabled plugin for it, the record can't go back into a window; kept, it would
            // come back every launch.
            if hasText(record) {
                if exists { unopenableText.append(record) } else { missingText.append(record) }
            } else {
                store.remove(id: record.id)
                let name = "“\(record.url.lastPathComponent)”"
                tell(exists ? "No enabled plugin opens \(name). Its unsaved changes couldn't be restored."
                            : "\(name) no longer exists. Its unsaved changes couldn't be restored.")
            }
        }
        copyToClipboard(missingText) { names, count in "\(names) \(count == 1 ? "no longer exists" : "no longer exist")." }
        copyToClipboard(unopenableText) { names, _ in "No enabled plugin opens \(names)." }
    }

    /// Puts the records' text on the clipboard and says why; the records stay if the clipboard refuses.
    private func copyToClipboard(_ records: [RecoveryRecord], reason: (_ names: String, _ count: Int) -> String) {
        guard !records.isEmpty, clipboard.add(records) else { return }
        let names = ListFormatter.localizedString(byJoining: records.map { "“\($0.url.lastPathComponent)”" })
        tell(reason(names, records.count) + " Your unsaved text was copied to the clipboard.")
    }
}
