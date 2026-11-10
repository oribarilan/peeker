import AppKit

/// The print panel's Table section: Row Numbers, and a checkbox for each column. The last checked column stays
/// checked.
final class TablePrintOptions: NSViewController, NSPrintPanelAccessorizing {
    private(set) var choices: TablePrintChoices
    /// Gets each change made here.
    var onChange: ((TablePrintChoices) -> Void)?
    /// Bumped on each change, so the print panel redraws its preview.
    @objc dynamic private(set) var choicesVersion = 0
    let rowNumbers = NSButton(checkboxWithTitle: "Row Numbers", target: nil, action: nil)
    let columnBoxes: [NSButton]

    private var shownCount: Int { columnBoxes.count - choices.hiddenColumns.count }

    /// `titles` names the table's columns. Hidden columns past them are dropped, and if every column is hidden,
    /// all show.
    init(titles: [String], choices: TablePrintChoices) {
        var choices = choices
        choices.hiddenColumns = choices.hiddenColumns.filter { $0 < titles.count }
        if choices.hiddenColumns.count == titles.count { choices.hiddenColumns = [] }
        self.choices = choices
        columnBoxes = titles.enumerated().map { index, title in
            let box = NSButton(checkboxWithTitle: title, target: nil, action: nil)
            box.tag = index
            box.lineBreakMode = .byTruncatingTail
            return box
        }
        super.init(nibName: nil, bundle: nil)
        title = "Table"
        rowNumbers.target = self
        rowNumbers.action = #selector(toggleRowNumbers)
        for box in columnBoxes {
            box.target = self
            box.action = #selector(toggleColumn(_:))
        }
        update()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func loadView() {
        let list = NSStackView(views: columnBoxes)
        list.orientation = .vertical
        list.alignment = .leading
        list.spacing = 6
        list.edgeInsets = NSEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        list.translatesAutoresizingMaskIntoConstraints = false
        let document = FlippedView()
        document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(list)
        let scroll = NSScrollView()
        scroll.borderType = .bezelBorder
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.documentView = document
        let label = NSTextField(labelWithString: "Columns:")
        let stack = NSStackView(views: [rowNumbers, label, scroll])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)
        let clip = scroll.contentView
        NSLayoutConstraint.activate([
            list.topAnchor.constraint(equalTo: document.topAnchor),
            list.bottomAnchor.constraint(equalTo: document.bottomAnchor),
            list.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            list.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            document.topAnchor.constraint(equalTo: clip.topAnchor),
            document.leadingAnchor.constraint(equalTo: clip.leadingAnchor),
            document.trailingAnchor.constraint(equalTo: clip.trailingAnchor),
            scroll.widthAnchor.constraint(equalToConstant: 280),
            scroll.heightAnchor.constraint(equalToConstant: min(list.fittingSize.height, 160) + 2),
        ])
        stack.setFrameSize(stack.fittingSize)
        view = stack
    }

    @objc private func toggleRowNumbers() {
        choices.showsRowNumbers = rowNumbers.state == .on
        changed()
    }

    @objc private func toggleColumn(_ box: NSButton) {
        let old = choices
        if box.state == .on {
            choices.hiddenColumns.remove(box.tag)
        } else if shownCount > 1 {
            choices.hiddenColumns.insert(box.tag)
        }
        if choices == old { update() } else { changed() }
    }

    private func changed() {
        update()
        choicesVersion += 1
        onChange?(choices)
    }

    private func update() {
        rowNumbers.state = choices.showsRowNumbers ? .on : .off
        for box in columnBoxes {
            let shown = !choices.hiddenColumns.contains(box.tag)
            box.state = shown ? .on : .off
            box.isEnabled = !shown || shownCount > 1
        }
    }

    // MARK: NSPrintPanelAccessorizing

    func localizedSummaryItems() -> [[NSPrintPanel.AccessorySummaryKey: String]] {
        [[.itemName: "Row Numbers", .itemDescription: choices.showsRowNumbers ? "On" : "Off"],
         [.itemName: "Columns", .itemDescription: "\(shownCount) of \(columnBoxes.count)"]]
    }

    func keyPathsForValuesAffectingPreview() -> Set<String> { [#keyPath(choicesVersion)] }
}

private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
