import AppKit
import PeekerKit

/// A data file: its text is the model, and the tree is a parse of it. Tree edits are text changes made through the
/// text view, so the text view's undo holds every edit, from either view.
final class DataDocument: NSObject, PluginDocument, NSTextViewDelegate {
    private(set) var url: URL
    private let allowsEditing: Bool
    private let preferences: PluginPreferences?
    private var format: TextFormat
    /// The text as last loaded or saved.
    private var baseline: String
    private var readOnlyReason: String?
    private(set) var info: [InfoRow]
    /// The parse of the text as it is now: a tree, or why it isn't one.
    private(set) var root: JSONNode?
    private(set) var error: JSONError?
    /// Whether the text shows instead of the tree, remembered for every data file.
    private(set) var showsText = false
    let undoManager = UndoManager()
    var onEdit: (() -> Void)?
    var onSidebarChange: (() -> Void)?

    private let container = NSView()
    private let errorBar = NSTextField(labelWithString: "")
    private let textScroll = NSScrollView()
    private let storage = NSTextStorage()
    let textView: ThemedFindTextView
    private var coloring: CodeColoring?
    private(set) lazy var tree = DataTreeView(document: self)
    private var pendingParse: DispatchWorkItem?
    /// Files whose text shows only in part get no tree: it would take about twelve times the file's size.
    private var textOnly = false
    static let textOnlyReason = "Files over 16 MB show as text only."
    private var textBelowBar: NSLayoutConstraint!
    private var textAtTop: NSLayoutConstraint!

