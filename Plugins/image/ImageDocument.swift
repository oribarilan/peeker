import AppKit
import PeekerKit

/// The decoded image fitted to the window, with zoom from fit to 16 times fit.
final class ImageDocument: PluginDocument {
    private let scrollView = NSScrollView()
    let sidebar: [SidebarPanel]

    init(image: CGImage, info: [InfoRow]) {
        sidebar = InfoPanel.make(info).map { [$0] } ?? []
        let imageView = LayerImageView(image: image)
        scrollView.documentView = imageView
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 1
        scrollView.maxMagnification = 16
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.drawsBackground = false
        imageView.autoresizingMask = [.width, .height]
    }

    var contentView: NSView { scrollView }

    let commands = [
        CommandSpec(id: "zoom-in", title: "Zoom In", symbol: "plus.magnifyingglass", shortcut: "cmd+="),
        CommandSpec(id: "zoom-out", title: "Zoom Out", symbol: "minus.magnifyingglass", shortcut: "cmd+-"),
        CommandSpec(id: "zoom-fit", title: "Zoom to Fit", symbol: "arrow.up.left.and.down.right.magnifyingglass", shortcut: "cmd+9"),
    ]

    func perform(_ id: String) -> Bool {
        switch id {
        case "zoom-in": scrollView.magnification *= 1.25
        case "zoom-out": scrollView.magnification /= 1.25
        case "zoom-fit": scrollView.magnification = 1
        default: return false
        }
        return true
    }

    /// Draws through its layer, which scales the image to fit while keeping its aspect ratio.
    private final class LayerImageView: NSView {
        init(image: CGImage) {
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
    }
}
