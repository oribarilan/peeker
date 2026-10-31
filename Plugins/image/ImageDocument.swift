import AppKit
import PeekerKit

/// The decoded image fitted to the window, with zoom from fit to 16 times fit. In a window it has an Edit mode:
/// crop, rotate, flip and resize, saved on Cmd+S at full resolution.
final class ImageDocument: PluginDocument {
    private let url: URL
    private let scrollView = NSScrollView()
    let canvas: ImageCanvas
    let sidebar: [SidebarPanel]
    let editMode: EditMode
    private(set) var isEditing = false
    var onEdit: (() -> Void)?
    /// The screen-size decode of the file as last loaded or saved, and the file's full size in pixels.
    private var base: CGImage
    private var baseSize: CGSize
    /// Print points per pixel, from the file's resolution.
    private let pointsPerPixel: CGFloat
    /// The unsaved edits, oldest first.
    private(set) var edits: [ImageEdit] = []
    /// The crop being chosen, and the Rotate & Resize panel, while shown.
    private(set) var cropOverlay: CropOverlay?
    private var transformPanel: TransformPanel?
    var transform: TransformPanel {
        if let transformPanel { return transformPanel }
        let panel = TransformPanel(currentSize: { [weak self] in self?.pixelSize ?? .zero }, onEdit: { [weak self] in self?.apply($0) })
        transformPanel = panel
        return panel
    }
    /// Undo for the edits since the last save; a save clears it, since a crop's pixels are then gone from the file.
    private(set) lazy var undoManager = UndoManager()

    init(url: URL, decoded: ImagePlugin.Decoded, editable: Bool) {
        self.url = url
        base = decoded.image
        baseSize = decoded.pixelSize
        pointsPerPixel = decoded.pixelSize.width > 0 ? decoded.printSize.width / decoded.pixelSize.width : 1
        editMode = !editable ? .none : decoded.uneditableReason.map { .unavailable(reason: $0) } ?? .available
        sidebar = InfoPanel.make(decoded.info).map { [$0] } ?? []
        canvas = ImageCanvas(image: decoded.image)
        scrollView.documentView = canvas
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 1
        scrollView.maxMagnification = 16
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.drawsBackground = false
        canvas.autoresizingMask = [.width, .height]
    }

    var contentView: NSView { scrollView }

    var commands: [CommandSpec] {
        editMode == .none ? ImagePlugin.commands.filter { !$0.isEditTool } : ImagePlugin.commands
    }

    /// The size the window shows, in screen-decode pixels.
    var shownSize: CGSize { CGSize(width: canvas.image.width, height: canvas.image.height) }
    /// The full image's size in pixels with the edits applied.
    var pixelSize: CGSize { ImageEditing.size(after: edits, from: baseSize) }

    /// One page, centered, at the image's own size, shrunk to fit and never enlarged (what fit pagination does).
    /// The screen-size decode is sharp enough for paper.
    var printJob: ((NSPrintInfo) -> NSPrintOperation?)? {
        let image = canvas.image
        let size = CGSize(width: pixelSize.width * pointsPerPixel, height: pixelSize.height * pointsPerPixel)
        return { info in
            info.horizontalPagination = .fit
            info.verticalPagination = .fit
            info.isHorizontallyCentered = true
            info.isVerticallyCentered = true
            info.orientation = size.width > size.height ? .landscape : .portrait
            let view = NSImageView(frame: NSRect(origin: .zero, size: size))
            view.image = NSImage(cgImage: image, size: size)
            view.imageScaling = .scaleAxesIndependently
            return NSPrintOperation(view: view, printInfo: info)
        }
    }

    func perform(_ id: String) -> Bool {
        switch id {
        case "zoom-in": scrollView.magnification *= 1.25
        case "zoom-out": scrollView.magnification /= 1.25
        case "zoom-fit": scrollView.magnification = 1
        case "crop" where isEditing: startCrop()
        case "transform" where isEditing: showTransform()
        default: return false
        }
        return true
    }

    // MARK: Editing

