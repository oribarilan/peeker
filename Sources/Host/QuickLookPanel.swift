import AppKit

/// Quick Look-style floating panel. It never activates the app, so Finder stays frontmost and keeps
/// handling arrow keys; the hotkey monitor closes it on the same key or Escape.
final class QuickLookPanel: NSPanel {
    private(set) var document: DocumentViewController?
    var onOpenInWindow: ((URL) -> Void)?

    init() {
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = NSSize(width: visible.width * 0.55, height: visible.height * 0.75)
        let frame = NSRect(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2, width: size.width, height: size.height)
        super.init(contentRect: frame, styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .fullSizeContentView],
                   backing: .buffered, defer: false)
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        isReleasedWhenClosed = false
        collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        titlebarAppearsTransparent = true

        let open = NSButton(title: "Open", target: self, action: #selector(openInWindow))
        open.bezelStyle = .push
        open.controlSize = .small
        let accessory = NSTitlebarAccessoryViewController()
        accessory.view = NSView(frame: NSRect(x: 0, y: 0, width: 70, height: 28))
        accessory.view.addSubview(open)
        open.frame = NSRect(x: 4, y: 3, width: 60, height: 22)
        accessory.layoutAttribute = .trailing
        addTitlebarAccessoryViewController(accessory)
    }

    var url: URL? { document?.url }

    func show(_ document: DocumentViewController) {
        self.document?.close()
        self.document = document
        title = document.url.lastPathComponent
        let frame = self.frame
        contentViewController = document
        setFrame(frame, display: false)
        orderFrontRegardless()
        document.load()
    }

    func dismiss() {
        orderOut(nil)
        document?.close()
        document = nil
        contentViewController = nil
    }

    override func close() {
        dismiss()
    }

    @objc private func openInWindow() {
        guard let url else { return }
        dismiss()
        onOpenInWindow?(url)
    }
}
