import AppKit

/// Draws the image through its layer, scaled to fit while keeping its aspect ratio. In Edit mode it takes the
/// keyboard, so Undo reaches the document's history, and hosts the crop overlay.
final class ImageCanvas: NSView, NSMenuItemValidation {
    var image: CGImage {
        didSet { layer?.contents = image }
    }
    var isEditing = false
    /// The document's undo history, set while in Edit mode.
    weak var editUndoManager: UndoManager?

    init(image: CGImage) {
        self.image = image
        super.init(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        wantsLayer = true
        layer?.contents = image
        layer?.contentsGravity = .resizeAspect
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        if let clip = superview { frame = clip.bounds }
    }

    /// Where the image is drawn, in this view's coordinates.
    var imageRect: CGRect {
        let size = CGSize(width: image.width, height: image.height)
        guard size.width > 0, size.height > 0, bounds.width > 0, bounds.height > 0 else { return .zero }
        let scale = min(bounds.width / size.width, bounds.height / size.height)
        let drawn = CGSize(width: size.width * scale, height: size.height * scale)
        return CGRect(x: bounds.midX - drawn.width / 2, y: bounds.midY - drawn.height / 2, width: drawn.width, height: drawn.height)
    }

    override var acceptsFirstResponder: Bool { isEditing }
    override var undoManager: UndoManager? { editUndoManager ?? super.undoManager }

    @objc func undo(_ sender: Any?) { if isEditing { undoManager?.undo() } }
    @objc func redo(_ sender: Any?) { if isEditing { undoManager?.redo() } }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(undo(_:)): isEditing && undoManager?.canUndo == true
        case #selector(redo(_:)): isEditing && undoManager?.canRedo == true
        default: true
        }
    }
}
