import AppKit
import PeekerKit

/// The decoded image fitted to the window, with zoom from fit to 16 times fit. In the Editor it has edit tools:
/// crop, rotate, flip and resize, saved on Cmd+S at full resolution.
final class ImageDocument: PluginDocument {
    private let url: URL
    /// The largest side a page is decoded at, as opening decoded the first.
    private let maxPixels: Int
    private let scrollView = NSScrollView()
    /// Below fit, down to an eighth, or to actual size when that's smaller.
    private static let minimumZoom: CGFloat = 1.0 / 8
    let canvas: ImageCanvas
    /// The file's details for the info panel, read again after a save.
    private(set) var info: [InfoRow]
    let editability: Editability
    /// Editable: crop and Rotate & Resize work from the start.
    var isEditing: Bool { editability == .editable }
    var onEdit: (() -> Void)?
    var onSidebarChange: (() -> Void)?
    /// The screen-size decode of the file as last loaded or saved, which opening makes, and the file's full size in
    /// pixels. Kept beside `full`: saving starts its next picture from it.
    private var base: CGImage
    private var baseSize: CGSize
    /// The file decoded at full resolution, up to `ImagePlugin.fullSide`, once zoomed past fit; kept until the
    /// document closes, and decoded again after a save.
    private var full: CGImage?
    /// The full decode while it runs.
    private(set) var sharpening: Task<Void, Never>?
    /// How the full decode is made; tests hold it back.
    var decodeFull: @concurrent @Sendable (URL, CGSize, Int) async throws(PluginError) -> CGImage = ImagePlugin.decodeFull
    /// Goes up on each save and page change, so a full decode of the file or page from before it is dropped.
    private var generation = 0
    /// The page shown, counted from 0; always 0 but for a multi-page TIFF.
    private(set) var page = 0
    private var pinchObserver: NSObjectProtocol?
    /// Print points per pixel, from the file's or page's resolution.
    private var pointsPerPixel: CGFloat
    /// The pages of a multi-page TIFF; 1 for any other image.
    let pageCount: Int
    /// Whether the pages can be browsed: a multi-page TIFF in the Editor. The Peek panel shows only the first page.
    private let showsPages: Bool
    /// The decode of the page being moved to, while it runs.
    private(set) var pageChange: Task<Void, Never>?
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
    /// Nil for a still image.
    let animation: AnimationPlayer?
    /// Undo for the edits since the last save; a save clears it, since a crop's pixels are then gone from the file.
    private(set) lazy var undoManager = UndoManager()

