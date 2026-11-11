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
    var listApps: (URL) -> [AppChoice] = { NSWorkspace.shared.urlsForApplications(toOpen: $0).compactMap(AppChoice.init(url:)) }
    var openInApp: (URL, URL) -> Void = { file, app in
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open([file], withApplicationAt: app, configuration: configuration)
    }
    var revealInFinder: (URL) -> Void = { NSWorkspace.shared.activateFileViewerSelecting([$0]) }
    /// Its name is what tells the panel apart from Quick Look, whose button opens Preview. Its arrow lists other apps.
    let openButton = NSComboButton(title: "Open in Peeker", menu: NSMenu(), target: nil, action: nil)
    /// While the button's menu is open, the key monitor leaves every key to it.
    var isMenuOpen = false
    /// The buttons' keys, shown as captions while `showsKeys` (the Show shortcuts setting) is on; the app sets them.
    var openKey: Shortcut?
    var showInFinderKey: Shortcut?
    var showsKeys = false
    let finderButton = NSButton(image: NSImage(systemSymbolName: "folder", accessibilityDescription: "Show in Finder")!, target: nil, action: nil)
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

        openButton.target = self
        openButton.action = #selector(openFromButton)
        openButton.style = .split
        openButton.controlSize = .small
        openButton.menu.delegate = self
        // NSComboButton won't open an empty menu; menuNeedsUpdate replaces this as it opens.
        openButton.menu.addItem(withTitle: "Other…", action: nil, keyEquivalent: "")
        finderButton.target = self
        finderButton.action = #selector(showFileInFinder(_:))
        finderButton.controlSize = .small
        finderButton.toolTip = "Show in Finder"
        let accessory = NSTitlebarAccessoryViewController()
        accessory.view = NSView(frame: NSRect(x: 0, y: 0, width: 0, height: 28))
        accessory.view.addSubview(finderButton)
        accessory.view.addSubview(openButton)
        layOutTitlebarButtons()
        accessory.layoutAttribute = .trailing
        addTitlebarAccessoryViewController(accessory)
    }

    /// The folder button, then Open in Peeker, sized to their titles.
    func layOutTitlebarButtons() {
        finderButton.sizeToFit()
        openButton.sizeToFit()
        finderButton.frame.origin = NSPoint(x: 4, y: ((28 - finderButton.frame.height) / 2).rounded())
        openButton.frame.origin = NSPoint(x: finderButton.frame.maxX + 6, y: ((28 - openButton.frame.height) / 2).rounded())
        openButton.superview?.frame.size.width = openButton.frame.maxX + 6
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
        title = document.url.lastPathComponent
        updateOpenButton(for: document.url)
        document.onFollowLink = { [weak self] document, link in Task { await self?.follow(link, from: document) } }
        // A visible panel keeps its frame while arrow keys and links change the file; a hidden one is placed afresh.
        let frame = isVisible ? self.frame : placement()
        arrange {
            contentViewController = document
            setFrame(frame, display: false)
        }
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
