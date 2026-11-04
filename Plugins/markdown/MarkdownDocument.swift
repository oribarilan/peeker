import AppKit
import PeekerKit

/// A Markdown file rendered with native text, with an outline: the Peek panel's view, which only views.
final class MarkdownDocument: NSObject, PluginDocument, NSTextViewDelegate {
    private let url: URL
    private let scrollView = ThemedFindTextView.scrollableTextView()
    private let textView: NSTextView
    private(set) var anchors: [Int: Int] = [:]
    /// Counts renders, so a tail scheduled by an older one is dropped.
    private var renders = 0
    private(set) var outline: [OutlineItem] = []
    private(set) var info: [InfoRow] = []
    private var blocks: [MarkdownBlock] = []
    let pictures: MarkdownPictures
    private var images: [String: LocalImage] = [:]

    init(url: URL, parsed: MarkdownPlugin.Parsed) {
        self.url = url
        textView = scrollView.documentView as! NSTextView  // what scrollableTextView() always holds
        pictures = MarkdownPictures(textView: textView)
        super.init()
        pictures.onFallback = { [weak self] location, delta in
            guard let self else { return }
            for (line, anchor) in anchors where anchor > location { anchors[line] = anchor + delta }
        }
        textView.isEditable = false
        textView.delegate = self
        textView.textContainerInset = NSSize(width: 28, height: 22)
        applyThemeColors()
        apply(parsed)
        // Selector-based, so the observation ends with the document.
        NotificationCenter.default.addObserver(self, selector: #selector(themeChanged), name: TextTheme.didChange, object: nil)
    }

    isolated deinit {
        pictures.cancel()
    }

    @objc private func themeChanged() {
        applyThemeColors()
        update(blocks: blocks)
    }

    private func applyThemeColors() {
        let theme = TextTheme.current
        scrollView.appearance = TextTheme.appearance
        textView.backgroundColor = theme.background
        textView.selectedTextAttributes = [.backgroundColor: theme.selection]
        textView.linkTextAttributes = [.foregroundColor: theme.link, .cursor: NSCursor.pointingHand]
    }

    var contentView: NSView { scrollView }
    var focusView: NSView? { textView }
    var renderedText: String { textView.string }

    /// The document rendered in the system colors, printed in the light appearance, whatever the theme.
    var printJob: ((NSPrintInfo) -> NSPrintOperation?)? {
        { [blocks, url] info in
            TextPrinting.job(for: MarkdownPictures.printText(blocks, folder: url.deletingLastPathComponent(), info: info), info: info)
        }
    }

    func makeSidebar() -> [SidebarPanel] {
        var panels: [SidebarPanel] = []
        if !outline.isEmpty {
            panels.append(SidebarPanel(OutlineList(items: outline) { [weak self] in self?.scroll(toLine: $0) }, sizing: .fill))
        }
        if let info = InfoPanel.make(info) { panels.append(info) }
        return panels
    }

    func reload() async throws(PluginError) -> Bool {
        apply(try await MarkdownPlugin.parse(url))
        return true
    }

    private func apply(_ parsed: MarkdownPlugin.Parsed) {
        outline = parsed.outline
        info = parsed.info
        blocks = parsed.blocks
        images = parsed.images
        update(blocks: parsed.blocks)
    }

    /// Blocks drawn before the first paint; the rest are appended on the next run loop turn, the way Preview
    /// shows the first pages of a long PDF before the rest.
    private static let firstPaintBlocks = 150

    private func update(blocks: [MarkdownBlock]) {
        renders += 1
        let render = renders
        let visible = scrollView.contentView.bounds.origin
        let theme = TextTheme.current
        let shown = pictures.usable(images)
        let head = MarkdownRenderer.render(blocks.prefix(Self.firstPaintBlocks), theme: theme, images: shown)
        anchors = head.anchors
        textView.textStorage?.setAttributedString(head.text)
        scrollView.contentView.scroll(to: visible)
        // Pictures decode after the text shows, which already holds their space.
        pictures.start(shown)
        guard blocks.count > Self.firstPaintBlocks else { return }
        // One frame later, so the first screen is drawn and shown before the rest is laid out.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.016) { [weak self] in
            guard let self, renders == render, let storage = textView.textStorage else { return }
            let tail = MarkdownRenderer.render(blocks.dropFirst(Self.firstPaintBlocks), theme: theme, images: pictures.usable(images), leadingBreak: true)
            let offset = storage.length  // not the head's length: a picture that failed to decode changed it
            storage.append(tail.text)
            for (line, location) in tail.anchors { anchors[line] = location + offset }
            pictures.fill()
            scrollView.contentView.scroll(to: visible)
        }
    }

    private func scroll(toLine line: Int) {
        guard let location = anchors[line] else { return }
        textView.scrollRangeToVisible(NSRange(location: location, length: 0))
        textView.showFindIndicator(for: NSRange(location: location, length: 1))
    }

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        guard let url = link as? URL else { return false }
        LinkOpener.open(url, from: scrollView.window)
        return true
    }
}
