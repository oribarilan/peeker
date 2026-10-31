import AppKit

/// Choosing a crop: drag a rectangle over the image, then move it or pull its corners and edges. The outside is
/// dimmed and the size shows in the full image's pixels. Return crops, Escape cancels.
final class CropOverlay: NSView {
    /// The rectangle as fractions of the image, from the top left; nil until one is dragged.
    private(set) var selection: CGRect?
    private let pixelSize: CGSize
    private let onFinish: (CGRect?) -> Void
    private weak var canvas: ImageCanvas?
    private var drag: Drag?
    private static let handle: CGFloat = 8

    private enum Drag {
        /// From a fixed corner to the pointer: a new rectangle, or one pulled by a corner.
        case corner(anchor: CGPoint)
        /// One edge follows the pointer.
        case edge(NSRectEdge, CGRect)
        case move(from: CGPoint, CGRect)
    }

    init(canvas: ImageCanvas, pixelSize: CGSize, onFinish: @escaping (CGRect?) -> Void) {
        self.canvas = canvas
        self.pixelSize = pixelSize
        self.onFinish = onFinish
        super.init(frame: canvas.bounds)
        autoresizingMask = [.width, .height]
        setAccessibilityRole(.group)
        setAccessibilityLabel("Crop")
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var acceptsFirstResponder: Bool { true }

    private var imageRect: CGRect { canvas?.imageRect ?? .zero }

    /// `rect` in this view as fractions of `image`, from its top left, clamped to the image.
    static func fractions(of rect: CGRect, in image: CGRect) -> CGRect {
        guard image.width > 0, image.height > 0 else { return .zero }
        let clamped = rect.intersection(image)
        guard !clamped.isNull else { return .zero }
        return CGRect(x: (clamped.minX - image.minX) / image.width, y: (image.maxY - clamped.maxY) / image.height,
                      width: clamped.width / image.width, height: clamped.height / image.height)
    }

    /// The inverse of `fractions(of:in:)`.
    static func rect(for fractions: CGRect, in image: CGRect) -> CGRect {
        CGRect(x: image.minX + fractions.minX * image.width, y: image.maxY - fractions.maxY * image.height,
               width: fractions.width * image.width, height: fractions.height * image.height)
    }

    private var shownRect: CGRect? { selection.map { Self.rect(for: $0, in: imageRect) } }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = clampedPoint(convert(event.locationInWindow, from: nil))
        drag = shownRect.flatMap { grab($0, at: point) } ?? .corner(anchor: point)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let drag else { return }
        let point = clampedPoint(convert(event.locationInWindow, from: nil))
        let rect: CGRect
        switch drag {
        case .corner(let anchor):
            rect = CGRect(x: min(anchor.x, point.x), y: min(anchor.y, point.y), width: abs(point.x - anchor.x), height: abs(point.y - anchor.y))
        case .edge(let edge, let start):
            var r = start
            switch edge {
            case .minX: r = CGRect(x: min(point.x, start.maxX), y: r.minY, width: abs(start.maxX - point.x), height: r.height)
            case .maxX: r = CGRect(x: min(point.x, start.minX), y: r.minY, width: abs(point.x - start.minX), height: r.height)
            case .minY: r = CGRect(x: r.minX, y: min(point.y, start.maxY), width: r.width, height: abs(start.maxY - point.y))
            case .maxY: r = CGRect(x: r.minX, y: min(point.y, start.minY), width: r.width, height: abs(point.y - start.minY))
            @unknown default: break
            }
            rect = r
        case .move(let from, let start):
            let image = imageRect
            let dx = min(max(point.x - from.x, image.minX - start.minX), image.maxX - start.maxX)
            let dy = min(max(point.y - from.y, image.minY - start.minY), image.maxY - start.maxY)
            rect = start.offsetBy(dx: dx, dy: dy)
        }
        selection = rect.width >= 1 && rect.height >= 1 ? Self.fractions(of: rect, in: imageRect) : nil
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        drag = nil
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76: finish(selection)  // Return, Enter
        case 53: finish(nil)  // Escape
        default: super.keyDown(with: event)
        }
    }

    override func cancelOperation(_ sender: Any?) { finish(nil) }

    /// Ends cropping: crops to `rect`, or cancels when nil.
    func finish(_ rect: CGRect?) {
        removeFromSuperview()
        onFinish(rect.flatMap { $0.width > 0 && $0.height > 0 ? $0 : nil })
    }

    private func clampedPoint(_ point: CGPoint) -> CGPoint {
        let image = imageRect
        return CGPoint(x: min(max(point.x, image.minX), image.maxX), y: min(max(point.y, image.minY), image.maxY))
    }

    /// What dragging from `point` does to `rect`: a corner or edge pulls it, inside moves it; nil starts a new one.
    private func grab(_ rect: CGRect, at point: CGPoint) -> Drag? {
        let near = Self.handle
        let left = abs(point.x - rect.minX) < near, right = abs(point.x - rect.maxX) < near
        let bottom = abs(point.y - rect.minY) < near, top = abs(point.y - rect.maxY) < near
        let inX = point.x > rect.minX - near && point.x < rect.maxX + near, inY = point.y > rect.minY - near && point.y < rect.maxY + near
        if (left || right) && (top || bottom) {
            return .corner(anchor: CGPoint(x: left ? rect.maxX : rect.minX, y: bottom ? rect.maxY : rect.minY))
        }
        if left && inY { return .edge(.minX, rect) }
        if right && inY { return .edge(.maxX, rect) }
        if bottom && inX { return .edge(.minY, rect) }
        if top && inX { return .edge(.maxY, rect) }
        return rect.contains(point) ? .move(from: point, rect) : nil
    }

    override func draw(_ dirtyRect: NSRect) {
        let image = imageRect
        guard let rect = shownRect else {
            NSColor.black.withAlphaComponent(0.25).setFill()
            image.fill()
            return
        }
        let dim = NSBezierPath(rect: image)
        dim.append(NSBezierPath(rect: rect))
        dim.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.45).setFill()
        dim.fill()
        NSColor.white.setStroke()
        let outline = NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5))
        outline.lineWidth = 1
        outline.stroke()
        NSColor.white.setFill()
        for x in [rect.minX, rect.midX, rect.maxX] {
            for y in [rect.minY, rect.midY, rect.maxY] where !(x == rect.midX && y == rect.midY) {
                NSRect(x: x - 3, y: y - 3, width: 6, height: 6).fill()
            }
        }
        guard let selection else { return }
        let pixels = ImageEditing.cropRect(selection, in: pixelSize).size
        let label = "\(Int(pixels.width)) × \(Int(pixels.height))" as NSString
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium), .foregroundColor: NSColor.white]
        let size = label.size(withAttributes: attributes)
        let box = NSRect(x: rect.minX, y: min(rect.maxY + 4, bounds.maxY - size.height - 6), width: size.width + 10, height: size.height + 4)
        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: box, xRadius: 4, yRadius: 4).fill()
        label.draw(at: NSPoint(x: box.minX + 5, y: box.minY + 2), withAttributes: attributes)
    }
}
