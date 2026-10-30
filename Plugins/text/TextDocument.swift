import AppKit
import PeekerKit

/// Plain text in a native text view: system monospaced font, find bar, wrap toggle and zoom.
///
/// TextKit 1 with non-contiguous layout, not TextKit 2: TextKit 2 gives every line fragment its own view and
/// registers the scroll view with the titlebar's edge effect, which kept a warm Space on a 10 KB file near 30 ms
/// (TextKit 1: under 20). It also placed find results screens away from the match in a 90 MB log.
final class TextDocument: NSObject, PluginDocument, NSTextViewDelegate {
    private let url: URL
    private let allowsEditing: Bool
    private let root = NSView()
    private let scrollView = NSScrollView()
    /// Owns the layout manager and text container; a TextKit 1 text view doesn't retain its storage.
    private let storage = NSTextStorage()
    private var textView: NSTextView { scrollView.documentView as! NSTextView }
    private let noteLabel = NSTextField(labelWithString: "")
    private var scrollBelowNote: NSLayoutConstraint!
    private var scrollAtTop: NSLayoutConstraint!
    private var fontSize = TextDocument.defaultFontSize
    private var wraps = true
    /// Cached for unwrapped text; nil until wrap is first turned off, and after the text changes.
    private var longestLineUnits: Int?
    /// The text as last loaded or saved.
    private var baseline: String
    /// How the file stores its text, so a save writes it back the same way.
    private var format: TextFormat
    /// Why the file is read-only or only partly shown; nil when it's editable.
    private var readOnlyReason: String?
    private(set) var info: [InfoRow]
    var onEdit: (() -> Void)?

    private static let defaultFontSize: CGFloat = 12
    private static let fontSizes: ClosedRange<CGFloat> = 6...72