    init(url: URL, decoded: ImagePlugin.Decoded, editable: Bool, maxPixels: Int) {
        self.url = url
        self.maxPixels = maxPixels
        pageCount = decoded.pageCount
        showsPages = editable && decoded.pageCount > 1
        base = decoded.image
        baseSize = decoded.pixelSize
        pointsPerPixel = decoded.pointsPerPixel
        editability = !editable ? .notEditable : decoded.uneditableReason.map(Editability.readOnly) ?? .editable
        info = decoded.info
        canvas = ImageCanvas(image: decoded.image)
        scrollView.contentView = CenteringClipView()
        scrollView.documentView = canvas
        scrollView.allowsMagnification = true
        scrollView.minMagnification = Self.minimumZoom
        scrollView.maxMagnification = 16
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.hasHorizontalScroller = true
        scrollView.drawsBackground = false
        canvas.autoresizingMask = [.width, .height]
        animation = decoded.isAnimated ? AnimationPlayer(url: url, canvas: canvas) : nil
        if isEditing { canvas.editUndoManager = undoManager }
        pinchObserver = NotificationCenter.default.addObserver(forName: NSScrollView.didEndLiveMagnifyNotification, object: scrollView,
                                                               queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.sharpenIfNeeded() }
        }
    }

    isolated deinit {
        sharpening?.cancel()
        pageChange?.cancel()
        pinchObserver.map(NotificationCenter.default.removeObserver)
    }

    var contentView: NSView { scrollView }
    /// The canvas takes the keyboard when editable, so Undo reaches the document's history.
    var focusView: NSView? { isEditing ? canvas : nil }
    /// The page thumbnails of a multi-page TIFF, above the info panel.
    func makeSidebar() -> [SidebarPanel] {
        (pageList.map { [SidebarPanel($0, sizing: .fill)] } ?? []) + (InfoPanel.make(info).map { [$0] } ?? [])
    }

    /// The thumbnails of a multi-page TIFF; nil for any other image.
    private(set) lazy var pageList: PageList? = showsPages
        ? PageList(url: url, pageCount: pageCount) { [weak self] in self?.showPage($0) } : nil

    var tools: [ToolSpec] {
        ImagePlugin.tools.filter { tool in
            !(tool.isEditTool && editability == .notEditable) && (showsPages || !Self.pageTools.contains(tool.id))
                && (animation != nil || tool.id != "play-animation")
        }
    }

    /// Play Animation is checked while the animation plays.
    func isOn(_ tool: String) -> Bool? {
        tool == "play-animation" ? animation.map { !$0.isPaused } : nil
    }

    private static let pageTools: Set = ["next-page", "previous-page"]

    func unavailableReason(for tool: String) -> String? {
        switch tool {
        case "previous-page" where page == 0: "This is the first page."
        case "next-page" where page == pageCount - 1: "This is the last page."
        default: nil
        }
    }

    /// The size the window shows, in the pixels of the decode it shows: the screen-size one, or the full one.
    var shownSize: CGSize { CGSize(width: canvas.image.width, height: canvas.image.height) }
    /// The full image's size in pixels with the edits applied.
    var pixelSize: CGSize { ImageEditing.size(after: edits, from: baseSize) }

    /// One page, centered, at the image's own size, shrunk to fit and never enlarged (what fit pagination does).
    /// It prints the picture the window shows; the screen-size decode is sharp enough for paper. A multi-page TIFF
    /// prints every page instead.
    var printJob: ((NSPrintInfo) -> NSPrintOperation?)? {
        if pageCount > 1 { return printPages }
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

    /// Every page of a multi-page TIFF, one per sheet; the orientation follows the first page.
    private var printPages: (NSPrintInfo) -> NSPrintOperation? {
        let url = url, maxPixels = maxPixels
        return { info in
            let pages = ImagePlugin.printPages(url, maxSide: maxPixels)
            guard let first = pages.first else { return nil }
            info.orientation = first.size.width > first.size.height ? .landscape : .portrait
            return NSPrintOperation(view: PagesPrintView(pages: pages, printInfo: info), printInfo: info)
        }
    }

    func perform(_ id: String) -> Bool {
        switch id {
        case "zoom-in":
            scrollView.magnification *= 1.25
            sharpenIfNeeded()
        case "zoom-out": scrollView.magnification /= 1.25
        case "zoom-fit": scrollView.magnification = 1
        case "zoom-actual":
            zoomToActualSize()
            sharpenIfNeeded(atActualSize: true)
        case "play-animation" where animation != nil: animation?.toggle()
        case "next-page" where showsPages: showPage(page + 1)
        case "previous-page" where showsPages: showPage(page - 1)
        case "crop" where isEditing: startCrop()
        case "transform" where isEditing: showTransform()
        default: return false
        }
        return true
    }

    /// The magnification that shows one image pixel per screen pixel, given the fitted image's width in points.
    static func actualMagnification(pixelWidth: CGFloat, backingScale: CGFloat, fittedWidth: CGFloat) -> CGFloat {
        guard fittedWidth > 0, backingScale > 0 else { return 1 }
        return pixelWidth / backingScale / fittedWidth
    }

    private func zoomToActualSize() {
        let scale = scrollView.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        let target = Self.actualMagnification(pixelWidth: pixelSize.width, backingScale: scale, fittedWidth: canvas.imageRect.width)
        scrollView.minMagnification = min(Self.minimumZoom, target)
        scrollView.setMagnification(min(target, scrollView.maxMagnification), centeredAt: NSPoint(x: canvas.bounds.midX, y: canvas.bounds.midY))
    }

    /// Starts the full decode when the view shows more than the screen-size decode holds: zoomed past fit, or at
    /// Actual Size, which shows the image's own pixels. Never for an animation, nor twice, nor when the screen-size
    /// decode already has every pixel the full one would.
    private func sharpenIfNeeded(atActualSize: Bool = false) {
        guard atActualSize || scrollView.magnification > 1, animation == nil, full == nil, sharpening == nil,
              max(base.width, base.height) < ImagePlugin.fullSide(for: baseSize) else { return }
        let started = generation, url = url, size = baseSize, page = page, decode = decodeFull
        sharpening = Task { [weak self] in
            let image = try? await decode(url, size, page)
            // After a save the file has changed, and a new decode has taken this one's place.
            guard let self, generation == started else { return }
            sharpening = nil
            guard let image else { return }
            full = image
            redraw()
        }
    }

    // MARK: Pages

    /// Moves to `index`, counted from 0, once its decode is ready, keeping the zoom: fit stays fit, any other
    /// magnification stays, scrolled to the page's top left. Past the first or last page it does nothing.
    func showPage(_ index: Int) {
        guard (0..<pageCount).contains(index), index != page else { return }
        page = index
        pageList?.select(index)
        generation += 1
        sharpening?.cancel()
        sharpening = nil
        pageChange?.cancel()
        let started = generation, url = url, maxPixels = maxPixels
        pageChange = Task { [weak self] in
            let decoded = try? await ImagePlugin.decode(url, maxPixels: maxPixels, page: index)
            guard let self, generation == started else { return }
            pageChange = nil
            guard let decoded else { return NSSound.beep() }
            base = decoded.image
            baseSize = decoded.pixelSize
            pointsPerPixel = decoded.pointsPerPixel
            info = decoded.info
            full = nil
            redraw()
            if scrollView.magnification != 1 {
                let image = canvas.imageRect, clip = scrollView.contentView.bounds
                scrollView.contentView.scroll(to: NSPoint(x: image.minX, y: image.maxY - clip.height))
                scrollView.reflectScrolledClipView(scrollView.contentView)
                sharpenIfNeeded()
            }
            onSidebarChange?()
        }
    }

    // MARK: Editing

    private func startCrop() {
        transformPanel?.popover.close()
        cropOverlay?.finish(nil)
        let overlay = CropOverlay(canvas: canvas, in: scrollView, pixelSize: pixelSize) { [weak self] rect in
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

    /// Shows the sharpest decode there is with the edits applied.
    private func redraw() {
        canvas.image = ImageEditing.preview(edits, of: full ?? base, fullSize: baseSize)
    }

    func unsavedEdits() -> UnsavedEdits? {
        edits.isEmpty ? nil : UnsavedEdits(ImageSnapshot(edits: edits))
    }

    func restore(encoded data: Data) -> Bool {
        guard isEditing, let decoded = try? JSONDecoder().decode([ImageEdit].self, from: data),
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
        base = ImageEditing.preview(snapshot.edits, of: base, fullSize: baseSize)
        baseSize = ImageEditing.size(after: snapshot.edits, from: baseSize)
        edits = remainder
        generation += 1
        sharpening?.cancel()
        sharpening = nil
        full = nil
        redraw()
        sharpenIfNeeded()
        undoManager.removeAllActions()
        info = await ImagePlugin.info(of: url)
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
