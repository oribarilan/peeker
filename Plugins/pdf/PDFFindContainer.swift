import AppKit
import PDFKit
import PeekerKit

/// Holds the PDF view and, under the toolbar, from the first Cmd+F the find bar above it, and the markup strip while
/// it shows. The strip floats over the pages rather than pushing them down, which would move them under the pointer
/// between the two clicks of a double-click. It answers the Find menu items for the view and the find bar, being in
/// the responder chain of each.
final class PDFFindContainer: NSView, NSMenuItemValidation {
    let finder: PDFFinder
    private(set) var bar: FindBar?
    private let pdfView: PDFView
    /// False in the Peek panel, which has no find.
    private let allowsFind: Bool
    private var pagesAtTop: NSLayoutConstraint!
    private var pagesBelowBar: NSLayoutConstraint?
    /// The markup strip, made when first shown, under the toolbar or under the find bar while that shows.
    private(set) var strip: PDFMarkupStrip?
    private var stripAtTop: NSLayoutConstraint?
    private var stripBelowBar: NSLayoutConstraint?

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
        placeStrip()
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
        placeStrip()
        finder.highlights = false
        window?.makeFirstResponder(pdfView)
    }

    private func makeBar() -> FindBar {
        let bar = FindBar(label: "Find in PDF", target: self)
        bar.onSearch = { [weak self] in self?.finder.search($0) }
        finder.onChange = { [weak self, weak bar] in bar?.status = self?.finder.status ?? "" }
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
            bar.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            bar.leadingAnchor.constraint(equalTo: leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        pagesBelowBar = pdfView.topAnchor.constraint(equalTo: bar.bottomAnchor)
        stripBelowBar = strip?.topAnchor.constraint(equalTo: bar.bottomAnchor)
        self.bar = bar
        return bar
    }

    /// Shows or hides the markup strip, making it the first time; nil when hidden.
    @discardableResult
    func showStrip(_ shown: Bool) -> PDFMarkupStrip? {
        guard shown || strip != nil else { return nil }
        let strip =
            strip
            ?? {
                let made = PDFMarkupStrip()
                made.translatesAutoresizingMaskIntoConstraints = false
                addSubview(made)
                NSLayoutConstraint.activate([
                    made.leadingAnchor.constraint(equalTo: leadingAnchor),
                    made.trailingAnchor.constraint(equalTo: trailingAnchor),
                ])
                stripAtTop = made.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor)
                stripBelowBar = bar.map { made.topAnchor.constraint(equalTo: $0.bottomAnchor) }
                self.strip = made
                return made
            }()
        strip.isHidden = !shown
        placeStrip()
        return shown ? strip : nil
    }

    private func placeStrip() {
        let underBar = bar.map { !$0.isHidden } ?? false
        stripAtTop?.isActive = !underBar
        stripBelowBar?.isActive = underBar
    }

    private static func findAction(of sender: Any?) -> NSFindPanelAction? {
        let tag = (sender as? NSMenuItem)?.tag ?? (sender as? NSControl)?.tag
        return tag.flatMap { NSFindPanelAction(rawValue: UInt($0)) }
    }
}
