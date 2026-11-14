import AppKit
import PeekerKit

/// The Peek panel: a floating panel like Finder's Quick Look. It never activates the app, so Finder stays frontmost and keeps
/// handling arrow keys; the hotkey monitor closes it on the same key or Escape.
final class PeekPanel: NSPanel {
    private(set) var document: DocumentViewController?
    /// Opens a file in an Editor window, at a place in it such as a heading a link named.
    var onOpenInWindow: ((URL, String?) -> Void)?
    /// Called after the panel goes away.
    var onDismiss: (() -> Void)?
    /// The id of the enabled plugin that opens a file, for links; the app sets it.
    var owner: (URL) -> String? = { _ in nil }
    /// Tests replace these two.
    var beep: () -> Void = { NSSound.beep() }
    var confirmOpenElsewhere: (PeekPanel, URL) async -> Bool = { await OpenElsewhere.confirm($1, on: $0) }
    /// Extension -> bundle ID of the app the button opens it with instead of Peeker; the app sets it from the config.
    var openWith: [String: String] = [:]
    /// The button's menu set a default (an app's bundle ID) or dropped one (nil) for an extension.
    var onSetDefault: ((String, String?) -> Void)?
    /// Tests replace these four.
    var appFor: (String) -> AppChoice? = AppChoice.installed(bundleID:)
    var listApps: (URL) -> [AppChoice] = AppChoices.list(for:)
    var openInApp: (URL, URL) -> Void = AppChoices.open(_:in:)
    var revealInFinder: (URL) -> Void = { NSWorkspace.shared.activateFileViewerSelecting([$0]) }
    /// The focus a sheet on the panel needs; tests replace these.
    /// Hands the focus back to Finder. Peeker may be the active app by then (a sheet makes it so), and macOS lets the
    /// active app pass the focus on only by yielding it first.
    var activateFinder: () -> Void = {
        guard let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first else { return }
        NSApp.yieldActivation(to: finder)
        finder.activate(from: .current)
    }
    var isShowing: (PeekPanel) -> Bool = { $0.isVisible }
    /// Set while a sheet on the panel has the keyboard.
    var tookKeyboardForSheet = false
    /// Its name is what tells the panel apart from Quick Look, whose button opens Preview. Its arrow lists other apps.
    let openButton = NSComboButton(title: "Open in Peeker", menu: NSMenu(), target: nil, action: nil)
    /// While the button's menu is open, the key monitor leaves every key to it.
    var isMenuOpen = false
    /// The keys for the button and for Show in Finder; the button shows its key as a caption while `showsKeys` (the
    /// Show shortcuts setting) is on, and the menu shows Show in Finder's. The app sets them.
    var openKey: Shortcut?
    var showInFinderKey: Shortcut?
    var showsKeys = false
    /// The file's name, in place of AppKit's title, which would run under the button and can only be cut at its end.
    let titleLabel = NSTextField(labelWithString: "")
    /// Where the frame the user last gave the panel is kept, as `NSStringFromRect`.
    static let frameKey = "peekPanelFrame"
    private let defaults: UserDefaults
    /// True while the panel sets its own frame, which isn't saved.
    private var arranging = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        super.init(
            contentRect: PanelPlacement.frame(saved: nil, screen: Self.pointerScreenFrame()),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered, defer: false)
        minSize = PanelPlacement.minimumSize
        for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification] {
            NotificationCenter.default.addObserver(self, selector: #selector(frameChanged), name: name, object: self)
        }
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        isReleasedWhenClosed = false
        collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        titleLabel.font = .titleBarFont(ofSize: 0)
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.maximumNumberOfLines = 1
        NotificationCenter.default.addObserver(
            self, selector: #selector(sidebarResized), name: NSSplitView.didResizeSubviewsNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(sheetWillBegin), name: NSWindow.willBeginSheetNotification, object: self)
        NotificationCenter.default.addObserver(self, selector: #selector(sheetDidEnd), name: NSWindow.didEndSheetNotification, object: self)

        openButton.target = self
        openButton.action = #selector(openFromButton)
        openButton.style = .split
        openButton.controlSize = .small
        openButton.menu.delegate = self
        // NSComboButton won't open an empty menu; menuNeedsUpdate replaces this as it opens.
        openButton.menu.addItem(withTitle: "Other…", action: nil, keyEquivalent: "")
        let accessory = NSTitlebarAccessoryViewController()
        accessory.view = NSView(frame: NSRect(x: 0, y: 0, width: 0, height: 28))
        accessory.view.addSubview(titleLabel)
        accessory.view.addSubview(openButton)
        layOutTitlebarButtons()
        accessory.layoutAttribute = .trailing
        addTitlebarAccessoryViewController(accessory)
    }

    /// The name, then Open in Peeker, sized to its title. The title-bar accessory reaches from where the name starts to
    /// the trailing edge, and the name gets what the button leaves.
    func layOutTitlebarButtons() {
        openButton.sizeToFit()
        let button = 4 + openButton.frame.width + 6
        let width = max(button, frame.width - titleStart())
        func centered(_ height: CGFloat) -> CGFloat { ((28 - height) / 2).rounded() }
        openButton.frame.origin = NSPoint(x: width - button + 4, y: centered(openButton.frame.height))
        let height = titleLabel.fittingSize.height
        titleLabel.frame = NSRect(x: 0, y: centered(height), width: max(openButton.frame.minX - 8, 0), height: height)
        openButton.superview?.frame.size.width = width
    }

    /// Where AppKit would start the title: past the sidebar when one shows, else past the window's buttons.
    private func titleStart() -> CGFloat {
        let sidebar = (contentViewController as? NSSplitViewController)?.splitViewItems.first { $0.behavior == .sidebar && !$0.isCollapsed }
        if let sidebar { return sidebar.viewController.view.frame.maxX + 12 }
        return (standardWindowButton(.zoomButton)?.frame.maxX ?? 60) + 12
    }

    /// The file's name: the window's title, for VoiceOver and the Window menu, and the label that shows it.
    func showTitle(_ name: String) {
        title = name
        titleLabel.stringValue = name
        layOutTitlebarButtons()
    }

    @objc private func sidebarResized(_ notification: Notification) {
        if (notification.object as? NSView)?.window === self { layOutTitlebarButtons() }
    }

    @objc func showFileInFinder(_ sender: Any?) {
        if let url { choose(.showInFinder, for: url) }
    }

    var url: URL? { document?.url }

    /// AppKit spends a first click on making the panel key when the content needs that (selectable text), so a link
    /// took two clicks. Making it key first lets the same click act. It still doesn't activate the app.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown, !isKeyWindow { makeKey() }
        super.sendEvent(event)
    }

    func show(_ document: DocumentViewController) {
        self.document?.close()
        self.document = document
        showTitle(document.url.lastPathComponent)
        updateOpenButton(for: document.url)
        document.onFollowLink = { [weak self] document, link in Task { await self?.follow(link, from: document) } }
        // A visible panel keeps its frame while arrow keys and links change the file; a hidden one is placed afresh.
        let frame = isVisible ? self.frame : placement()
        arrange {
            contentViewController = document
            setFrame(frame, display: false)
        }
        layOutTitlebarButtons()  // the sidebar, if any, now decides where the name starts
        orderFrontRegardless()
        Task.immediate { await document.load() }
    }

    /// The visible area of the display with the pointer, where the panel opens.
    static func pointerScreenFrame() -> NSRect {
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        return screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    }

    static func hasSavedFrame(in defaults: UserDefaults) -> Bool { defaults.string(forKey: frameKey) != nil }

    /// Puts the panel where it opens: its saved frame on the pointer's display, or as `PanelPlacement` says.
    func placeOnScreen() {
        let frame = placement()
        arrange { setFrame(frame, display: false) }
    }

    /// Forgets the saved frame and goes back to the default on the pointer's display.
    func resetFrame() {
        defaults.removeObject(forKey: Self.frameKey)
        placeOnScreen()
    }

    private func placement() -> NSRect {
        PanelPlacement.frame(saved: defaults.string(forKey: Self.frameKey).map(NSRectFromString), screen: Self.pointerScreenFrame())
    }

    private func arrange(_ change: () -> Void) {
        arranging = true
        defer { arranging = false }
        change()
    }

    /// A move or resize the panel didn't make itself is the user's (a drag, a resize, Accessibility), so it's what the
    /// panel opens with next time.
    @objc private func frameChanged(_ notification: Notification) {
        if notification.name == NSWindow.didResizeNotification { layOutTitlebarButtons() }
        if !arranging { defaults.set(NSStringFromRect(frame), forKey: Self.frameKey) }
    }

    func dismiss() {
        orderOut(nil)
        document?.close()
        document = nil
        contentViewController = nil
        onDismiss?()
    }

    override func close() {
        dismiss()
    }

    @objc private func openFromButton() {
        if let url { openDefault(url) }
    }

    /// A link from the panel's document: a heading scrolls the panel; a file closes it and opens in an Editor window,
    /// as Open in Peeker does. The panel keeps no history.
    func follow(_ link: URL, from document: DocumentViewController) async {
        switch LinkRoute(link: link, from: document.url, plugin: document.entry.id, owner: owner, isOpenElsewhere: { _ in false }) {
        case .missing: beep()
        case .stay, .bringForward: break  // nothing is open elsewhere for the panel; opening brings a window forward
        case .place(let name):
            if await (document.pluginDocument as? any LinkFollowing)?.go(to: name) == nil { beep() }
        case .sameTab(let file, let place), .ownTab(let file, let place):
            dismiss()
            onOpenInWindow?(file, place)
        case .ask(let file):
            if await confirmOpenElsewhere(self, file) { NSWorkspace.shared.open(file) }
        }
    }
}
