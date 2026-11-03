import AppKit
import PeekerKit

/// A Markdown file in the Editor: its source, editable, styled as it's typed. TextKit 1 with non-contiguous layout,
/// like Plain Text's view, for the same speed reasons (see `TextDocument`).
final class MarkdownEditor: NSObject, PluginDocument, NSTextViewDelegate {
    private let url: URL
    private let scrollView = NSScrollView()
    /// Owns the layout manager and text container; a TextKit 1 text view doesn't retain its storage.
    private let storage = NSTextStorage()
    private let textView: MarkdownTextView
    /// The text as last loaded or saved.
    private var baseline: String
    private var format: TextFormat
    private var readOnlyReason: String?
    private var style: MarkdownStyle
    private var styled: Bool
    private var baseSize = MarkdownEditor.defaultSize
    /// Counts edits, so a restyle parsed from older text is dropped.
    private(set) var generation = 0
    private var pendingRestyle: DispatchWorkItem?
    var onEdit: (() -> Void)?
    var onSidebarChange: (() -> Void)?
    /// Opens a Cmd-clicked link; replaced in tests.
    var openLink: (String) -> Void

    static let defaultSize: CGFloat = 14
    private static let sizes: ClosedRange<CGFloat> = 8...48
    /// How long typing pauses before the source is parsed and styled again.
    static let restyleDelay: TimeInterval = 0.15

