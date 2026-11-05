import AppKit
import PDFKit

/// The sidebar's page thumbnails. Several can be selected. In the Editor they can be dragged to reorder (when the
/// file allows page changes, on macOS 27 and later), Delete removes the selected pages, and a right-click shows the
/// page tools.
final class PageThumbnails: PDFThumbnailView, NSMenuItemValidation {
    var isEditing = false {
        didSet { update() }
    }
    var allowsPageChanges = true {
        didSet { update() }
    }
    /// Runs a page tool by id; false when it was refused.
    var onCommand: ((String) -> Bool)?
    /// Whether a page tool can run now.
    var canRun: ((String) -> Bool)?
    private let pageMenu = NSMenu()
    /// The insertion bar shown while a thumbnail is dragged; nil before the thumbnails are in a window or where pages
    /// can't be dragged.
    private(set) var dropBar: ThumbnailDropBar?

    init(tools: [(id: String, title: String)]) {
        super.init(frame: .zero)
        allowsMultipleSelection = true
        for command in tools {
            let item = NSMenuItem(title: command.title, action: #selector(runTool(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = command.id
            pageMenu.addItem(item)
        }
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// Whether a thumbnail drag can reorder pages: from macOS 27. Before, PDFKit's copy of a dragged page isn't tied to
    /// the original, so a move can't be told from a page dropped in from elsewhere.
    nonisolated static let dragsReorderPages = ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 0))

    private func update() {
        allowsDragging = isEditing && allowsPageChanges && Self.dragsReorderPages
        menu = isEditing ? pageMenu : nil
        installDropBar()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        installDropBar()
    }

    /// Again if PDFKit has since put its own delegate back.
    private func installDropBar() {
        guard Self.dragsReorderPages, window != nil, dropBar == nil || dropBar?.collectionView?.delegate !== dropBar else { return }
        dropBar = ThumbnailDropBar.install(in: self)
    }

    override func deleteBackward(_ sender: Any?) {
        guard isEditing, onCommand?("delete-page") == true else { return NSSound.beep() }
    }

    @objc private func runTool(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String, onCommand?(id) == true else { return NSSound.beep() }
    }

    // A click or a page tool leaves the thumbnails the keyboard, outside the pages' responder chain, so Undo and Find
    // pass through them to the document.

    @objc func undo(_ sender: Any?) { (pdfView as? PeekerPDFView)?.undo(sender) }
    @objc func redo(_ sender: Any?) { (pdfView as? PeekerPDFView)?.redo(sender) }
    @objc func performFindPanelAction(_ sender: Any?) { findContainer?.performFindPanelAction(sender) }
    private var findContainer: PDFFindContainer? { pdfView?.superview as? PDFFindContainer }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(undo(_:)), #selector(redo(_:)): return (pdfView as? PeekerPDFView)?.validateMenuItem(menuItem) ?? false
        case #selector(performFindPanelAction(_:)): return findContainer?.validateMenuItem(menuItem) ?? false
        default: break
        }
        guard let id = menuItem.representedObject as? String else { return true }
        return canRun?(id) ?? false
    }
}
