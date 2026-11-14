import AppKit

/// Cmd-C over the panel, and the focus a sheet on it needs. The panel never knows what it shows: it asks the view
/// with its focus, as Edit > Copy would.
extension PeekPanel {
    /// Whether the view with the panel's focus can copy now: it answers Copy and says Copy is enabled. A table has
    /// nothing to copy before a click, and a text view needs selected text.
    var canCopy: Bool {
        guard let responder = firstResponder, responder !== self, responder.responds(to: Self.copyAction) else { return false }
        let item = NSMenuItem(title: "Copy", action: Self.copyAction, keyEquivalent: "c")
        let object = responder as AnyObject
        if responder.responds(to: #selector(NSMenuItemValidation.validateMenuItem(_:))) { return object.validateMenuItem?(item) ?? true }
        if responder.responds(to: #selector(NSUserInterfaceValidations.validateUserInterfaceItem(_:))) {
            return object.validateUserInterfaceItem?(item) ?? true
        }
        return true
    }

    func copySelection() {
        if canCopy { _ = firstResponder?.tryToPerform(Self.copyAction, with: nil) }
    }

    private static let copyAction = #selector(NSText.copy(_:))

    /// A sheet needs the keyboard, which a panel over Finder doesn't have: the panel takes it, and the key monitor
    /// leaves every key to the sheet meanwhile. Finder gets the keyboard back when the sheet ends while the panel still
    /// shows; when the sheet's own completion closed the panel (Other… opening an app), the focus stays where it put it.
    @objc func sheetWillBegin(_ notification: Notification) {
        tookKeyboardForSheet = true
        makeKey()
    }

    /// Checked a turn later, once the sheet's own completion has run: Other…'s closes the panel and opens an app,
    /// which must keep the focus.
    @objc func sheetDidEnd(_ notification: Notification) {
        guard tookKeyboardForSheet else { return }
        tookKeyboardForSheet = false
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isShowing(self) else { return }
            // Ordering the panel out and straight back in drops its key status, so keys go to Finder again.
            self.orderOut(nil)
            self.orderFrontRegardless()
            self.activateFinder()
        }
    }
}
