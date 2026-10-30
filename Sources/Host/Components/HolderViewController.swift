import AppKit

/// Plain container whose single child view fills it.
final class HolderViewController: NSViewController {
    override func loadView() { view = NSView() }

    func show(_ child: NSView) {
        view.subviews.forEach { $0.removeFromSuperview() }
        child.frame = view.bounds
        child.autoresizingMask = [.width, .height]
        view.addSubview(child)
    }
}
