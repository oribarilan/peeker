import AppKit
import PeekerKit

/// The zoom control at the bottom right of a zooming document in an Editor window: Zoom Out, the zoom as a percentage,
/// and Zoom In, on glass. Shown while the pointer is over the document or its menu is open, and hidden otherwise, so
/// its corner takes clicks and scrolls only while it shows. − and + run the document's own zoom tools, so their steps
/// match the View menu's. Keyboard users zoom with the View menu's keys; VoiceOver reaches the control.
@MainActor final class ZoomControl: NSView {
    let zoomOutButton = NSButton()
    let zoomInButton = NSButton()
    private let levelButton = NSButton()
    private weak var document: (any Zooming)?
    private let run: (String) -> Void
    private var hovering = false
    private var menuOpen = false
    private var tracking: (area: NSTrackingArea, holder: NSView)?

    /// `run` runs one of the document's tools by id, as its menu item would.
    init(document: any Zooming, run: @escaping (String) -> Void) {
        self.document = document
        self.run = run
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        for (button, symbol, label, action) in [(zoomOutButton, "minus", "Zoom Out", #selector(zoomOut)), (zoomInButton, "plus", "Zoom In", #selector(zoomIn))] {
            button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
            button.toolTip = label
            button.target = self
            button.action = action
        }
        levelButton.target = self
        levelButton.action = #selector(showLevelMenu)
        levelButton.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        levelButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 46).isActive = true
        for button in [zoomOutButton, levelButton, zoomInButton] {
            button.isBordered = false
            button.bezelStyle = .accessoryBarAction
            button.controlSize = .small
        }
        let stack = NSStackView(views: [zoomOutButton, levelButton, zoomInButton])
        stack.spacing = 2
        stack.edgeInsets = NSEdgeInsets(top: 3, left: 6, bottom: 3, right: 6)
        let glass = NSGlassEffectView()
        glass.contentView = stack
        glass.cornerRadius = 14
        glass.translatesAutoresizingMaskIntoConstraints = false
        addSubview(glass)
        NSLayoutConstraint.activate([
            glass.leadingAnchor.constraint(equalTo: leadingAnchor), glass.trailingAnchor.constraint(equalTo: trailingAnchor),
            glass.topAnchor.constraint(equalTo: topAnchor), glass.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Zoom")
        alphaValue = 0
        isHidden = true
        update()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    var levelTitle: String { levelButton.title }

    /// Shows the document's zoom now.
    func update() {
        guard let percent = document?.zoomPercent, percent.isFinite else { return }
        let title = "\(Int(percent.rounded()))%"
        guard title != levelButton.title else { return }  // an image calls this on every scroll
        levelButton.title = title
        levelButton.setAccessibilityLabel("Zoom level, \(title)")
    }

    /// Placed at the bottom right of `holder`, tracking the pointer over it.
    func install(in holder: NSView) {
        holder.addSubview(self)
        NSLayoutConstraint.activate([
            trailingAnchor.constraint(equalTo: holder.trailingAnchor, constant: -14),
            bottomAnchor.constraint(equalTo: holder.bottomAnchor, constant: -14),
        ])
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self)
        holder.addTrackingArea(area)
        tracking = (area, holder)
        // A tracking area added under the pointer sends no mouseEntered: content that opens or unlocks there.
        if let window = holder.window, window.isKeyWindow {
            hovering = holder.bounds.contains(holder.convert(window.mouseLocationOutsideOfEventStream, from: nil))
            fade()
        }
    }

    override func viewWillMove(toSuperview newSuperview: NSView?) {
        super.viewWillMove(toSuperview: newSuperview)
        guard newSuperview == nil, let tracking else { return }
        tracking.holder.removeTrackingArea(tracking.area)
        self.tracking = nil
    }

    override func mouseEntered(with event: NSEvent) { hovering = true; fade() }
    override func mouseExited(with event: NSEvent) { hovering = false; fade() }

    /// Scrolling over the control scrolls the document under it.
    override func scrollWheel(with event: NSEvent) {
        guard let holder = superview else { return super.scrollWheel(with: event) }
        let point = holder.convert(event.locationInWindow, from: nil)
        let under = holder.subviews.last { $0 !== self && $0.frame.contains(point) }?.hitTest(point)
        if let under { under.scrollWheel(with: event) } else { super.scrollWheel(with: event) }
    }

    private func fade() {
        let shows = hovering || menuOpen
        if shows { isHidden = false }
        let target: CGFloat = shows ? 1 : 0
        guard alphaValue != target else { return }
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduceMotion ? 0 : 0.15
            animator().alphaValue = target
        } completionHandler: { [weak self] in
            // Hidden once faded out, so the corner takes no clicks or scrolls meanwhile.
            MainActor.assumeIsolated {
                guard let self, !(self.hovering || self.menuOpen) else { return }
                self.isHidden = true
            }
        }
    }

    @objc private func zoomOut() { run("zoom-out") }
    @objc private func zoomIn() { run("zoom-in") }

    /// Actual Size, Zoom to Fit where the document has it, and fixed steps within its range.
    func levelMenu() -> NSMenu {
        let menu = NSMenu()
        let tools = Set(document?.tools.map(\.id) ?? [])
        for (title, id) in [("Actual Size", "zoom-actual"), ("Zoom to Fit", "zoom-fit")] where tools.contains(id) {
            let item = NSMenuItem(title: title, action: #selector(runFromMenu(_:)), keyEquivalent: "")
            item.representedObject = id
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())
        for percent in [50.0, 200, 400] where document?.zoomRange.contains(percent) == true {
            let item = NSMenuItem(title: "\(Int(percent))%", action: #selector(setLevel(_:)), keyEquivalent: "")
            item.representedObject = percent
            item.target = self
            item.state = document.map { Int($0.zoomPercent.rounded()) == Int(percent) } == true ? .on : .off
            menu.addItem(item)
        }
        return menu
    }

    @objc private func showLevelMenu() {
        menuOpen = true
        fade()
        // The control sits at the window's bottom, so the menu opens upward: its last item at the button.
        let menu = levelMenu()
        menu.popUp(positioning: menu.items.last, at: .zero, in: levelButton)
        menuOpen = false
        fade()
    }

    @objc private func runFromMenu(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? String { run(id) }
    }

    @objc private func setLevel(_ sender: NSMenuItem) {
        if let percent = sender.representedObject as? Double { document?.setZoom(percent, around: nil) }
    }
}
