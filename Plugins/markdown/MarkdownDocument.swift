import AppKit
import PeekerKit

/// A Markdown file rendered with native text, with an outline and task checkboxes that tick straight into the file.
final class MarkdownDocument: NSObject, PluginDocument, NSTextViewDelegate {
    private let url: URL
    private let scrollView = NSTextView.scrollableTextView()
    private let textView: NSTextView
    private var anchors: [Int: Int] = [:]
    /// Counts renders, so a tail scheduled by an older one is dropped.
    private var renders = 0
    private(set) var outline: [OutlineItem] = []
    private(set) var info: [InfoRow] = []

    init(url: URL, parsed: MarkdownPlugin.Parsed) {
        self.url = url
        textView = scrollView.documentView as! NSTextView  // what scrollableTextView() always holds
        super.init()
        textView.isEditable = false
        textView.delegate = self
        textView.textContainerInset = NSSize(width: 28, height: 22)
        textView.usesFindBar = true
        textView.linkTextAttributes = [.foregroundColor: NSColor.linkColor, .cursor: NSCursor.pointingHand]
        apply(parsed)
    }

    var contentView: NSView { scrollView }
    var focusView: NSView? { textView }
    var renderedText: String { textView.string }

    /// The rendered text, printed in the light appearance.
    var printJob: ((NSPrintInfo) -> NSPrintOperation?)? {
        { [textView] info in TextPrinting.job(for: NSAttributedString(attributedString: textView.attributedString()), info: info) }
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

    /// Ticks or unticks the task on a 1-based source line, in the file at once, then shows the result. Not an edit:
    /// nothing is left to save.
    func toggleTask(atLine line: Int) async throws(PluginError) {
        try await MarkdownPlugin.toggleTask(atLine: line, in: url)
        apply(try await MarkdownPlugin.parse(url))
    }

    private func apply(_ parsed: MarkdownPlugin.Parsed) {
        outline = parsed.outline
        info = parsed.info
        update(blocks: parsed.blocks)
    }

    /// Blocks drawn before the first paint; the rest are appended on the next run loop turn, the way Preview
    /// shows the first pages of a long PDF before the rest.
    private static let firstPaintBlocks = 150

    private func update(blocks: [MarkdownBlock]) {
        renders += 1
        let render = renders
        let visible = scrollView.contentView.bounds.origin
        let head = MarkdownRenderer.render(blocks.prefix(Self.firstPaintBlocks))
        anchors = head.anchors
        textView.textStorage?.setAttributedString(head.text)
        scrollView.contentView.scroll(to: visible)
        guard blocks.count > Self.firstPaintBlocks else { return }
        let offset = head.text.length
        // One frame later, so the first screen is drawn and shown before the rest is laid out.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.016) { [weak self] in
            guard let self, renders == render else { return }
            let tail = MarkdownRenderer.render(blocks.dropFirst(Self.firstPaintBlocks), leadingBreak: true)
            self.textView.textStorage?.append(tail.text)
            for (line, location) in tail.anchors { self.anchors[line] = location + offset }
            self.scrollView.contentView.scroll(to: visible)
        }
    }

    private func scroll(toLine line: Int) {
        guard let location = anchors[line] else { return }
        textView.scrollRangeToVisible(NSRange(location: location, length: 0))
        textView.showFindIndicator(for: NSRange(location: location, length: 1))
    }

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        guard let url = link as? URL else { return false }
        guard url.scheme == MarkdownRenderer.taskScheme, let line = Int(url.host() ?? "") else {
            NSWorkspace.shared.open(url)
            return true
        }
        Task {
            do throws(PluginError) {
                try await toggleTask(atLine: line)
            } catch {
                report(error)
            }
        }
        return true
    }

    private func report(_ error: PluginError) {
        let alert = NSAlert()
        alert.messageText = "Couldn't tick the task"
        alert.informativeText = error.message
        if let window = scrollView.window { alert.beginSheetModal(for: window) } else { alert.runModal() }
    }
}
