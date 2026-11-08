import AppKit
import PDFKit

/// Draws the selection with its corner handles, the drawing being dragged out, and the signature following the
/// pointer. Never takes clicks.
final class EditOverlay: NSView {
    weak var controller: EditController?
    var ghost: (signature: Signature, rect: CGRect)? { didSet { needsDisplay = true } }
    /// In its page's space, so each point is placed through the view, rotated pages included.
    var draft: (page: PDFPage, rect: CGRect, drawing: PDFDrawing)? { didSet { needsDisplay = true } }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    @objc func refresh() { needsDisplay = true }

    override func draw(_ dirtyRect: NSRect) {
        guard let view = superview as? PDFView else { return }
        if let annotation = controller?.selectedAnnotation, let page = annotation.page {
            let rect = convert(view.convert(annotation.bounds, from: page), from: view).insetBy(dx: -2, dy: -2)
            NSColor.controlAccentColor.setStroke()
            let outline = NSBezierPath(rect: rect)
            outline.lineWidth = 1
            outline.stroke()
            for corner in [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY)] {
                let size = EditController.handleSize
                let handle = NSBezierPath(rect: CGRect(x: corner.x - size / 2, y: corner.y - size / 2, width: size, height: size))
                NSColor.white.setFill()
                handle.fill()
                handle.stroke()
            }
        }
        if let draft {
            let color = draft.drawing.color
            NSColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: 1).setStroke()
            let place = { (p: CGPoint) in
                self.convert(view.convert(CGPoint(x: draft.rect.minX + p.x * draft.rect.width, y: draft.rect.minY + p.y * draft.rect.height), from: draft.page), from: view)
            }
            for stroke in draft.drawing.strokes {
                guard let first = stroke.first else { continue }
                let path = NSBezierPath()
                path.lineWidth = draft.drawing.width * view.scaleFactor
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                path.move(to: place(first))
                for point in stroke.dropFirst() { path.line(to: place(point)) }
                path.stroke()
            }
        }
        if let ghost {
            let rect = convert(ghost.rect, from: view)
            NSColor.black.withAlphaComponent(0.5).setStroke()
            for path in PDFMarks.paths(ghost.signature.strokes, size: rect.size) {
                path.transform(using: AffineTransform(translationByX: rect.minX, byY: rect.minY))
                path.stroke()
            }
        }
    }
}
