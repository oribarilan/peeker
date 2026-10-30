import AppKit

/// A host-owned view a plugin drives through its reply. Plugins never supply views of their own.
protocol Component: AnyObject {
    var view: NSView { get }
    /// Handles a command verb such as "zoom-in". Returns false for verbs it doesn't know.
    func perform(_ verb: String) -> Bool
    /// The view that takes keyboard focus when the component appears, so Cmd+F works without a click first.
    var focusView: NSView? { get }
    /// Called after each change the user makes.
    var onEdit: (() -> Void)? { get set }
    /// The changes since the content was loaded or last saved, or nil when there are none. No side effects, so
    /// anyone may ask (a save, crash recovery).
    func pendingEdits() -> Edits?
    /// Applies edits, such as recovered ones, as if the user had made them.
    func restore(_ edits: Edits)
    /// `saved`, an earlier result of `pendingEdits()`, is now on disk. Changes made since stay pending.
    func didSave(_ saved: Edits)
    /// Drops the pending edits, going back to the content as last loaded or saved.
    func revertEdits()
}

/// Defaults for view-only components.
extension Component {
    var focusView: NSView? { nil }
    var onEdit: (() -> Void)? {
        get { nil }
        set {}  // a view-only component never calls it
    }
    func pendingEdits() -> Edits? { nil }
    func restore(_ edits: Edits) {}
    func didSave(_ saved: Edits) {}
    func revertEdits() {}
}

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
