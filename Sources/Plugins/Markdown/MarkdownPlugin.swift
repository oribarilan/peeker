import AppKit
import PreviewPPKit
import UniformTypeIdentifiers

public final class MarkdownPlugin: Plugin {
    public static let manifest = PluginManifest(
        id: "markdown",
        name: "Markdown",
        fileTypes: [UTType("net.daringfireball.markdown") ?? UTType(importedAs: "net.daringfireball.markdown")]
    )

    public init() {}

    public func open(_ url: URL, host: any PluginHost) throws -> Viewer {
        guard let source = try? String(contentsOf: url, encoding: .utf8) else { throw PluginError.unreadable(url) }
        let controller = MarkdownViewController(url: url, source: source)
        return Viewer(content: controller, commands: [
            Command(id: "toggle-source", title: "Toggle Source", symbolName: "chevron.left.forwardslash.chevron.right", shortcut: Shortcut("e")) {
                controller.toggleSource()
            },
            Command(id: "save", title: "Save", symbolName: "square.and.arrow.down", shortcut: Shortcut("s")) {
                controller.save()
            },
        ])
    }
}

/// Rendered view by default; quick edits either by ticking a task checkbox or by toggling to the source.
final class MarkdownViewController: NSViewController, NSTextViewDelegate {
    private let url: URL
    private var source: String
    private let rendered = NSTextView.scrollableTextView()
    private let editor = NSTextView.scrollableTextView()
    private var showingSource = false

    private var renderedView: NSTextView { rendered.documentView as! NSTextView }
    private var editorView: NSTextView { editor.documentView as! NSTextView }

    init(url: URL, source: String) {
        self.url = url
        self.source = source
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func loadView() {
        renderedView.isEditable = false
        renderedView.delegate = self
        renderedView.textContainerInset = NSSize(width: 24, height: 20)
        renderedView.usesFindBar = true
        editorView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        editorView.isRichText = false
        editorView.allowsUndo = true
        editorView.usesFindBar = true
        editorView.textContainerInset = NSSize(width: 12, height: 12)
        editor.isHidden = true
        let container = NSView()
        for scrollView in [rendered, editor] {
            container.addSubview(scrollView)
            scrollView.frame = container.bounds
            scrollView.autoresizingMask = [.width, .height]
        }
        view = container
        render()
    }

    func toggleSource() {
        if showingSource {
            source = editorView.string
            render()
        } else {
            editorView.string = source
        }
        showingSource.toggle()
        editor.isHidden = !showingSource
        rendered.isHidden = showingSource
        view.window?.makeFirstResponder(showingSource ? editorView : renderedView)
    }

    func save() {
        if showingSource { source = editorView.string }
        write()
        render()
    }

    private func write() {
        do {
            try source.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            presentError(error)
        }
    }

    private func render() {
        renderedView.textStorage?.setAttributedString(MarkdownRenderer.render(source))
    }

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        guard let url = link as? URL else { return false }
        if url.scheme == MarkdownRenderer.taskScheme, let index = Int(url.host() ?? "") {
            source = MarkdownRenderer.toggleTask(at: index, in: source)
            write()
            let visible = rendered.contentView.bounds.origin
            render()
            rendered.contentView.scroll(to: visible)
            return true
        }
        NSWorkspace.shared.open(url)
        return true
    }
}

