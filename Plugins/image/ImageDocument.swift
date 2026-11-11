import AppKit
import PeekerKit

/// The decoded image fitted to the window, with zoom from fit to 16 times fit. In the Editor it has edit tools:
/// crop, rotate, flip and resize, saved on Cmd+S at full resolution.
final class ImageDocument: PluginDocument, Zooming {
    private(set) var url: URL
    /// The largest side a page is decoded at, as opening decoded the first.
    private let maxPixels: Int
    private let scrollView = NSScrollView()
    var contentScrollView: NSScrollView { scrollView }
    /// Below fit, down to an eighth, or to actual size when that's smaller.
    static let minimumZoom: CGFloat = 1.0 / 8
    let canvas: ImageCanvas
    /// The file's details for the info panel, read again after a save.
    private(set) var info: [InfoRow]
    let editability: Editability
    /// Editable: crop and Rotate & Resize work from the start.
    var isEditing: Bool { editability == .editable }
    var onEdit: (() -> Void)?
    var onSidebarChange: (() -> Void)?
    var onZoomChange: (() -> Void)?
    /// The screen-size decode of the file as it opened (edits and marks draw on it) and the file's full size in
    /// pixels, kept beside `full`.
    private var base: CGImage
    private var baseSize: CGSize
    /// The file decoded at full resolution, up to `ImagePlugin.fullSide`, once zoomed past fit; kept until the
    /// document closes, and decoded again after a save.
    private var full: CGImage?
    /// The full decode while it runs.
    private(set) var sharpening: Task<Void, Never>?
    /// How the full decode is made; tests hold it back.
    var decodeFull: @concurrent @Sendable (ImageSource, CGSize, Int) async throws(PluginError) -> CGImage = ImagePlugin.decodeFull
    /// Goes up on each save and page change, so a full decode of the file or page from before it is dropped.
    private var generation = 0
    /// The page shown, counted from 0; always 0 but for a multi-page TIFF.
    private(set) var page = 0
    private var pinchObserver: NSObjectProtocol?
    /// Reports every change of magnification or fit to `onZoomChange`: the menu, `setZoom`, a pinch or a resize.
    private var zoomObservers: [NSObjectProtocol] = []
    /// Print points per pixel, from the file's or page's resolution.
    private var pointsPerPixel: CGFloat
    /// The pages of a multi-page TIFF; 1 for any other image.
    let pageCount: Int
    /// Whether the pages can be browsed: a multi-page TIFF in the Editor. The Peek panel shows only the first page.
    private let showsPages: Bool
    /// The decode of the page being moved to, while it runs.
    private(set) var pageChange: Task<Void, Never>?
    /// The edits since the file opened, oldest first, and the marks on top of them.
    private(set) var edits: [ImageEdit] = []
    private(set) var marks: [ImageMark] = []
    /// What the file on disk holds, as edits and marks on the file as it opened; nil when that's unknown (recovered
    /// edits on a file saved since it opened), so everything counts as unsaved.
    private var saved: ImageState? = ImageState()
    /// The file's bytes as it opened, read before the first save writes over it; nil until then. Every save, the full
    /// decode and Copy draw from it, so a mark stays movable and Undo reaches past saves.
    var original: Data?
    /// Where the image as it opened is read from.
    var source: ImageSource { original.map(ImageSource.bytes) ?? .file(url) }
    /// Where the markup style is kept between launches; nil keeps it only here.
    let preferences: PluginPreferences?
    var markupStyle: MarkStyle
    /// Draws the marks over the image at the screen's resolution; the canvas's image holds only Pixelate's blocks.
    let marksView: MarksView
    /// The mark the overlay is dragging, which the shown image and marks view leave out.
    private var hiddenMark: String?
    /// The image and, above it while marking up, the strip.
    let container = MarkupContainer()
    var strip: MarkupStrip?
    var overlay: MarkupOverlay?
    var onActiveToolChange: (() -> Void)?
    /// Where Copy and Paste go; tests use one of their own, never the user's clipboard.
    var pasteboard = NSPasteboard.general
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
    /// Undo for the edits and marks since the file opened; it reaches past saves, which draw from the file as it opened.
    private(set) lazy var undoManager = UndoManager()

