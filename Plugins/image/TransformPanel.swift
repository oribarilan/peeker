import AppKit

/// The Rotate & Resize popover: rotate and flip buttons that L, R, H and V also press, and width and height fields
/// in pixels or percent with an aspect lock. Each press, and each Apply, is one edit.
final class TransformPanel: NSObject, NSTextFieldDelegate {
    let popover = NSPopover()
    let view: TransformView
    private let width = NSTextField()
    private let height = NSTextField()
    private let unit = NSPopUpButton()
    private let lock = NSButton(checkboxWithTitle: "Keep proportions", target: nil, action: nil)
    /// The image's size in pixels now; read when the fields fill in and on Apply.
    private let currentSize: () -> CGSize
    private let onEdit: (ImageEdit) -> Void

    enum Unit: Int { case pixels, percent }
    enum Side { case width, height }

    init(currentSize: @escaping () -> CGSize, onEdit: @escaping (ImageEdit) -> Void) {
        self.currentSize = currentSize
        self.onEdit = onEdit
        view = TransformView()
        super.init()
        var buttons: [NSView] = []
        for (index, turn) in Self.turns.enumerated() {
            let button = NSButton(image: NSImage(systemSymbolName: turn.symbol, accessibilityDescription: turn.title) ?? NSImage(), target: self, action: #selector(pressed(_:)))
            button.tag = index
            button.toolTip = turn.title
            button.bezelStyle = .smallSquare
            buttons.append(button)
            view.keys[turn.keyCode] = { [weak self] in self?.turn(turn.edit) }
        }
        for field in [width, height] {
            field.delegate = self
            field.alignment = .right
            field.widthAnchor.constraint(equalToConstant: 64).isActive = true
        }
        width.setAccessibilityLabel("Width")
        height.setAccessibilityLabel("Height")
        unit.addItems(withTitles: ["pixels", "percent"])
        unit.target = self
        unit.action = #selector(unitChanged(_:))
        lock.state = .on
        let apply = NSButton(title: "Apply", target: self, action: #selector(applySize(_:)))
        apply.keyEquivalent = "\r"
        let sizeRow = NSStackView(views: [width, NSTextField(labelWithString: "×"), height, unit])
        let applyRow = NSStackView(views: [lock, apply])
        let stack = NSStackView(views: [NSStackView(views: buttons), sizeRow, applyRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor), stack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor), stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        let controller = NSViewController()
        controller.view = view
        popover.contentViewController = controller
        popover.behavior = .transient
        fillSize()
    }

    /// Shows the panel hanging from the top of `view`, with the keyboard on its buttons.
    func show(below view: NSView) {
        fillSize()
        popover.show(relativeTo: NSRect(x: view.bounds.midX, y: view.isFlipped ? 0 : view.bounds.maxY - 1, width: 1, height: 1),
                     of: view, preferredEdge: view.isFlipped ? .maxY : .minY)
        self.view.window?.makeFirstResponder(self.view)
    }

    /// The pixel size the fields ask for. With the lock on, the side not edited follows the edited one.
    static func targetSize(width: Double, height: Double, unit: Unit, lock: Bool, edited: Side, current: CGSize) -> (width: Int, height: Int)? {
        guard current.width > 0, current.height > 0, width.isFinite, height.isFinite else { return nil }
        var w = unit == .percent ? current.width * width / 100 : width
        var h = unit == .percent ? current.height * height / 100 : height
        if lock {
            if edited == .width { h = w * current.height / current.width } else { w = h * current.width / current.height }
        }
        let result = (width: Int(w.rounded()), height: Int(h.rounded()))
        return ImageEdit.resize(width: result.width, height: result.height).isValid ? result : nil
    }

    private var lastEdited = Side.width

    /// The rotate and flip buttons, in order; a button's tag is its index. Each key is the ANSI key code of its letter,
    /// so it's the same key on the keyboard whatever letter the active layout types there, as Peeker's shortcuts are.
    private static let turns: [(symbol: String, title: String, keyCode: UInt16, edit: ImageEdit)] = [
        ("rotate.left", "Rotate Left (L)", 37, .rotate(by: -90)),
        ("rotate.right", "Rotate Right (R)", 15, .rotate(by: 90)),
        ("arrow.left.and.right.righttriangle.left.righttriangle.right", "Flip Horizontally (H)", 4, .flip(horizontal: true)),
        ("arrow.up.and.down.righttriangle.up.righttriangle.down", "Flip Vertically (V)", 9, .flip(horizontal: false)),
    ]

    @objc private func pressed(_ sender: NSButton) { turn(Self.turns[sender.tag].edit) }

    /// A rotate or flip, from a button or its key; the fields then show the turned size.
    private func turn(_ edit: ImageEdit) {
        onEdit(edit)
        fillSize()
    }

    @objc private func unitChanged(_ sender: Any?) { fillSize() }

    @objc func applySize(_ sender: Any?) {
        guard let size = Self.targetSize(width: width.doubleValue, height: height.doubleValue, unit: Unit(rawValue: unit.indexOfSelectedItem) ?? .pixels,
                                         lock: lock.state == .on, edited: lastEdited, current: currentSize()) else { return NSSound.beep() }
        if CGSize(width: size.width, height: size.height) != currentSize() { onEdit(.resize(width: size.width, height: size.height)) }
        fillSize()
    }

    func controlTextDidChange(_ notification: Notification) {
        lastEdited = (notification.object as? NSTextField) === height ? .height : .width
        guard lock.state == .on, let size = Self.targetSize(width: width.doubleValue, height: height.doubleValue,
                                                            unit: Unit(rawValue: unit.indexOfSelectedItem) ?? .pixels, lock: true,
                                                            edited: lastEdited, current: currentSize()) else { return }
        let percent = unit.indexOfSelectedItem == Unit.percent.rawValue
        let current = currentSize()
        if lastEdited == .width {
            height.stringValue = percent ? format(Double(size.height) / current.height * 100) : "\(size.height)"
        } else {
            width.stringValue = percent ? format(Double(size.width) / current.width * 100) : "\(size.width)"
        }
    }

    /// Puts the image's current size in the fields.
    private func fillSize() {
        let size = currentSize()
        if unit.indexOfSelectedItem == Unit.percent.rawValue {
            width.stringValue = "100"
            height.stringValue = "100"
        } else {
            width.stringValue = "\(Int(size.width))"
            height.stringValue = "\(Int(size.height))"
        }
    }

    private func format(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0...1)).grouping(.never)) }
}

/// The panel's content: takes the keyboard so L, R, H and V press the turn buttons; a focused field gets typing.
final class TransformView: NSView {
    /// Actions by key code.
    var keys: [UInt16: () -> Void] = [:]

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard event.modifierFlags.intersection([.command, .option, .control]).isEmpty, let action = keys[event.keyCode] else {
            return super.keyDown(with: event)
        }
        action()
    }
}