/// Renders Foundation's Markdown parse (block-level `PresentationIntent`) into an attributed string.
enum MarkdownRenderer {
    static let taskScheme = "ppp-task"
    private static let taskPattern = /^(\s*(?:[-*+]|\d+[.)])\s+)\[([ xX])\]/

    static func render(_ source: String) -> NSAttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            allowsExtendedAttributes: true,
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        guard let parsed = try? AttributedString(markdown: source, options: options) else {
            return NSAttributedString(string: source)
        }

        let out = NSMutableAttributedString()
        var lastBlock: Int?
        var lastRow: Int?
        var lastListItem: Int?
        var taskIndex = 0

        for run in parsed.runs {
            let components = run.presentationIntent?.components ?? []
            let block = components.first?.identity
            let row = components.first { if case .tableRow = $0.kind { true } else { false } }?.identity
            if let lastBlock, block != lastBlock {
                out.append(NSAttributedString(string: row != nil && row == lastRow ? "\t" : "\n"))
            }
            lastBlock = block
            lastRow = row

            var text = String(parsed[run.range].characters)
            var attributes = blockAttributes(for: components)
            applyInline(run.inlinePresentationIntent, to: &attributes)
            if let link = run.link { attributes[.link] = link }

            if let item = components.first(where: { if case .listItem = $0.kind { true } else { false } }), item.identity != lastListItem {
                lastListItem = item.identity
                out.append(NSAttributedString(string: listMarker(item: item, in: components), attributes: attributes))
                if let match = text.prefixMatch(of: /\[([ xX])\]\s/) {
                    let checked = match.1 != " "
                    var box = attributes
                    box[.link] = URL(string: "\(taskScheme)://\(taskIndex)")
                    out.append(NSAttributedString(string: checked ? "☑ " : "☐ ", attributes: box))
                    text.removeSubrange(match.range)
                    taskIndex += 1
                }
            }
            out.append(NSAttributedString(string: text, attributes: attributes))
        }
        return out
    }

    /// Flips the `index`-th task checkbox in the source, skipping fenced code blocks.
    static func toggleTask(at index: Int, in source: String) -> String {
        var lines = source.components(separatedBy: "\n")
        var inFence = false
        var seen = 0
        for i in lines.indices {
            if lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") { inFence.toggle() }
            guard !inFence, let match = lines[i].prefixMatch(of: taskPattern) else { continue }
            if seen == index {
                lines[i].replaceSubrange(match.range, with: "\(match.1)[\(match.2 == " " ? "x" : " ")]")
                break
            }
            seen += 1
        }
        return lines.joined(separator: "\n")
    }

    private static func listMarker(item: PresentationIntent.IntentType, in components: [PresentationIntent.IntentType]) -> String {
        let depth = components.filter { if case .listItem = $0.kind { true } else { false } }.count
        let indent = String(repeating: "    ", count: max(0, depth - 1))
        guard case .listItem(let ordinal) = item.kind else { return indent }
        let ordered = components.contains { if case .orderedList = $0.kind { true } else { false } }
        return indent + (ordered ? "\(ordinal). " : "•  ")
    }

    private static func blockAttributes(for components: [PresentationIntent.IntentType]) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.paragraphSpacing = 8
        paragraph.lineSpacing = 2
        var attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph,
        ]
        for component in components {
            switch component.kind {
            case .header(let level):
                let sizes: [CGFloat] = [26, 21, 18, 16, 14, 13]
                attributes[.font] = NSFont.systemFont(ofSize: sizes[min(level, 6) - 1], weight: .bold)
                paragraph.paragraphSpacingBefore = 10
            case .codeBlock:
                attributes[.font] = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
                attributes[.backgroundColor] = NSColor.quaternarySystemFill
            case .blockQuote:
                attributes[.foregroundColor] = NSColor.secondaryLabelColor
                paragraph.headIndent += 20
                paragraph.firstLineHeadIndent += 20
            case .tableCell(let column) where column == 0:
                attributes[.font] = NSFont.systemFont(ofSize: 13)
            case .thematicBreak:
                attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            default:
                break
            }
        }
        return attributes
    }

    private static func applyInline(_ intent: InlinePresentationIntent?, to attributes: inout [NSAttributedString.Key: Any]) {
        guard let intent, let base = attributes[.font] as? NSFont else { return }
        var traits: NSFontDescriptor.SymbolicTraits = []
        if intent.contains(.stronglyEmphasized) { traits.insert(.bold) }
        if intent.contains(.emphasized) { traits.insert(.italic) }
        if !traits.isEmpty {
            let descriptor = base.fontDescriptor.withSymbolicTraits(base.fontDescriptor.symbolicTraits.union(traits))
            attributes[.font] = NSFont(descriptor: descriptor, size: base.pointSize) ?? base
        }
        if intent.contains(.code) {
            attributes[.font] = NSFont.monospacedSystemFont(ofSize: base.pointSize - 1, weight: .regular)
            attributes[.backgroundColor] = NSColor.quaternarySystemFill
        }
        if intent.contains(.strikethrough) { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
    }
}
