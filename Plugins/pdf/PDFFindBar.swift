import AppKit
import PDFKit

enum FindAction: Equatable {
    case next, previous, close
}

/// Holds the PDF view and, from the first Cmd+F, the find bar above it. It answers the Find menu items for both,
/// since it's in the responder chain of each.
final class PDFFindContainer: NSView, NSMenuItemValidation {
    let finder: PDFFinder
    private(set) var bar: PDFFindBar?
    private let pdfView: PDFView
    /// False in the Space panel, which has no find.
    private let allowsFind: Bool
    private var pagesAtTop: NSLayoutConstraint!
    private var pagesBelowBar: NSLayoutConstraint?

    init(pdfView: PDFView, allowsFind: Bool) {
        self.pdfView = pdfView
        self.allowsFind = allowsFind
        finder = PDFFinder(view: pdfView)
        super.init(frame: .zero)
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pdfView)
        pagesAtTop = pdfView.topAnchor.constraint(equalTo: topAnchor)
        NSLayoutConstraint.activate([
            pagesAtTop,
            pdfView.leadingAnchor.constraint(equalTo: leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: trailingAnchor),
            pdfView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    @objc func performFindPanelAction(_ sender: Any?) {
        guard allowsFind else { return }
        switch Self.findAction(of: sender) {
        case .showFindPanel: showBar()
        case .next: finder.next()
        case .previous: finder.previous()
        default: NSSound.beep()
        }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard menuItem.action == #selector(performFindPanelAction(_:)), allowsFind else { return false }
        switch Self.findAction(of: menuItem) {
        case .showFindPanel: return true
        case .next, .previous: return !finder.matches.isEmpty
        default: return false
        }
    }

    func showBar() {
        let bar = self.bar ?? makeBar()
        bar.isHidden = false
        pagesAtTop.isActive = false
        pagesBelowBar?.isActive = true
        finder.highlights = true
        layoutSubtreeIfNeeded()
        window?.makeFirstResponder(bar.field)
        bar.field.selectText(nil)
    }

    func closeBar() {
        guard let bar, !bar.isHidden else { return }
        bar.isHidden = true
        pagesBelowBar?.isActive = false
        pagesAtTop.isActive = true
        finder.highlights = false
        window?.makeFirstResponder(pdfView)
    }

    private func makeBar() -> PDFFindBar {
        let bar = PDFFindBar(finder: finder, container: self)
        bar.onAction = { [weak self] action in
            switch action {
            case .next: self?.finder.next()
            case .previous: self?.finder.previous()
            case .close: self?.closeBar()
            }
        }
        bar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bar)
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: topAnchor),
            bar.leadingAnchor.constraint(equalTo: leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        pagesBelowBar = pdfView.topAnchor.constraint(equalTo: bar.bottomAnchor)
        self.bar = bar
        return bar
    }

    private static func findAction(of sender: Any?) -> NSFindPanelAction? {
        let tag = (sender as? NSMenuItem)?.tag ?? (sender as? NSControl)?.tag
        return tag.flatMap { NSFindPanelAction(rawValue: UInt($0)) }
    }
}

/// The find bar: a search field, the match count, previous and next, and Done. Return and Shift+Return in the
/// field step through the matches; Escape closes the bar.
final class PDFFindBar: NSView, NSSearchFieldDelegate {
    let field = FindField()
    private let status = NSTextField(labelWithString: "")
    private let finder: PDFFinder
    var onAction: ((FindAction) -> Void)?

    init(finder: PDFFinder, container: PDFFindContainer) {
        self.finder = finder
        super.init(frame: .zero)
        (field.cell as? FindFieldCell)?.editor.container = container
        field.delegate = self
        field.placeholderString = "Find"
        field.setAccessibilityLabel("Find in PDF")
        status.textColor = .secondaryLabelColor
        status.setContentHuggingPriority(.required, for: .horizontal)
        let steps = NSSegmentedControl(images: [NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Previous")!,
                                                NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Next")!],
                                       trackingMode: .momentary, target: self, action: #selector(step(_:)))
        steps.setToolTip("Previous", forSegment: 0)
        steps.setToolTip("Next", forSegment: 1)
        let done = NSButton(title: "Done", target: self, action: #selector(done(_:)))
        let row = NSStackView(views: [field, status, steps, done])
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
        finder.onChange = { [weak self] in self?.status.stringValue = finder.status }
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    static func action(for selector: Selector, shift: Bool) -> FindAction? {
        switch selector {
        case #selector(NSResponder.insertNewline(_:)): shift ? .previous : .next
        case #selector(NSResponder.cancelOperation(_:)): .close
        default: nil
        }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        let shift = NSApp.currentEvent?.modifierFlags.contains(.shift) == true
        guard let action = Self.action(for: commandSelector, shift: shift) else { return false }
        onAction?(action)
        return true
    }

    func controlTextDidChange(_ obj: Notification) {
        finder.search(field.stringValue)
    }

    @objc private func step(_ sender: NSSegmentedControl) {
        onAction?(sender.selectedSegment == 0 ? .previous : .next)
    }

    @objc private func done(_ sender: Any?) {
        onAction?(.close)
    }
}

/// A search field whose field editor passes Find Next and Find Previous on to the container. The standard field
/// editor is a text view: it would take those menu items and grey them out.
final class FindField: NSSearchField {
    override class var cellClass: AnyClass? {
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

final class FindFieldEditor: NSTextView {
    weak var container: PDFFindContainer?

    override func performFindPanelAction(_ sender: Any?) {
        container?.performFindPanelAction(sender)
    }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard menuItem.action == #selector(performFindPanelAction(_:)) else { return super.validateMenuItem(menuItem) }
        return container?.validateMenuItem(menuItem) ?? false
    }
}
