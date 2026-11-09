import AppKit
import PDFKit
import PeekerKit

/// The sidebar's page thumbnails. Several can be selected. In the Editor they can be dragged to reorder (when the
/// file allows page changes, on macOS 27 and later), Delete removes the selected pages, and a right-click shows the
/// page tools. The thumbnail under the pointer shows the hover tint, unless it's selected.
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
    /// The insertion bar shown while a thumbnail is dragged, which also sees each thumbnail come into view; nil before
    /// the thumbnails are in a window.
    private(set) var dropBar: ThumbnailDropBar?
    private let imageObservations = NSMapTable<NSImageView, NSKeyValueObservation>.weakToStrongObjects()
    /// The hover tint, in the background view of PDFKit's collection view, which has no hover of its own; nil before
    /// the thumbnails are in a window, or if PDFKit's insides change and there's no collection view.
    private(set) var hoverFill: HoverFill?
    private(set) weak var hoverCollection: NSCollectionView?
    private var hoveredItem: Int?
    private var selectionObservation: NSKeyValueObservation?

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
        installHover()
    }

    /// Again if PDFKit has since put its own delegate back.
    private func installDropBar() {
        guard window != nil, dropBar == nil || dropBar?.collectionView?.delegate !== dropBar else { return }
        dropBar = ThumbnailDropBar.install(in: self)
        dropBar?.onWillDisplay = { [weak self] item, index in self?.correct(item, at: index) }
    }

    /// Selects `pages` again, those still in the document: PDFKit's thumbnails drop the selection of pages that turn,
    /// and all of it when pages come or go.
    func reselect(_ pages: [PDFPage]) {
        guard let collection = ThumbnailDropBar.firstCollectionView(in: self), let document = pdfView?.document else { return }
        collection.selectionIndexPaths = Set(pages.map(document.index(for:)).filter { $0 != NSNotFound }.map { IndexPath(item: $0, section: 0) })
    }

    // MARK: Images and labels

    /// PDFKit draws every thumbnail upright and labels it with the page's number in the file it came from. This turns
    /// each image to its page's rotation once PDFKit sets it, and once pages were added, removed or moved numbers them
    /// in order, as saving will: PDFKit then writes the file without its page labels.
    private func correct(_ item: NSCollectionViewItem, at index: Int) {
        if (pdfView?.document as? PeekerPDFDocument)?.pagesMoved == true { item.textField?.stringValue = String(index + 1) }
        guard let imageView = item.imageView, imageObservations.object(forKey: imageView) == nil else { return }
        let observation = imageView.observe(\.image) { [weak self, weak item] imageView, _ in
            MainActor.assumeIsolated {
                guard let image = imageView.image, !(image is TurnedThumbnail), let item, let index = item.collectionView?.indexPath(for: item)?.item,
                      let rotation = self?.pdfView?.document?.page(at: index)?.rotation, rotation % 360 != 0 else { return }
                imageView.image = TurnedThumbnail(image, by: rotation)
            }
        }
        imageObservations.setObject(observation, forKey: imageView)
    }

    // MARK: Hover

    private func installHover() {
        guard window != nil, hoverFill == nil, let collection = ThumbnailDropBar.firstCollectionView(in: self) else { return }
        // The items draw into the collection view's own layer, so a subview would cover them; its background view
        // stays behind them.
        let fill = HoverFill()
        let background = collection.backgroundView ?? NSView()
        background.addSubview(fill)
        collection.backgroundView = background
        hoverFill = fill
        hoverCollection = collection
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
                                       owner: self))
        selectionObservation = collection.observe(\.selectionIndexPaths) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.setHovered(self?.hoveredItem) }
        }
        if let clip = collection.enclosingScrollView?.contentView {
            clip.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(self, selector: #selector(scrolled), name: NSView.boundsDidChangeNotification, object: clip)
        }
    }

    override func mouseMoved(with event: NSEvent) { hover(at: event.locationInWindow) }
    override func mouseEntered(with event: NSEvent) { hover(at: event.locationInWindow) }
    override func mouseExited(with event: NSEvent) { setHovered(nil) }

    /// Thumbnails moved under a pointer that stayed put.
    @objc private func scrolled() {
        if let window, hoveredItem != nil { hover(at: window.mouseLocationOutsideOfEventStream) }
    }

    private func hover(at windowPoint: NSPoint) {
        guard let collection = hoverCollection else { return }
        setHovered(collection.indexPathForItem(at: collection.convert(windowPoint, from: nil))?.item)
    }

    /// `item` can be gone: the pointer stays put while its page is deleted, and asking for its frame then raises.
    private func setHovered(_ item: Int?) {
        hoveredItem = item
        guard let collection = hoverCollection, let fill = hoverFill else { return }
        guard let item, item < collection.numberOfItems(inSection: 0), !collection.selectionIndexPaths.contains(IndexPath(item: item, section: 0)) else {
            fill.isHovered = false
            return
        }
        fill.frame = collection.convert(collection.frameForItem(at: item), to: fill.superview)
        fill.isHovered = true
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

/// A thumbnail turned clockwise by a page's rotation.
private nonisolated final class TurnedThumbnail: NSImage {
    convenience init(_ image: NSImage, by degrees: Int) {
        let size = degrees % 180 == 0 ? image.size : NSSize(width: image.size.height, height: image.size.width)
        self.init(size: size, flipped: false) { rect in
            let turn = NSAffineTransform()
            turn.translateX(by: rect.midX, yBy: rect.midY)
            turn.rotate(byDegrees: CGFloat(-degrees))
            turn.concat()
            image.draw(in: NSRect(origin: NSPoint(x: -image.size.width / 2, y: -image.size.height / 2), size: image.size))
            return true
        }
    }
}
