import Foundation
import PeekerKit

/// Keeps one document's unsaved edits in the recovery store, so a crash loses none. `schedule` writes a short delay
/// after the last edit; `write` writes at once, or removes the record when there's nothing to keep.
final class RecoveryJournal {
    /// What to keep: the unsaved edits, and the file's modification date they were made against.
    struct Contents {
        let edits: UnsavedEdits
        let fileModified: Date?
    }

    private let store: RecoveryStore
    private let id: String
    private let url: URL
    private let pluginID: String
    private let contents: () -> Contents?
    private var pending: DispatchWorkItem?
    private let delay: TimeInterval

    init(store: RecoveryStore, id: String, url: URL, pluginID: String, delay: TimeInterval = 2, contents: @escaping () -> Contents?) {
        self.store = store
        self.id = id
        self.url = url
        self.pluginID = pluginID
        self.delay = delay
        self.contents = contents
    }

    func write() {
        pending?.cancel()
        pending = nil
        guard let contents = contents() else { return store.remove(id: id) }
        store.writeInBackground(id: id, url: url, pluginID: pluginID, fileModified: contents.fileModified, edits: contents.edits)
    }

    /// Writes `delay` after the last call; each call restarts the delay.
    func schedule() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.write() } }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
}
