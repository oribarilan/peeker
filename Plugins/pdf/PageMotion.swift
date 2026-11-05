import AppKit
import PDFKit

/// A short animation for a page edit in a window: a rotated page turns into place, a deleted page shrinks away and a
/// restored one grows back. The edit is applied at once; the animation plays over the pages on images of them, so
/// input never waits for it. Nothing moves with Reduce Motion on, or for pages off screen.
@MainActor struct PageMotion {
    static let identifier = NSUserInterfaceItemIdentifier("pageMotion")
    static let duration: CFTimeInterval = 0.2
    /// Whether the user asked macOS to reduce motion; tests replace it.
    nonisolated(unsafe) static var reducesMotion: () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    private enum Kind { case turn(degrees: Int), shrink, grow }
    private struct Shot { let page: PDFPage; let image: NSImage; let frame: NSRect }

    private let view: PDFView
    private let kind: Kind
    private let shots: [Shot]
    private let restored: [Int]

    /// Takes images of the pages `edit` changes, before it's applied; nil when nothing should move.
    init?(for edit: PDFEdit, in view: PDFView) {
        guard view.window != nil, !Self.reducesMotion(), let document = view.document else { return nil }
        let changed: [Int]
        switch edit {
        case .rotatePages(let pages, let by): (kind, changed, restored) = (.turn(degrees: by), pages, [])
        case .deletePages(let pages, _): (kind, changed, restored) = (.shrink, pages, [])
        case .restorePages(let pages, _, _): (kind, changed, restored) = (.grow, [], pages)
        default: return nil
        }
        self.view = view
        shots = changed.compactMap { document.page(at: $0) }.compactMap { Self.shot(of: $0, in: view) }
        if shots.isEmpty, restored.isEmpty { return nil }
    }

    /// Plays over the pages once the edit is applied and laid out.
    func play() {
        let shots = restored.isEmpty ? shots : restored.compactMap { view.document?.page(at: $0) }.compactMap { Self.shot(of: $0, in: view) }
        guard !shots.isEmpty else { return }
        let overlay = Overlay(frame: view.bounds)
        overlay.identifier = Self.identifier
        overlay.autoresizingMask = [.width, .height]
        view.addSubview(overlay)
        let root = overlay.layer!
        for shot in shots { animate(shot, in: root, overlay: overlay) }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.duration + 0.05) { overlay.removeFromSuperview() }
    }

    private func animate(_ shot: Shot, in root: CALayer, overlay: NSView) {
        let start = overlay.convert(shot.frame, from: view)
        let image = CALayer()
        image.contents = shot.image
        image.contentsGravity = .resize
        image.bounds = CGRect(origin: .zero, size: start.size)
        image.position = CGPoint(x: start.midX, y: start.midY)
        switch kind {
        case .turn(let degrees):
            // The page as it now sits under the image, hidden until the image has turned onto it.
            guard let now = Self.frame(of: shot.page, in: view).map({ overlay.convert($0, from: view) }) else { return }
            let cover = CALayer()
            cover.backgroundColor = view.backgroundColor.cgColor
            cover.frame = now
            root.addSublayer(cover)
            root.addSublayer(image)
            let scale = start.height > 0 ? now.width / start.height : 1
            let angle = CGFloat(-degrees) * .pi / 180  // a positive PDF rotation turns clockwise
            var end = CATransform3DMakeRotation(angle, 0, 0, 1)
            end = CATransform3DScale(end, scale, scale, 1)
            add(image, "transform", from: CATransform3DIdentity, to: end)
            add(image, "position", from: image.position, to: CGPoint(x: now.midX, y: now.midY))
            add(cover, "opacity", from: 1, to: 0)
        case .shrink:
            root.addSublayer(image)
            add(image, "transform", from: CATransform3DIdentity, to: CATransform3DMakeScale(0.85, 0.85, 1))
            add(image, "opacity", from: 1, to: 0)
        case .grow:
            let cover = CALayer()
            cover.backgroundColor = view.backgroundColor.cgColor
            cover.frame = start
            root.addSublayer(cover)
            root.addSublayer(image)
            add(image, "transform", from: CATransform3DMakeScale(0.85, 0.85, 1), to: CATransform3DIdentity)
            add(image, "opacity", from: 0, to: 1)
        }
    }

    /// Holds the end value until the overlay goes, so nothing flickers back between the end and the removal.
    private func add(_ layer: CALayer, _ key: String, from: Any, to: Any) {
        let animation = CABasicAnimation(keyPath: key)
        animation.fromValue = from
        animation.toValue = to
        animation.duration = Self.duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        layer.add(animation, forKey: key)
    }

    /// The page's frame in the view, when any of it is on screen.
    private static func frame(of page: PDFPage, in view: PDFView) -> NSRect? {
        let frame = view.convert(page.bounds(for: view.displayBox), from: page)
        return frame.intersects(view.bounds) ? frame : nil
    }

    private static func shot(of page: PDFPage, in view: PDFView) -> Shot? {
        guard let frame = frame(of: page, in: view) else { return nil }
        return Shot(page: page, image: page.thumbnail(of: frame.size, for: view.displayBox), frame: frame)
    }

    /// Clips the images to the pages' area and lets clicks through.
    private final class Overlay: NSView {
        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            layer?.masksToBounds = true
        }
        required init?(coder: NSCoder) { nil }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