    init(url: URL, decoded: ImagePlugin.Decoded, editable: Bool, maxPixels: Int, preferences: PluginPreferences? = nil) {
        self.url = url
        self.preferences = preferences
        markupStyle = Self.markupStyle(in: preferences)
        self.maxPixels = maxPixels
        pageCount = decoded.pageCount
        showsPages = editable && decoded.pageCount > 1
        base = decoded.image
        baseSize = decoded.pixelSize
        pointsPerPixel = decoded.pointsPerPixel
        editability = !editable ? .notEditable : decoded.uneditableReason.map(Editability.readOnly) ?? .editable
        info = decoded.info
        canvas = ImageCanvas(image: decoded.image)
        marksView = MarksView(canvas: canvas)
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
        container.image = scrollView
        animation = decoded.isAnimated ? AnimationPlayer(url: url, canvas: canvas) : nil
        if isEditing {
            marksView.frame = canvas.bounds
            marksView.autoresizingMask = [.width, .height]
            canvas.addSubview(marksView)
            canvas.editUndoManager = undoManager
            canvas.onCopy = { [weak self] in self?.copy() }
            canvas.onPaste = { [weak self] in self?.paste() }
            canvas.canPaste = { [weak self] in self?.canPasteMark ?? false }
        }
        pinchObserver = NotificationCenter.default.addObserver(
            forName: NSScrollView.didEndLiveMagnifyNotification, object: scrollView,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.sharpenIfNeeded() }
        }
        // Magnifying changes the clip view's bounds; a resize changes the canvas, and with it the fit.
        zoomObservers = [(NSView.boundsDidChangeNotification, scrollView.contentView), (NSView.frameDidChangeNotification, canvas)].map {
            name, view in
            NotificationCenter.default.addObserver(forName: name, object: view, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.onZoomChange?() }
            }
        }
    }

    isolated deinit {
        sharpening?.cancel()
        pageChange?.cancel()
        pinchObserver.map(NotificationCenter.default.removeObserver)
        zoomObservers.forEach(NotificationCenter.default.removeObserver)
    }

    var contentView: NSView { container }
    /// The canvas takes the keyboard when editable, so Undo reaches the document's history.
    var focusView: NSView? { isEditing ? canvas : nil }
    /// The page thumbnails of a multi-page TIFF, above the info panel.
    func makeSidebar() -> [SidebarPanel] {
        (pageList.map { [SidebarPanel($0, sizing: .fill)] } ?? []) + (InfoPanel.make(info).map { [$0] } ?? [])
    }

    /// The thumbnails of a multi-page TIFF; nil for any other image.
    private(set) lazy var pageList: PageList? =
        showsPages
        ? PageList(url: url, pageCount: pageCount) { [weak self] in self?.showPage($0) } : nil

    var tools: [ToolSpec] {
        ImagePlugin.tools.filter { tool in
            !(tool.isEditTool && editability == .notEditable) && (showsPages || !Self.pageTools.contains(tool.id))
                && (animation != nil || tool.id != "play-animation")
        }
    }

    /// Play Animation is checked while the animation plays; the armed markup tool, while the strip shows.
    func isOn(_ tool: String) -> Bool? {
        if let markup = MarkupTool(id: tool) { return isMarkingUp && overlay?.tool == markup }
        return tool == "play-animation" ? animation.map { !$0.isPaused } : nil
    }

    /// Markup shows as in use in the toolbar while its strip does.
    var activeTool: String? { isMarkingUp ? "markup" : nil }

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
        // The shown image holds only Pixelate's blocks; the other marks are drawn over it.
        let image = MarkRenderer.render(marks.filter { !$0.isPixelate }, on: canvas.image, imageSize: pixelSize) ?? canvas.image
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
        case "markup" where isEditing: isMarkingUp ? hideMarkup() : showMarkup()
        case let id where isEditing && MarkupTool(id: id) != nil: arm(MarkupTool(id: id))
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
        let target = actualSizeMagnification
        scrollView.minMagnification = min(Self.minimumZoom, target)
        scrollView.setMagnification(min(target, scrollView.maxMagnification), centeredAt: NSPoint(x: canvas.bounds.midX, y: canvas.bounds.midY))
    }

    /// Starts the full decode when the view shows more than the screen-size decode holds: zoomed past fit, or at
    /// Actual Size, which shows the image's own pixels. Never for an animation, nor twice, nor when the screen-size
    /// decode already has every pixel the full one would.
    func sharpenIfNeeded(atActualSize: Bool = false) {
        guard atActualSize || scrollView.magnification > 1, animation == nil, full == nil, sharpening == nil,
            max(base.width, base.height) < ImagePlugin.fullSide(for: baseSize)
        else { return }
        let started = generation, source = source, size = baseSize, page = page, decode = decodeFull
        sharpening = Task { [weak self] in
            let image = try? await decode(source, size, page)
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
        hideMarkup()
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

    /// Adds an edit, shown at once and undoable. Marks move with a crop, turn, flip or resize; a crop drops the ones
    /// it leaves out.
    func apply(_ edit: ImageEdit) {
        guard edit.isValid else { return }
        overlay?.endTextEditing()  // text being typed is placed before the image changes under it
        setState(ImageState(edits: edits + [edit], marks: ImageMark.mapped(marks, through: edit, from: pixelSize)))
    }

    /// Adds a mark, or replaces the one with its id, shown at once and undoable.
    func put(_ mark: ImageMark) {
        guard mark.isValid else { return }
        var new = marks
        if let index = new.firstIndex(where: { $0.id == mark.id }) { new[index] = mark } else { new.append(mark) }
        setState(ImageState(edits: edits, marks: new))
    }

    func removeMark(id: String) {
        guard marks.contains(where: { $0.id == id }) else { return }
        setState(ImageState(edits: edits, marks: marks.filter { $0.id != id }))
    }

    private var state: ImageState { ImageState(edits: edits, marks: marks) }

    private func setState(_ new: ImageState) {
        let old = state
        edits = new.edits
        marks = new.marks
        // A group of its own: in a window it nests in the event's group, so one action is one undo step.
        undoManager.beginUndoGrouping()
        undoManager.registerUndo(withTarget: self) { $0.setState(old) }
        undoManager.endUndoGrouping()
        redraw()
        if isMarkingUp { showStyle() }  // after Undo, the strip shows the selected mark as it now is
        onEdit?()
    }

    /// Shows the sharpest decode there is with the edits applied and the marks drawn, but for the one with id
    /// `hiding`, which the markup overlay draws while it's dragged.
    func redraw(hiding: String? = nil) {
        hiddenMark = hiding
        let edited = ImageEditing.preview(edits, of: full ?? base, fullSize: baseSize)
        let shown = hiding.map { id in marks.filter { $0.id != id } } ?? marks
        canvas.image = MarkRenderer.render(shown.filter(\.isPixelate), on: edited, imageSize: pixelSize) ?? edited
        marksView.show(shown, numbering: marks, imageSize: pixelSize)
        onZoomChange?()  // a crop, turn, resize or page changes the image's size, and with it the fit
    }

    /// A spotlight being drawn or dragged dims together with the others, in the marks view; nil shows the marks
    /// without it. Drawn apart, it dimmed the image a second time.
    func preview(_ draft: ImageMark?) {
        let shown = marks.filter { $0.id != hiddenMark && $0.id != draft?.id } + (draft.map { [$0] } ?? [])
        marksView.show(shown, numbering: marks, imageSize: pixelSize)
    }

    func unsavedEdits() -> UnsavedEdits? {
        state == saved ? nil : UnsavedEdits(ImageSnapshot(state: state, original: original))
    }

    func restore(encoded data: Data) -> Bool {
        guard isEditing else { return false }
        var recovered: ImageSnapshot.Recovered
        if let plain = try? JSONDecoder().decode([ImageEdit].self, from: data) {
            recovered = ImageSnapshot.Recovered(edits: plain, marks: [])  // from before marks
        } else if let decoded = try? JSONDecoder().decode(ImageSnapshot.Recovered.self, from: data) {
            recovered = decoded
        } else {
            return false
        }
        guard recovered.edits.count + recovered.marks.count <= Self.maxRecoveredEdits, !(recovered.edits.isEmpty && recovered.marks.isEmpty),
            recovered.edits.allSatisfy(\.isValid), recovered.marks.allSatisfy(\.isValid)
        else { return false }
        if recovered.fromOriginal {
            // Saved since it opened: the edits start from the file as it opened, which the record carries.
            guard let bytes = recovered.original, let decoded = try? ImagePlugin.screenDecode(.bytes(bytes), maxPixels: maxPixels) else {
                return false
            }
            original = bytes
            base = decoded.image
            baseSize = decoded.pixelSize
            generation += 1
            sharpening?.cancel()
            sharpening = nil
            full = nil
            saved = nil
        }
        setState(ImageState(edits: recovered.edits, marks: recovered.marks))
        return true
    }

    /// More than any real session makes; a recovery record comes from a file.
    private static let maxRecoveredEdits = 1000

    /// Reads the file as it opened, before the first save writes over it, following a symlink to the file itself.
    private func keepOriginal() async throws(PluginError) -> ImageSource {
        if original == nil { original = try await Self.bytes(of: url) }
        return source
    }

    @concurrent private static func bytes(of url: URL) async throws(PluginError) -> Data {
        try PluginError.catching { try Data(contentsOf: url) }
    }

    func save(_ unsaved: UnsavedEdits, accepting offer: SaveOffer?) async throws(PluginError) {
        guard let snapshot = unsaved.value as? ImageSnapshot else { throw PluginError("These changes aren't image edits.") }
        let source = try await keepOriginal()
        try await ImageSaving.save(snapshot.state.edits, marks: snapshot.state.marks, from: source, to: url.path)
        saved = snapshot.state
        info = await ImagePlugin.info(of: url)
    }

    func saveAs(_ unsaved: UnsavedEdits?, to destination: URL, accepting offer: SaveOffer?) async throws(PluginError) {
        if let snapshot = unsaved?.value as? ImageSnapshot {
            let source = try await keepOriginal()
            try await ImageSaving.save(snapshot.state.edits, marks: snapshot.state.marks, from: source, to: destination.path)
            saved = snapshot.state
        } else {
            try await FileReplacement.copy(url, to: destination)
        }
        url = destination
        info = await ImagePlugin.info(of: url)
        animation?.url = destination
        pageList?.url = destination
    }

    /// Back to the file as last saved. When what it holds is unknown (recovered edits on a file saved since it
    /// opened), it's decoded again and becomes the file as it opened.
    func revertEdits() {
        if saved == nil, let decoded = try? ImagePlugin.decodeNow(url, maxPixels: maxPixels) {
            original = nil
            base = decoded.image
            baseSize = decoded.pixelSize
            full = nil
            saved = ImageState()
        }
        let back = saved ?? ImageState()
        edits = back.edits
        marks = back.marks
        redraw()
        undoManager.removeAllActions()
    }
}

/// An image's edits and marks, both made since the file opened.
nonisolated struct ImageState: Codable, Sendable, Equatable {
    var edits: [ImageEdit] = []
    var marks: [ImageMark] = []
}

/// What a save writes: every edit and mark since the file opened. Once a save has written over the file, the recovery
/// copy also keeps the file's bytes as it opened, which the edits start from, unless they're too large to keep.
nonisolated struct ImageSnapshot: Encodable, Sendable {
    let state: ImageState
    let original: Data?

    /// Larger originals aren't kept in the recovery copy, so edits after a save to such a file can't come back.
    static let maxRecoveredOriginal = 64 << 20

    struct Recovered: Codable {
        let edits: [ImageEdit]
        let marks: [ImageMark]
        /// The edits start from `original`, not from the file on disk.
        var fromOriginal = false
        var original: Data?
    }

    func encode(to encoder: any Encoder) throws {
        let kept = original.flatMap { $0.count <= Self.maxRecoveredOriginal ? $0 : nil }
        try Recovered(edits: state.edits, marks: state.marks, fromOriginal: original != nil, original: kept).encode(to: encoder)
    }
}