    init(url: URL, loaded: DataPlugin.Loaded, allowsEditing: Bool, preferences: PluginPreferences?) {
        self.url = url
        self.allowsEditing = allowsEditing
        self.preferences = preferences
        format = loaded.file.format
        baseline = loaded.file.text
        readOnlyReason = loaded.file.editable ? nil : loaded.file.note ?? TextFile.readOnlyNote
        info = Self.info(loaded.file)
        // TextKit 1 with non-contiguous layout, as Plain Text uses, for speed on large files.
        let layoutManager = NSLayoutManager()
        layoutManager.allowsNonContiguousLayout = true
        storage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)
        textView = ThemedFindTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 400), textContainer: textContainer)
        super.init()
        textOnly = loaded.file.isPartial
        if !textOnly {
            switch loaded.parsed {
            case .success(let node): root = node
            case .failure(let failure): error = failure
            }
        }
        showsText = preferences?.bool("showsText") ?? false
        setUpViews(text: loaded.file.text)
        coloring = loaded.colors.map { CodeColoring($0, in: textView) }
        NotificationCenter.default.addObserver(self, selector: #selector(applyTheme), name: TextTheme.didChange, object: nil)
        // Undo and Redo change the text; the tree follows at once, so a tree edit never acts on an old parse.
        for name in [NSNotification.Name.NSUndoManagerDidUndoChange, .NSUndoManagerDidRedoChange] {
            NotificationCenter.default.addObserver(self, selector: #selector(undoneOrRedone), name: name, object: undoManager)
        }
    }

    @objc private func undoneOrRedone() { reparse() }

    static func info(_ file: TextFile.Loaded) -> [InfoRow] {
        [InfoRow(label: "Lines", value: file.lineCount.formatted()),
         InfoRow(label: "Encoding", value: String.localizedName(of: file.format.encoding) + (file.format.hasBOM ? " with BOM" : "")),
         InfoRow(label: "Size", value: ByteCountFormatter.string(fromByteCount: Int64(file.byteCount), countStyle: .file))]
    }

    // MARK: Views

    private func setUpViews(text: String) {
        textView.isVerticallyResizable = true
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        textView.autoresizingMask = [.width]
        textView.delegate = self
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.isEditable = isEditable
        textView.string = text
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textScroll.documentView = textView
        textScroll.hasVerticalScroller = true
        textScroll.autohidesScrollers = true
        errorBar.textColor = .white
        errorBar.backgroundColor = .systemRed
        errorBar.drawsBackground = true
        errorBar.lineBreakMode = .byTruncatingTail
        for view in [errorBar, textScroll, tree] {
            view.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(view)
        }
        // The bar sits under the toolbar; the text below it only while it shows, as Plain Text's note does.
        textBelowBar = textScroll.topAnchor.constraint(equalTo: errorBar.bottomAnchor)
        textAtTop = textScroll.topAnchor.constraint(equalTo: container.topAnchor)
        NSLayoutConstraint.activate([
            errorBar.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor),
            errorBar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            errorBar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            textAtTop,
            tree.topAnchor.constraint(equalTo: container.topAnchor),
        ] + [textScroll, tree].flatMap { view in [
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ] })
        applyTheme()
        showView()
    }

    /// The tree, or the text when chosen or when the text doesn't parse; the error bar with it.
    private func showView() {
        let text = showsText || root == nil
        textScroll.isHidden = !text
        tree.isHidden = text
        let message = error.map { "  Line \($0.line): \($0.message)" } ?? (textOnly ? "  " + Self.textOnlyReason : nil)
        errorBar.isHidden = message == nil
        errorBar.stringValue = message ?? ""
        errorBar.backgroundColor = error == nil ? .secondaryLabelColor : .systemRed
        textAtTop.isActive = message == nil
        textBelowBar.isActive = message != nil
        if !text { tree.reload() }
    }

    @objc private func applyTheme() {
        let theme = TextTheme.current
        textScroll.appearance = TextTheme.appearance
        textView.backgroundColor = theme.background
        textView.textColor = theme.text
        textView.insertionPointColor = theme.cursor
        textView.selectedTextAttributes = [.backgroundColor: theme.selection]
        coloring?.recolor()
    }

    var contentView: NSView { container }
    var focusView: NSView? { showsText || root == nil ? textView : tree.outlineView }
    var tools: [ToolSpec] { DataPlugin.tools }

    func makeSidebar() -> [SidebarPanel] {
        let list = DataOutlineList(items: (root?.children ?? []).map { $0.key ?? "\($0.index)" }) { [weak self] index in self?.go(toTopLevel: index) }
        return [SidebarPanel(list, sizing: .fill)] + (InfoPanel.make(info).map { [$0] } ?? [])
    }

    /// From the outline: the top-level item at `index`, selected in the tree or with the cursor on its line.
    func go(toTopLevel index: Int) {
        guard let node = root?.children[safe: index] else { return }
        if showsText || root == nil {
            let range = nsRange(node.start..<node.start)
            textView.setSelectedRange(range)
            textView.scrollRangeToVisible(range)
            textView.window?.makeFirstResponder(textView)
        } else {
            tree.select(node)
        }
    }

    // MARK: Editing state

    var editability: Editability {
        guard allowsEditing else { return .notEditable }
        return readOnlyReason.map(Editability.readOnly) ?? .editable
    }

    var isEditable: Bool { editability == .editable }
    var text: String { textView.string }

    func isOn(_ tool: String) -> Bool? { tool == "show-text" ? showsText || root == nil : nil }

    func unavailableReason(for tool: String) -> String? {
        if tool == "show-text", textOnly { return Self.textOnlyReason }
        if tool == "show-text", root == nil { return error.map { "Line \($0.line) has a problem; the tree shows once it's fixed." } }
        guard ["add-item", "add-child", "delete-item"].contains(tool) else { return nil }
        if showsText || root == nil { return "Switch to the tree to change items." }
        if root?.isContainer != true { return "This file holds a single value." }
        if tool == "add-child", tree.selectedNodes.first?.isContainer != true { return "Select an object or array." }
        if tool == "delete-item", tree.selectedNodes.isEmpty { return "Select the items to delete." }
        return nil
    }

    func perform(_ id: String) -> Bool {
        tree.commitEditing()  // what's being typed in a cell lands before anything else changes
        switch id {
        case "show-text":
            guard showsText || root != nil else { return false }
            showsText.toggle()
            preferences?.set(showsText, for: "showsText")
            if !showsText { reparse() }
            showView()
            container.window?.makeFirstResponder(focusView)
        case "add-item" where isEditable && unavailableReason(for: id) == nil: addItem()
        case "add-child" where isEditable && unavailableReason(for: id) == nil:
            guard let container = tree.selectedNodes.first else { return false }
            let key = container.kind == .object ? JSONEdits.freshKey(in: container) : nil
            apply(name: "Add Child", select: (container, container.children.count)) { [JSONEdits.addChild(to: container, key: key, in: $0)] }
        case "delete-item" where isEditable && unavailableReason(for: id) == nil: deleteSelection()
        default: return false
        }
        return true
    }

    private func addItem() {
        guard let root else { return }
        if let sibling = tree.selectedNodes.last, let parent = sibling.parent {
            let key = parent.kind == .object ? JSONEdits.freshKey(in: parent) : nil
            apply(name: "Add Item", select: (parent, sibling.index + 1)) { [JSONEdits.insert(after: sibling, key: key, in: $0)] }
        } else if root.isContainer {
            let key = root.kind == .object ? JSONEdits.freshKey(in: root) : nil
            apply(name: "Add Item", select: (root, root.children.count)) { [JSONEdits.addChild(to: root, key: key, in: $0)] }
        }
    }

    private func deleteSelection() {
        // An item inside another selected one goes with it.
        let selected = tree.selectedNodes, ids = Set(selected.map(ObjectIdentifier.init))
        let nodes = selected.filter { node in !node.ancestors.contains { ids.contains(ObjectIdentifier($0)) } }
        // One at a time from the end, each against the text as it then is: a later item's delete can reach back to
        // the comma before it, and earlier items' places don't move.
        let steps = nodes.sorted { $0.start > $1.start }.map { node in { (text: String) in JSONEdits.delete(node, in: text) } }
        apply(name: nodes.count == 1 ? "Delete Item" : "Delete Items", select: nil, steps: steps)
    }

    func setValue(_ node: JSONNode, to typed: String) {
        guard isEditable, !node.isContainer, isCurrent(node), typed != node.value else { return }
        apply(name: "Change Value", select: nil) { _ in [JSONEdits.setValue(node, typed: typed)] }
    }

    func rename(_ node: JSONNode, to name: String) {
        guard isEditable, node.key != nil, node.key != name, isCurrent(node) else { return }
        apply(name: "Rename Key", select: nil) { _ in [JSONEdits.rename(node, to: name)] }
    }

    func move(_ node: JSONNode, to index: Int) {
        guard isEditable, let parent = node.parent, index != node.index, isCurrent(node) else { return }
        apply(name: "Move Item", select: (parent, index)) { [JSONEdits.move(node, to: index, in: $0)] }
    }

    /// Whether `node` belongs to the parse of the text as it is now.
    private func isCurrent(_ node: JSONNode) -> Bool { (node.ancestors.last ?? node) === root }

    private func apply(name: String, select: (container: JSONNode, index: Int)?, _ step: @escaping (String) -> [TextChange]) {
        apply(name: name, select: select, steps: [step])
    }

    /// Makes text changes through the text view as one undo step, then parses the text again. Each step computes its
    /// changes from the text as the earlier steps left it. With `select`, the child at that index of that container is
    /// selected afterwards, and a new key's name starts editing.
    private func apply(name: String, select: (container: JSONNode, index: Int)?, steps: [(String) -> [TextChange]]) {
        let path = select.map { indexPath(of: $0.container) + [$0.index] }
        textView.breakUndoCoalescing()  // its own undo step, not part of the last typing
        undoManager.beginUndoGrouping()
        for step in steps {
            let current = text, bytes = Array(current.utf8)
            for change in step(current).sorted(by: { $0.range.lowerBound > $1.range.lowerBound }) {
                let range = Self.nsRange(change.range, in: bytes)
                guard textView.shouldChangeText(in: range, replacementString: change.replacement) else { continue }
                textView.replaceCharacters(in: range, with: change.replacement)
                textView.didChangeText()
            }
        }
        undoManager.setActionName(name)
        undoManager.endUndoGrouping()
        reparse()
        if let path, let node = node(at: path) {
            tree.select(node)
            if node.key != nil, name.hasPrefix("Add") { tree.edit(node, key: true) }
        }
    }

    // MARK: Text

    func undoManager(for view: NSTextView) -> UndoManager? { undoManager }

    func textDidChange(_ notification: Notification) {
        onEdit?()
        coloring?.textChanged()
        pendingParse?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.reparse() }
        pendingParse = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    /// Parses the text as it is now, keeping the tree's open items and selection where they still are.
    func reparse() {
        pendingParse?.cancel()
        guard !textOnly else { return }
        tree.cancelEditing()  // its node is from the old parse
        let before = root.map { _ in tree.state() }
        let topLevel = root?.children.map { $0.key ?? "" }
        let wasBroken = root == nil
        switch JSONParser.parse(text) {
        case .success(let node):
            root = node
            error = nil
            // Fixed while typing: the text stays, rather than the tree taking over under the cursor.
            if wasBroken, textView.window?.firstResponder === textView { showsText = true }
        case .failure(let failure):
            root = nil
            error = failure
        }
        showView()
        if let before { tree.restore(before) }
        if root?.children.map({ $0.key ?? "" }) != topLevel { onSidebarChange?() }
    }

    func indexPath(of node: JSONNode) -> [Int] {
        var path: [Int] = [], current = node
        while let parent = current.parent {
            path.insert(current.index, at: 0)
            current = parent
        }
        return path
    }

    func node(at path: [Int]) -> JSONNode? {
        var current = root
        for index in path { current = current?.children[safe: index] }
        return current
    }

    /// A UTF-8 byte range of the text as a range for the text view.
    func nsRange(_ range: Range<Int>) -> NSRange { Self.nsRange(range, in: Array(text.utf8)) }

    /// Counted from the bytes: a UTF-16 unit per byte that starts a character, two for a four-byte one. Walking the
    /// text view's bridged string by UTF-8 offsets took over 100 ms in a 10 MB file.
    static func nsRange(_ range: Range<Int>, in bytes: [UInt8]) -> NSRange {
        func units(_ count: Int) -> Int {
            var units = 0
            for byte in bytes[..<min(count, bytes.count)] where byte & 0xC0 != 0x80 { units += byte >= 0xF0 ? 2 : 1 }
            return units
        }
        let start = units(range.lowerBound)
        return NSRange(location: start, length: units(range.upperBound) - start)
    }

    // MARK: Saving

    func unsavedEdits() -> UnsavedEdits? {
        guard isEditable else { return nil }
        return (text as NSString).isEqual(to: baseline) ? nil : UnsavedEdits(TextEdits(text: text))
    }

    func restore(encoded edits: Data) -> Bool {
        guard isEditable, let text = (try? JSONDecoder().decode(TextEdits.self, from: edits))?.text else { return false }
        let range = NSRange(location: 0, length: storage.length)
        guard textView.shouldChangeText(in: range, replacementString: text) else { return false }
        textView.replaceCharacters(in: range, with: text)
        textView.didChangeText()
        reparse()
        return true
    }

    func save(_ edits: UnsavedEdits, accepting offer: SaveOffer?) async throws(PluginError) {
        guard isEditable, let text = (edits.value as? TextEdits)?.text else { throw PluginError(readOnlyReason ?? TextFile.readOnlyNote) }
        try await write(text, to: url, offer: offer)
    }

    func saveAs(_ edits: UnsavedEdits?, to destination: URL, accepting offer: SaveOffer?) async throws(PluginError) {
        if isEditable, let text = (edits?.value as? TextEdits)?.text {
            try await write(text, to: destination, offer: offer)
        } else {
            try await FileReplacement.copy(url, to: destination)
        }
        url = destination
    }

    private func write(_ text: String, to destination: URL, offer: SaveOffer?) async throws(PluginError) {
        let target = offer == TextFile.saveAsUTF8 ? TextFormat(encoding: .utf8, hasBOM: false, lineEnding: format.lineEnding) : format
        guard destination != url || target != format || Data(text.utf8) != Data(baseline.utf8) else { baseline = text; return }
        let byteCount = try await TextFile.write(text, as: target, to: destination.path)
        format = target
        baseline = text
        info = [InfoRow(label: "Lines", value: TextCodec.lineCount(of: text).formatted())] + info.dropFirst().dropLast()
            + [InfoRow(label: "Size", value: ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file))]
        onSidebarChange?()
    }

    func revertEdits() {
        tree.commitEditing()
        textView.string = baseline
        undoManager.removeAllActions()
        coloring?.textChanged()
        reparse()
    }

    func reload() async throws(PluginError) -> Bool {
        let loaded = try await DataPlugin.load(url)
        guard unsavedEdits() == nil else { return true }  // edits made meanwhile win
        format = loaded.file.format
        baseline = loaded.file.text
        readOnlyReason = loaded.file.editable ? nil : loaded.file.note ?? TextFile.readOnlyNote
        textOnly = loaded.file.isPartial
        info = Self.info(loaded.file)
        textView.isEditable = isEditable
        revertEdits()
        onSidebarChange?()
        return true
    }
}

extension JSONNode {
    /// Its parent, its parent's parent, up to the top.
    var ancestors: [JSONNode] {
        var nodes: [JSONNode] = [], current = parent
        while let node = current {
            nodes.append(node)
            current = node.parent
        }
        return nodes
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
