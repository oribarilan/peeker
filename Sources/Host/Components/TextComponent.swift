import AppKit

/// Plain text in a native text view: system monospaced font, find bar, wrap toggle and zoom.
///
/// TextKit 1 with non-contiguous layout, not TextKit 2: TextKit 2 gives every line fragment its own view and
/// registers the scroll view with the titlebar's edge effect, which kept a warm Space on a 10 KB file near 30 ms
/// (TextKit 1: under 20). It also placed find results screens away from the match in a 90 MB log.
final class TextComponent: NSObject, Component, NSTextViewDelegate {
    private let scrollView = NSScrollView()
    /// Owns the layout manager and text container; a TextKit 1 text view doesn't retain its storage.
    private let storage = NSTextStorage()
    private var textView: NSTextView { scrollView.documentView as! NSTextView }
    private let container: NSView
    private let noteLabel: NSTextField?
    private var fontSize = TextComponent.defaultFontSize
    private var wraps = true
    /// Cached for unwrapped text; nil until wrap is first turned off, and after the text changes.
    private var longestLineUnits: Int?
    /// The text as last loaded or saved.
    private var baseline: String
    var onEdit: (() -> Void)?

    private static let defaultFontSize: CGFloat = 12
    private static let fontSizes: ClosedRange<CGFloat> = 6...72

    init(text: String, editable: Bool, note: String?) {
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
        noteLabel = note.map { NSTextField(labelWithString: $0) }
        container = noteLabel.map { [scrollView] in Self.container(note: $0, above: scrollView) } ?? scrollView
        baseline = text
        super.init()
        textView.delegate = self
        textView.isEditable = editable
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
        textView.string = text
    }

    var view: NSView { container }
    var note: String? { noteLabel?.stringValue }
    var isEditable: Bool { textView.isEditable }
    var focusView: NSView? { textView }

    /// Replaces the text with a reloaded version, keeping the scroll position. The undo history refers to the old
    /// text, so it goes.
    func update(text: String) {
        let origin = scrollView.contentView.bounds.origin
        baseline = text
        textView.string = text
        textView.undoManager?.removeAllActions()
        longestLineUnits = nil
        if !wraps { applyWrap() }
        scrollView.contentView.scroll(to: origin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    /// Changes the note's text, such as the size in "Showing the first 16 MB of …" as a log grows. A component made
    /// without a note has no bar to change.
    func setNote(_ note: String) {
        noteLabel?.stringValue = note
    }

    /// Carries zoom, wrap and scroll over from the component this one replaces.
    func takeViewState(from old: TextComponent) {
        fontSize = old.fontSize
        wraps = old.wraps
        applyFont()
        if !wraps { applyWrap() }
        scrollView.layoutSubtreeIfNeeded()
        scrollView.contentView.scroll(to: old.scrollView.contentView.bounds.origin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    func textDidChange(_ notification: Notification) {
        onEdit?()
    }

    func pendingEdits() -> Edits? {
        guard isEditable else { return nil }
        let text = textView.string
        // A literal comparison: String == treats canonically equivalent text as equal, which would drop such an edit.
        return (text as NSString).isEqual(to: baseline) ? nil : .text(text)
    }

    /// Replaces the whole text as one undoable change.
    func restore(_ edits: Edits) {
        guard case .text(let text) = edits else { return }
        let range = NSRange(location: 0, length: storage.length)
        guard textView.shouldChangeText(in: range, replacementString: text) else { return }
        textView.replaceCharacters(in: range, with: text)
        textView.didChangeText()
    }

    func revertEdits() {
        update(text: baseline)
    }

    func didSave(_ saved: Edits) {
        if case .text(let text) = saved { baseline = text }
    }

    func perform(_ verb: String) -> Bool {
        switch verb {
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

    /// The text with a slim note bar above it, such as the read-only notice.
    private static func container(note label: NSTextField, above scrollView: NSScrollView) -> NSView {
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byTruncatingTail
        let container = NSView()
        for view in [label, scrollView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(view)
        }
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -10),
            label.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor, constant: 5),
            scrollView.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 5),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }
}