    func setEditing(_ on: Bool) {
        guard editMode == .available, on != isEditing else { return }
        isEditing = on
        canvas.isEditing = on
        canvas.editUndoManager = on ? undoManager : nil
        if on {
            canvas.window?.makeFirstResponder(canvas)
        } else {
            cropOverlay?.finish(nil)
            transformPanel?.popover.close()
        }
    }

    private func startCrop() {
        transformPanel?.popover.close()
        cropOverlay?.finish(nil)
        let overlay = CropOverlay(canvas: canvas, pixelSize: pixelSize) { [weak self] rect in
            guard let self else { return }
            cropOverlay = nil
            if let rect { apply(.crop(rect)) }
            canvas.window?.makeFirstResponder(canvas)
        }
        cropOverlay = overlay
        canvas.addSubview(overlay)
        canvas.window?.makeFirstResponder(overlay)
    }

    private func showTransform() {
        cropOverlay?.finish(nil)
        transform.show(below: scrollView)
    }

    /// Adds an edit, shown at once and undoable.
    func apply(_ edit: ImageEdit) {
        guard edit.isValid else { return }
        setEdits(edits + [edit])
    }

    private func setEdits(_ new: [ImageEdit]) {
        let old = edits
        edits = new
        // A group of its own: in a window it nests in the event's group, so one action is one undo step.
        undoManager.beginUndoGrouping()
        undoManager.registerUndo(withTarget: self) { $0.setEdits(old) }
        undoManager.endUndoGrouping()
        redraw()
        onEdit?()
    }

    /// Shows the base with the edits applied. A resize scales the screen decode by the same factor as the full image.
    private func redraw() {
        var image = base
        var full = baseSize
        for edit in edits {
            let shown: ImageEdit
            if case .resize(let width, let height) = edit, full.width > 0, full.height > 0 {
                // Never larger than the first decode: enlarging only shows as the same picture, and stays cheap.
                var size = CGSize(width: CGFloat(image.width) * CGFloat(width) / full.width, height: CGFloat(image.height) * CGFloat(height) / full.height)
                let limit = CGFloat(max(base.width, base.height)) / max(size.width, size.height)
                if limit < 1 { size = CGSize(width: size.width * limit, height: size.height * limit) }
                shown = .resize(width: max(Int(size.width.rounded()), 1), height: max(Int(size.height.rounded()), 1))
            } else {
                shown = edit
            }
            image = ImageEditing.apply(shown, to: image) ?? image
            full = ImageEditing.size(after: [edit], from: full)
        }
        canvas.image = image
    }

    func unsavedEdits() -> UnsavedEdits? {
        edits.isEmpty ? nil : UnsavedEdits(ImageSnapshot(edits: edits))
    }

    func restore(encoded data: Data) -> Bool {
        guard editMode == .available, let decoded = try? JSONDecoder().decode([ImageEdit].self, from: data),
              (1...Self.maxRecoveredEdits).contains(decoded.count), decoded.allSatisfy(\.isValid) else { return false }
        setEdits(decoded)
        return true
    }

    /// More than any real session makes; a recovery record comes from a file.
    private static let maxRecoveredEdits = 1000

    func save(_ unsaved: UnsavedEdits, accepting offer: SaveOffer?) async throws(PluginError) {
        guard let snapshot = unsaved.value as? ImageSnapshot else { throw PluginError("These changes aren't image edits.") }
        try await ImageSaving.save(snapshot.edits, to: url.path)
        // The file now has the saved edits; start from it. Edits added during the save stay pending on top. If the
        // list changed under the save (an undo), those changes no longer fit the file and are dropped.
        let remainder = edits.starts(with: snapshot.edits) ? Array(edits.dropFirst(snapshot.edits.count)) : []
        edits = snapshot.edits
        redraw()
        base = canvas.image
        baseSize = ImageEditing.size(after: snapshot.edits, from: baseSize)
        edits = remainder
        redraw()
        undoManager.removeAllActions()
        onEdit?()
    }

    func revertEdits() {
        edits = []
        redraw()
        undoManager.removeAllActions()
    }
}

/// The edits a save writes; encodes as the list alone, for the recovery copy.
nonisolated struct ImageSnapshot: Encodable, Sendable {
    let edits: [ImageEdit]

    func encode(to encoder: any Encoder) throws {
        try edits.encode(to: encoder)
    }
}