    init(url: URL, loaded: TextPlugin.Loaded, allowsEditing: Bool) {
        self.url = url
        self.allowsEditing = allowsEditing
        baseline = loaded.text
        format = loaded.format
        info = loaded.info
        let layoutManager = NSLayoutManager()
        layoutManager.allowsNonContiguousLayout = true
        storage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 400), textContainer: textContainer)
        textView.isVerticallyResizable = true
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        textView.autoresizingMask = [.width]
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        super.init()
        layOut()
        textView.delegate = self
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.textContainerInset = NSSize(width: 6, height: 8)
        // Always on and hidden while the text fits, so a wrap toggle doesn't also retile the scroll view.
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        applyFont()
        apply(editable: loaded.editable, note: loaded.note)
        textView.string = loaded.text
    }

    var contentView: NSView { root }
    var focusView: NSView? { textView }
    var sidebar: [SidebarPanel] { InfoPanel.make(info).map { [$0] } ?? [] }
    var isEditable: Bool { textView.isEditable }
    var note: String? { noteLabel.isHidden ? nil : noteLabel.stringValue }
    var text: String { textView.string }

    let commands = [
        CommandSpec(id: "zoom-in", title: "Zoom In", symbol: "plus.magnifyingglass", shortcut: "cmd+="),
        CommandSpec(id: "zoom-out", title: "Zoom Out", symbol: "minus.magnifyingglass", shortcut: "cmd+-"),
        CommandSpec(id: "toggle-wrap", title: "Wrap Lines", symbol: "arrow.turn.down.left", shortcut: "opt+cmd+w"),
    ]

    /// Shows the file as it is on disk now, keeping zoom, wrap and the scroll position. A growing log can cross a size
    /// limit, so editability and the note can change too.
    func reload() async throws(PluginError) -> Bool {
        let loaded = try await TextPlugin.load(url)
        guard unsavedEdits() == nil else { return true }  // typing that started meanwhile wins
        format = loaded.format
        info = loaded.info
        apply(editable: loaded.editable, note: loaded.note)
        update(text: loaded.text)
        return true
    }

    func unsavedEdits() -> UnsavedEdits? {
        guard isEditable else { return nil }
        let text = textView.string
        // A literal comparison: String == treats canonically equivalent text as equal, which would drop such an edit.
        return (text as NSString).isEqual(to: baseline) ? nil : UnsavedEdits(TextEdits.text(text))
    }

    /// Replaces the whole text as one undoable change.
    func restore(encoded edits: Data) -> Bool {
        guard isEditable, let text = (try? JSONDecoder().decode(TextEdits.self, from: edits))?.text else { return false }
        let range = NSRange(location: 0, length: storage.length)
        guard textView.shouldChangeText(in: range, replacementString: text) else { return false }
        textView.replaceCharacters(in: range, with: text)
        textView.didChangeText()
        return true
    }

    func save(_ edits: UnsavedEdits, accepting offer: SaveOffer?) async throws(PluginError) {
        guard isEditable, let text = (edits.value as? TextEdits)?.text else { throw PluginError(readOnlyReason ?? TextPlugin.readOnlyNote) }
        let target = offer == TextPlugin.saveAsUTF8 ? TextFormat(encoding: .utf8, hasBOM: false, lineEnding: format.lineEnding) : format
        // Bytes, not String ==, which treats canonically equivalent text as equal. Unchanged text writes nothing, so a
        // file with mixed line endings stays byte for byte the same.
        guard target != format || Data(text.utf8) != Data(baseline.utf8) else {
            baseline = text
            return
        }
        info = try await TextPlugin.write(text, as: target, to: url.path)
        format = target
        baseline = text
    }

    func revertEdits() {
        update(text: baseline)
    }

    /// Replaces the text with a reloaded version, keeping the scroll position. The undo history refers to the old
    /// text, so it goes.
    private func update(text: String) {
        let origin = scrollView.contentView.bounds.origin
        baseline = text
        textView.string = text
        textView.undoManager?.removeAllActions()
        longestLineUnits = nil
        if !wraps { applyWrap() }
        scrollView.contentView.scroll(to: origin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func apply(editable: Bool, note: String?) {
        readOnlyReason = editable ? nil : note ?? TextPlugin.readOnlyNote
        textView.isEditable = allowsEditing && editable
        noteLabel.stringValue = note ?? ""
        noteLabel.isHidden = note == nil
        scrollAtTop.isActive = note == nil
        scrollBelowNote.isActive = note != nil
    }

    func textDidChange(_ notification: Notification) {
        onEdit?()
    }

    func perform(_ id: String) -> Bool {
        switch id {
        case "zoom-in": setFontSize(fontSize + 1)
        case "zoom-out": setFontSize(fontSize - 1)
        case "toggle-wrap":
            wraps.toggle()
            applyWrap()
        default: return false
        }
        return true
    }

    private func setFontSize(_ size: CGFloat) {
        let clamped = min(max(size, Self.fontSizes.lowerBound), Self.fontSizes.upperBound)
        guard clamped != fontSize else { return NSSound.beep() }
        fontSize = clamped
        applyFont()
        if !wraps { applyWrap() }
    }

    private func applyFont() {
        textView.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }

    private func applyWrap() {
        guard let textContainer = textView.textContainer else { return }
        textContainer.widthTracksTextView = wraps
        textView.autoresizingMask = wraps ? [.width] : []
        // A fixed width from the longest line rather than a view that resizes to fit: fitting needs the whole text
        // laid out to find its widest line, which froze the app for seconds on a 90 MB log.
        let width = wraps ? scrollView.contentSize.width : longestLineWidth() + 2 * textView.textContainerInset.width
        if !wraps { textContainer.size = NSSize(width: width - 2 * textView.textContainerInset.width, height: .greatestFiniteMagnitude) }
        textView.setFrameSize(NSSize(width: width, height: textView.frame.height))
        textView.sizeToFit()  // the height for the new line breaks; non-contiguous layout estimates it
    }

    /// An upper bound on the widest line in the monospaced font, so unwrapped text needs no full layout to size the
    /// view. Non-ASCII characters count double (CJK is twice as wide) and tabs as a full tab stop.
    private func longestLineWidth() -> CGFloat {
        let advance = ("0" as NSString).size(withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)]).width
        let tabUnits = Int(ceil(NSParagraphStyle.default.defaultTabInterval / advance))
        let units = longestLineUnits ?? Self.longestLineUnits(in: textView.textStorage?.mutableString ?? "", tabUnits: tabUnits)
        longestLineUnits = units
        return CGFloat(units + 2) * advance
    }

    private static func longestLineUnits(in text: NSString, tabUnits: Int) -> Int {
        var longest = 0, current = 0
        let chunk = 65_536
        var buffer = [unichar](repeating: 0, count: chunk)
        var location = 0
        while location < text.length {
            let length = min(chunk, text.length - location)
            text.getCharacters(&buffer, range: NSRange(location: location, length: length))
            for unit in buffer[..<length] {
                switch unit {
                case 0x0A, 0x0D:
                    longest = max(longest, current)
                    current = 0
                case 0x09: current += tabUnits
                case 0..<0x80: current += 1
                default: current += 2
                }
            }
            location += length
        }
        return max(longest, current)
    }

    /// The text, with a slim note bar above it when there's a note, such as the read-only notice.
    private func layOut() {
        noteLabel.font = .systemFont(ofSize: 11)
        noteLabel.textColor = .secondaryLabelColor
        noteLabel.lineBreakMode = .byTruncatingTail
        for view in [noteLabel, scrollView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            root.addSubview(view)
        }
        scrollBelowNote = scrollView.topAnchor.constraint(equalTo: noteLabel.bottomAnchor, constant: 5)
        scrollAtTop = scrollView.topAnchor.constraint(equalTo: root.topAnchor)
        NSLayoutConstraint.activate([
            noteLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 10),
            noteLabel.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -10),
            noteLabel.topAnchor.constraint(equalTo: root.safeAreaLayoutGuide.topAnchor, constant: 5),
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])
    }
}
