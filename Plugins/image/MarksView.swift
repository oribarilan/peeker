import AppKit

/// The marks drawn over the canvas at the screen's resolution, so they stay sharp on a small image and when zoomed in.
/// The saved file, Copy and Print paint them into the image's pixels instead. Clicks pass through to what's under it.
final class MarksView: NSView {
    private var marks: [ImageMark] = []
    private var numbering: [ImageMark] = []
    private var imageSize: CGSize = .zero
    private unowned let canvas: ImageCanvas

    init(canvas: ImageCanvas) {
        self.canvas = canvas
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// Draws `marks` but Pixelate, numbering steps among `numbering`.
    func show(_ marks: [ImageMark], numbering: [ImageMark], imageSize: CGSize) {
        self.marks = marks.filter { !$0.isPixelate }
        self.numbering = numbering
        self.imageSize = imageSize
        needsDisplay = true
    }

    /// What's drawn, for tests.
    var shownMarks: [ImageMark] { marks }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        MarkRenderer.drawOnScreen(marks, numbering: numbering, over: canvas.image, imageSize: imageSize, in: canvas.imageRect, context: context)
    }
}