    init(url: URL, source: MarkdownPlugin.Source) {
        self.url = url
        baseline = source.file.text
        format = source.file.format
        readOnlyReason = source.file.editable ? nil : source.file.note ?? TextFile.readOnlyNote
        style = source.style
        styled = source.styled
        let layoutManager = NSLayoutManager()
        layoutManager.allowsNonContiguousLayout = true
        storage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)
        textView = MarkdownTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 400), textContainer: textContainer)
        openLink = { _ in }
        super.init()
        openLink = { [weak self] in LinkOpener.open($0, from: self?.scrollView.window) }
        textView.isVerticallyResizable = true
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        textView.autoresizingMask = [.width]
        textView.delegate = self
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        // Each of these would rewrite the user's Markdown.
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.textContainerInset = NSSize(width: 28, height: 22)
        textView.isEditable = readOnlyReason == nil
        textView.onClick = { [weak self] index, command in self?.click(at: index, command: command) ?? false }
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        storage.setAttributedString(NSAttributedString(string: source.file.text, attributes: baseAttributes))
        applyTheme()
        // Selector-based, so the observation ends with the document.
        NotificationCenter.default.addObserver(self, selector: #selector(applyTheme), name: TextTheme.didChange, object: nil)
    }

    /// The theme's colors for the view, in the text appearance, then a style pass for the text's.
    @objc private func applyTheme() {
        let theme = TextTheme.current
        scrollView.appearance = TextTheme.appearance
        textView.backgroundColor = theme.background
        textView.insertionPointColor = theme.cursor
        textView.selectedTextAttributes = [.backgroundColor: theme.selection]
        applyStyle()
    }

    var contentView: NSView { scrollView }
    var focusView: NSView? { textView }
    var text: String { textView.string }
    var tools: [ToolSpec] { MarkdownPlugin.tools }
    var editability: Editability { readOnlyReason.map { .readOnly($0) } ?? .editable }
    var info: [InfoRow] { MarkdownPlugin.info(words: style.words, tasks: style.tasks) }
    var outline: [OutlineItem] { style.outline }
    /// The text view's attributes at `location`, for tests.
    func attributes(at location: Int) -> [NSAttributedString.Key: Any] { storage.attributes(at: location, effectiveRange: nil) }

    func makeSidebar() -> [SidebarPanel] {
        var panels: [SidebarPanel] = []
        if !outline.isEmpty {
            panels.append(SidebarPanel(OutlineList(items: outline) { [weak self] in self?.jump(toLine: $0) }, sizing: .fill))
        }
        if let info = InfoPanel.make(info) { panels.append(info) }
        return panels
    }

    /// The current text rendered as the Peek panel shows it, printed in the light appearance.
    var printJob: ((NSPrintInfo) -> NSPrintOperation?)? {
        { [weak self] info in self.flatMap { TextPrinting.job(for: $0.printText, info: info) } }
    }

    var printText: NSAttributedString { MarkdownRenderer.render(MarkdownTree.blocks(from: textView.string), theme: .system).text }

    // MARK: Editing

    func unsavedEdits() -> UnsavedEdits? {
        guard readOnlyReason == nil else { return nil }
        // A literal comparison: String == treats canonically equivalent text as equal, which would drop such an edit.
        return (textView.string as NSString).isEqual(to: baseline) ? nil : UnsavedEdits(TextEdits.text(textView.string))
    }

    /// Replaces the whole text as one undoable change.
    func restore(encoded edits: Data) -> Bool {
        guard readOnlyReason == nil, let text = (try? JSONDecoder().decode(TextEdits.self, from: edits))?.text else { return false }
        return replace(NSRange(location: 0, length: storage.length), with: text)
    }

    func save(_ edits: UnsavedEdits, accepting offer: SaveOffer?) async throws(PluginError) {
        guard readOnlyReason == nil, let text = (edits.value as? TextEdits)?.text else { throw PluginError(readOnlyReason ?? TextFile.readOnlyNote) }
        let target = offer == TextFile.saveAsUTF8 ? TextFormat(encoding: .utf8, hasBOM: false, lineEnding: format.lineEnding) : format
        // Bytes, not String ==; unchanged text writes nothing, so a file with mixed line endings stays as it is.
        guard target != format || Data(text.utf8) != Data(baseline.utf8) else {
            baseline = text
            return
        }
        _ = try await TextFile.write(text, as: target, to: url.path)
        format = target
        baseline = text
    }

    func revertEdits() { show(baseline) }

    /// Shows the file as it is on disk now, keeping the scroll position and zoom; typing that started meanwhile wins.
    func reload() async throws(PluginError) -> Bool {
        let source = try await MarkdownPlugin.load(url)
        guard unsavedEdits() == nil else { return true }
        format = source.file.format
        guard (source.file.editable ? nil : source.file.note ?? TextFile.readOnlyNote) == readOnlyReason else { return false }  // reopen to show or drop the note
        style = source.style
        styled = source.styled
        show(source.file.text)
        return true
    }

    func textDidChange(_ notification: Notification) {
        generation += 1
        onEdit?()
        guard styled else { return }
        pendingRestyle?.cancel()
        let work = DispatchWorkItem { [weak self] in Task { await self?.restyle() } }
        pendingRestyle = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.restyleDelay, execute: work)
    }

    /// Parses the current text off the main thread and styles it, unless it changed meanwhile. Above
    /// `MarkdownLimits.styledBytes` nothing runs, so typing in a large file never parses it.
    func restyle() async {
        guard styled else { return }
        let text = textView.string, started = generation
        apply(await Self.parse(text), parsedAt: started)
    }

    /// Shows a parse of the text as it was at `generation`; dropped when the text changed since.
    func apply(_ parsed: MarkdownStyle, parsedAt started: Int) {
        guard started == generation else { return }
        let sidebarChanged = parsed.outline != style.outline || parsed.words != style.words || parsed.tasks != style.tasks
        style = parsed
        applyStyle()
        if sidebarChanged { onSidebarChange?() }
    }

    @concurrent nonisolated private static func parse(_ text: String) async -> MarkdownStyle { MarkdownStyler.style(text) }

    /// Replaces `range` as one undoable edit, as typing would.
    @discardableResult private func replace(_ range: NSRange, with text: String) -> Bool {
        guard textView.shouldChangeText(in: range, replacementString: text) else { return false }
        textView.replaceCharacters(in: range, with: text)
        textView.didChangeText()
        return true
    }

    /// Replaces the text with a reloaded or reverted version. The undo history refers to the old text, so it goes.
    private func show(_ text: String) {
        let origin = scrollView.contentView.bounds.origin
        baseline = text
        generation += 1
        storage.setAttributedString(NSAttributedString(string: text, attributes: baseAttributes))
        textView.undoManager?.removeAllActions()
        applyStyle()
        onSidebarChange?()
        scrollView.contentView.scroll(to: origin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    // MARK: Clicks

    /// A plain click on a task box flips it; a Cmd-click on a link opens it. Returns whether the click was used.
    func click(at index: Int, command: Bool) -> Bool {
        if command, let link = style.links.first(where: { NSLocationInRange(index, $0.range) }) {
            openLink(link.destination)
            return true
        }
        guard !command, readOnlyReason == nil, let box = style.taskBoxes.first(where: { NSLocationInRange(index, $0) }),
              NSMaxRange(box) <= storage.length else { return false }
        let mark = NSRange(location: box.location + 1, length: 1)
        replace(mark, with: (storage.string as NSString).substring(with: mark) == " " ? "x" : " ")
        return true
    }

    /// Puts the cursor at the start of a 1-based source line and shows it.
    func jump(toLine line: Int) {
        let starts = MarkdownStyler.lineStarts(in: textView.string)
        guard starts.indices.contains(line - 1) else { return }
        let range = NSRange(location: starts[line - 1], length: 0)
        textView.setSelectedRange(range)
        textView.scrollRangeToVisible(range)
        textView.window?.makeFirstResponder(textView)
        if range.location < storage.length { textView.showFindIndicator(for: NSRange(location: range.location, length: 1)) }
    }

    // MARK: Zoom

    func perform(_ id: String) -> Bool {
        switch id {
        case "zoom-in": setSize(baseSize + 1)
        case "zoom-out": setSize(baseSize - 1)
        default: return false
        }
        return true
    }

    private func setSize(_ size: CGFloat) {
        let clamped = min(max(size, Self.sizes.lowerBound), Self.sizes.upperBound)
        guard clamped != baseSize else { return NSSound.beep() }
        baseSize = clamped
        applyStyle()
        let cursor = textView.selectedRange().location
        if storage.length > 0 { textView.typingAttributes = storage.attributes(at: min(max(cursor - 1, 0), storage.length - 1), effectiveRange: nil) }
    }

    // MARK: Styling

    private var bodyFont: NSFont { .systemFont(ofSize: baseSize) }
    private var baseAttributes: [NSAttributedString.Key: Any] { [.font: bodyFont, .foregroundColor: TextTheme.current.text] }
    private static let headingScales: [CGFloat] = [1.7, 1.45, 1.25, 1.1, 1, 0.95]

    /// Sets every attribute from the base and the last parse, in one batch. Attribute changes made on the storage
    /// don't enter the undo stack or count as edits.
    private func applyStyle() {
        let whole = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.setAttributes(baseAttributes, range: whole)
        if styled {
            let theme = TextTheme.current
            for run in style.runs where NSMaxRange(run.range) <= storage.length { apply(run, theme) }
        }
        storage.endEditing()
        // Otherwise typing takes the style of the text before the cursor, so a heading keeps its size as it grows.
        if storage.length == 0 { textView.typingAttributes = baseAttributes }
    }

    private func apply(_ run: StyleRun, _ theme: TextTheme) {
        let range = run.range
        switch run.kind {
        case .heading(let level):
            storage.addAttributes([.font: NSFont.systemFont(ofSize: (baseSize * Self.headingScales[level - 1]).rounded(), weight: .bold),
                                   .foregroundColor: theme.heading], range: range)
        case .strong: addTrait(.boldFontMask, in: range)
        case .emphasis: addTrait(.italicFontMask, in: range)
        case .strikethrough: storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        case .code, .codeBlock:
            storage.addAttributes([.font: NSFont.monospacedSystemFont(ofSize: baseSize - 1.5, weight: .regular),
                                   .backgroundColor: theme.codeBackground], range: range)
        case .link: storage.addAttribute(.foregroundColor, value: theme.link, range: range)
        case .taskBox, .marker: storage.addAttribute(.foregroundColor, value: theme.marker, range: range)
        case .quote: break  // its > markers are dimmed; the quoted text stays readable
        }
    }

    private func addTrait(_ trait: NSFontTraitMask, in range: NSRange) {
        storage.enumerateAttribute(.font, in: range) { value, part, _ in
            guard let font = value as? NSFont else { return }
            storage.addAttribute(.font, value: NSFontManager.shared.convert(font, toHaveTrait: trait), range: part)
        }
    }
}

/// Hands clicks to the editor first, so a task box flips and a Cmd-click opens a link; anything else, including a
/// plain click on a link, places the cursor as usual.
final class MarkdownTextView: ThemedFindTextView {
    var onClick: ((Int, Bool) -> Bool)?

    override func mouseDown(with event: NSEvent) {
        guard event.clickCount == 1, let layoutManager, let textContainer else { return super.mouseDown(with: event) }
        var point = convert(event.locationInWindow, from: nil)
        point.x -= textContainerOrigin.x
        point.y -= textContainerOrigin.y
        let glyph = layoutManager.glyphIndex(for: point, in: textContainer)
        guard layoutManager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: textContainer).contains(point) else {
            return super.mouseDown(with: event)
        }
        let index = layoutManager.characterIndexForGlyph(at: glyph)
        if onClick?(index, event.modifierFlags.contains(.command)) != true { super.mouseDown(with: event) }
    }
}
