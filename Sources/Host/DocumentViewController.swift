import AppKit

/// A plugin command as declared in its reply.
struct CommandSpec {
    let id: String
    let title: String
    let symbol: String?
    let shortcut: Shortcut?
    /// Handled by the host component without asking the plugin.
    let verb: String?

    init?(_ spec: [String: Any]) {
        guard let id = spec["id"] as? String, let title = spec["title"] as? String else { return nil }
        self.id = id
        self.title = title
        symbol = spec["symbol"] as? String
        shortcut = (spec["shortcut"] as? String).flatMap(Shortcut.init(parsing:))
        verb = spec["verb"] as? String
    }
}

/// One open file, shown by one plugin. Used by both document windows and the quick-look panel.
final class DocumentViewController: NSSplitViewController {
    let url: URL
    let entry: PluginEntry
    private let process: PluginProcess
    private let config: Config
    private let docID = UUID().uuidString
    private let content = HolderViewController()
    private var sidebarItem: NSSplitViewItem?
    private var component: Component?
    private var opened = ContinuousClock.now
    private var pluginWasRunning = false
    private var isReady = false
    /// Time from `load()` until the plugin's reply arrived, before the host drew anything.
    private(set) var replyDuration: Duration = .zero
    private(set) var commands: [(spec: CommandSpec, shortcut: Shortcut?)] = []

    /// First content on screen: time since `load()`, and whether the plugin process was already running.
    var onReady: ((DocumentViewController, Duration, Bool) -> Void)?
    var onFailure: ((DocumentViewController, String) -> Void)?
    var onCommandsChanged: ((DocumentViewController) -> Void)?

    init(url: URL, entry: PluginEntry, process: PluginProcess, config: Config) {
        self.url = url
        self.entry = entry
        self.process = process
        self.config = config
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        addSplitViewItem(NSSplitViewItem(viewController: content))
    }

    /// Pixel size the image plugin should decode to: the largest screen, so fit-to-window stays sharp.
    private static var maxPixels: Int {
        let screens = NSScreen.screens.map { max($0.frame.width, $0.frame.height) * $0.backingScaleFactor }
        return Int(screens.max() ?? 2048)
    }

    func load() {
        opened = .now
        isReady = false
        pluginWasRunning = process.isRunning
        process.attach(docID) { [weak self] message in self?.fail(message) }
        process.request("open", ["doc": docID, "path": url.path, "maxPixels": Self.maxPixels]) { [weak self] result in
            guard let self else { return }
            self.replyDuration = .now - self.opened
            self.handle(result)
        }
    }

    func run(_ spec: CommandSpec) {
        if let verb = spec.verb {
            if component?.perform(verb) != true { NSSound.beep() }
            return
        }
        send(command: spec.id, args: [:])
    }

    func close() {
        process.notify("close", ["doc": docID])
        process.detach(docID)
    }

    private func send(command: String, args: [String: Any]) {
        process.request("command", ["doc": docID, "command": command, "args": args]) { [weak self] result in
            self?.handle(result)
        }
    }

    private func handle(_ result: Result<[String: Any], PluginProcess.Failure>) {
        switch result {
        case .failure(let failure): fail(failure.message)
        case .success(let reply): apply(reply)
        }
    }

    private func apply(_ reply: [String: Any]) {
        do {
            if let node = reply["view"] as? [String: Any] { try install(node) }
        } catch {
            fail("The \(entry.manifest.name) plugin sent something the app can't show.")
            return
        }
        if let panels = reply["sidebar"] as? [[String: Any]] { installSidebar(panels) }
        if let specs = reply["commands"] as? [[String: Any]] {
            commands = specs.compactMap(CommandSpec.init).map { ($0, config.keys["\(entry.id).\($0.id)"] ?? $0.shortcut) }
            onCommandsChanged?(self)
        }
        markReady()
    }

    private func install(_ node: [String: Any]) throws {
        switch node["type"] as? String {
        case "markdown":
            let blocks = node["blocks"] as? [[String: Any]] ?? []
            if let markdown = component as? MarkdownComponent {
                markdown.update(blocks: blocks)
                return
            }
            let markdown = MarkdownComponent(blocks: blocks)
            markdown.onToggleTask = { [weak self] line in self?.send(command: "toggle-task", args: ["line": line]) }
            setComponent(markdown)
        case "pdf":
            // A plugin may only point the host at the file it was asked to open.
            guard let path = node["path"] as? String, URL(filePath: path).standardizedFileURL == url.standardizedFileURL else {
                throw CocoaError(.fileReadNoPermission)
            }
            setComponent(try PDFComponent(url: url))
        case "bitmap":
            setComponent(try BitmapComponent(node: node))
        default:
            throw CocoaError(.featureUnsupported)
        }
    }

    private func setComponent(_ new: Component) {
        component = new
        content.show(new.view)
    }

    private func installSidebar(_ panels: [[String: Any]]) {
        if let sidebarItem { removeSplitViewItem(sidebarItem) }
        sidebarItem = nil
        let onAnchor: (Int) -> Void = { [weak self] line in (self?.component as? MarkdownComponent)?.scroll(toLine: line) }
        guard let view = Sidebar.make(panels, component: component, onAnchor: onAnchor) else { return }
        let holder = HolderViewController()
        holder.loadViewIfNeeded()
        holder.show(view)
        let item = NSSplitViewItem(sidebarWithViewController: holder)
        item.minimumThickness = 170
        item.maximumThickness = 320
        insertSplitViewItem(item, at: 0)
        sidebarItem = item
    }

    /// Same rule for every plugin: ready once the window has drawn the content and the run loop has turned.
    private func markReady() {
        guard !isReady else { return }
        isReady = true
        view.window?.displayIfNeeded()
        DispatchQueue.main.async { self.onReady?(self, .now - self.opened, self.pluginWasRunning) }
    }

    private func fail(_ message: String) {
        component = nil
        let label = NSTextField(wrappingLabelWithString: message)
        label.alignment = .center
        label.textColor = .secondaryLabelColor
        let retry = NSButton(title: "Reopen", target: self, action: #selector(reopen))
        let stack = NSStackView(views: [label, retry])
        stack.orientation = .vertical
        stack.alignment = .centerX
        let container = NSView()
        container.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualTo: container.widthAnchor, constant: -40),
        ])
        content.show(container)
        if let sidebarItem { removeSplitViewItem(sidebarItem) }
        sidebarItem = nil
        onFailure?(self, message)
    }

    @objc private func reopen() {
        process.detach(docID)
        load()
    }
}
