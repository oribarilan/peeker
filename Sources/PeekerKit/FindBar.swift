import AppKit

public enum FindAction: Equatable, Sendable {
    case next, previous, close
}

/// The find bar a plugin shows under the toolbar: a search field, the match count, previous and next, and Done.
/// Return and Shift+Return in the field step through the matches; Escape closes the bar.
public final class FindBar: NSView, NSSearchFieldDelegate {
    public let field = FindField()
    private let statusLabel = NSTextField(labelWithString: "")
    /// The search text, on each change.
    public var onSearch: ((String) -> Void)?
    public var onAction: ((FindAction) -> Void)?
    /// "2 of 5", "Not found" and so on.
    public var status: String {
        get { statusLabel.stringValue }
        set { statusLabel.stringValue = newValue }
    }

    /// `label` names the field for VoiceOver, such as "Find in PDF". `target` gets Find Next and Find Previous while
    /// the field has the keyboard, and validates them.
    public init(label: String, target: NSResponder) {
        super.init(frame: .zero)
        (field.cell as? FindFieldCell)?.editor.target = target
        field.delegate = self
        field.placeholderString = "Find"
        field.setAccessibilityLabel(label)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.setContentHuggingPriority(.required, for: .horizontal)
        let steps = NSSegmentedControl(images: [NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Previous")!,
                                                NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Next")!],
                                       trackingMode: .momentary, target: self, action: #selector(step(_:)))
        steps.setToolTip("Previous (⇧⌘G)", forSegment: 0)
        steps.setToolTip("Next (⌘G)", forSegment: 1)
        let done = NSButton(title: "Done", target: self, action: #selector(done(_:)))
        let row = NSStackView(views: [field, statusLabel, steps, done])
        row.spacing = 8
        row.edgeInsets = NSEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        let line = NSBox()
        line.boxType = .separator
        for view in [row, line] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            line.topAnchor.constraint(equalTo: row.bottomAnchor),
            line.leadingAnchor.constraint(equalTo: leadingAnchor),
            line.trailingAnchor.constraint(equalTo: trailingAnchor),
            line.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    public static func action(for selector: Selector, shift: Bool) -> FindAction? {
        switch selector {
        case #selector(NSResponder.insertNewline(_:)): shift ? .previous : .next
        case #selector(NSResponder.cancelOperation(_:)): .close
        default: nil
        }
    }

    public func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        let shift = NSApp.currentEvent?.modifierFlags.contains(.shift) == true
        guard let action = Self.action(for: commandSelector, shift: shift) else { return false }
        onAction?(action)
        return true
    }

    public func controlTextDidChange(_ obj: Notification) {
        onSearch?(field.stringValue)
    }

    @objc private func step(_ sender: NSSegmentedControl) {
        onAction?(sender.selectedSegment == 0 ? .previous : .next)
    }

    @objc private func done(_ sender: Any?) {
        onAction?(.close)
    }
}

/// A search field whose field editor passes Find Next and Find Previous on to the bar's target. The standard field
/// editor is a text view: it would take those menu items and grey them out.
public final class FindField: NSSearchField {
    override public class var cellClass: AnyClass? {
        get { FindFieldCell.self }
        set { super.cellClass = newValue }
    }
}

final class FindFieldCell: NSSearchFieldCell {
    let editor: FindFieldEditor = {
        let editor = FindFieldEditor()
        editor.isFieldEditor = true
        return editor
    }()

    override func fieldEditor(for controlView: NSView) -> NSTextView? { editor }
}

public final class FindFieldEditor: NSTextView {
    weak var target: NSResponder?

    override public func performFindPanelAction(_ sender: Any?) {
        target?.tryToPerform(#selector(performFindPanelAction(_:)), with: sender)
    }

    override public func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard menuItem.action == #selector(performFindPanelAction(_:)) else { return super.validateMenuItem(menuItem) }
        return (target as? NSMenuItemValidation)?.validateMenuItem(menuItem) ?? false
    }
}
