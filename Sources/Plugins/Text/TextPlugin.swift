import AppKit
import PreviewPPKit
import UniformTypeIdentifiers

public final class TextPlugin: Plugin {
    public static let manifest = PluginManifest(id: "text", name: "Plain Text", fileTypes: [.plainText, .json])

    public init() {}

    public func open(_ url: URL, host: any PluginHost) throws -> Viewer {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { throw PluginError.unreadable(url) }
        let controller = TextViewController(text: String(decoding: data, as: UTF8.self))
        return Viewer(content: controller, commands: [
            Command(id: "save", title: "Save", symbolName: "square.and.arrow.down", shortcut: Shortcut("s")) {
                controller.save(to: url)
            },
            Command(id: "toggle-wrap", title: "Toggle Wrap", symbolName: "text.word.spacing", shortcut: Shortcut("w", [.command, .option])) {
                controller.toggleWrap()
            },
        ])
    }
}

final class TextViewController: NSViewController {
    private let text: String
    private var textView: NSTextView!
    private var wraps = true

    init(text: String) {
        self.text = text
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func loadView() {
        // PPP_TEXTKIT1 exists only for the POC benchmark comparing layout engines on huge files.
        let useTextKit1 = ProcessInfo.processInfo.environment["PPP_TEXTKIT1"] != nil
        let scrollView = useTextKit1 ? Self.textKit1ScrollView() : NSTextView.scrollableTextView()
        textView = scrollView.documentView as? NSTextView
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.string = text
        view = scrollView
    }

    private static func textKit1ScrollView() -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        let textView = NSTextView(usingTextLayoutManager: false)
        textView.layoutManager?.allowsNonContiguousLayout = true
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        scrollView.documentView = textView
        return scrollView
    }

    func save(to url: URL) {
        do {
            try textView.string.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            presentError(error)
        }
    }

    func toggleWrap() {
        wraps.toggle()
        guard let container = textView.textContainer, let scrollView = textView.enclosingScrollView else { return }
        scrollView.hasHorizontalScroller = !wraps
        textView.isHorizontallyResizable = !wraps
        container.widthTracksTextView = wraps
        if wraps {
            container.containerSize = NSSize(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)
            textView.frame.size.width = scrollView.contentSize.width
        } else {
            container.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
            textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        }
    }
}
