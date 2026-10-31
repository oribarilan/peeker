import AppKit
import PDFKit

/// Searches a PDF as the user types, on PDFKit's background search, ignoring case and accents. Matches are added as
/// they're found and highlighted on the pages; one is current, selected and scrolled into view.
final class PDFFinder: NSObject {
    private let view: PDFView
    private(set) var matches: [PDFSelection] = []
    private(set) var current: Int?
    private(set) var isSearching = false
    private var query = ""
    /// Whether the matches show on the pages: off while the find bar is closed.
    var highlights = true {
        didSet { showHighlights() }
    }
    /// Called whenever `status` may have changed.
    var onChange: (() -> Void)?
    private var searched: PDFDocument?
    private var observers: [NSObjectProtocol] = []
    /// Tells a search's notifications from those of the search it replaced, which can still be queued.
    private var generation = 0

    init(view: PDFView) {
        self.view = view
    }

    isolated deinit {
        stop()
    }

    /// "2 of 5", "Not found", or empty while there's nothing to say yet.
    var status: String {
        if let current { return "\(current + 1) of \(matches.count)" }
        return query.isEmpty || isSearching ? "" : "Not found"
    }

    func search(_ text: String) {
        stop()
        matches = []
        current = nil
        query = text
        showHighlights()
        if !text.isEmpty, let document = view.document {
            observe(document)
            isSearching = true
            document.beginFindString(text, withOptions: [.caseInsensitive, .diacriticInsensitive])
        }
        onChange?()
    }

    func next() {
        guard !matches.isEmpty else { return NSSound.beep() }
        current = ((current ?? -1) + 1) % matches.count
        select()
    }

    func previous() {
        guard !matches.isEmpty else { return NSSound.beep() }
        current = ((current ?? 0) - 1 + matches.count) % matches.count
        select()
    }

    private func observe(_ document: PDFDocument) {
        searched = document
        generation += 1
        let search = generation
        let center = NotificationCenter.default
        // PDFKit may post from its search thread; the main queue brings each one here in order.
        observers = [
            center.addObserver(forName: .PDFDocumentDidFindMatch, object: document, queue: .main) { [weak self] note in
                // Safe: the main queue runs this block on the main thread, where the selection is used.
                nonisolated(unsafe) let selection = note.userInfo?["PDFDocumentFoundSelection"] as? PDFSelection
                MainActor.assumeIsolated { self?.found(selection, in: search) }
            },
            center.addObserver(forName: .PDFDocumentDidEndFind, object: document, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.ended(search) }
            },
        ]
    }

    private func found(_ selection: PDFSelection?, in search: Int) {
        guard search == generation, let selection else { return }
        selection.color = .findHighlightColor
        matches.append(selection)
        if current == nil {
            current = 0
            select()
        }
        showHighlights()
        onChange?()
    }

    private func ended(_ search: Int) {
        guard search == generation else { return }
        stopObserving()
        isSearching = false
        onChange?()
    }

    private func stop() {
        if isSearching { searched?.cancelFindString() }
        stopObserving()
        isSearching = false
    }

    private func stopObserving() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        searched = nil
    }

    private func select() {
        guard let current else { return }
        view.setCurrentSelection(matches[current], animate: false)
        view.go(to: matches[current])
        onChange?()
    }

    private func showHighlights() {
        view.highlightedSelections = highlights && !matches.isEmpty ? matches : nil
    }
}
