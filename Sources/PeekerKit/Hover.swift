import AppKit

/// Peeker's one hover look, for everything clickable without a button frame of its own: a faint rounded tint in the
/// accent color behind what the pointer is over.
@MainActor public enum HoverStyle {
    public static let cornerRadius: CGFloat = 6
    /// Whether the user asked macOS to reduce motion; tests replace it.
    nonisolated(unsafe) public static var reducesMotion: () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    /// How long the tint takes to come and go: none with Reduce Motion.
    public static var fade: TimeInterval { reducesMotion() ? 0 : 0.1 }
    /// The accent (the user's, or the app's under Multicolor) at 12% in light and 18% in dark.
    public static let color = NSColor(name: "PeekerHover") { appearance in
        let dark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return NSColor.controlAccentColor.withAlphaComponent(dark ? 0.18 : 0.12)
    }
}

/// The hover tint as a view: place it behind content and set `isHovered`. Clicks go through it.
public final class HoverFill: NSView {
    public var isHovered = false {
        didSet {
            guard isHovered != oldValue else { return }
            let target: CGFloat = isHovered ? 1 : 0
            NSAnimationContext.runAnimationGroup { context in
                context.duration = HoverStyle.fade
                animator().alphaValue = target
            }
        }
    }

    public override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = HoverStyle.cornerRadius
        alphaValue = 0
    }

    public required init?(coder: NSCoder) { nil }

    public override var wantsUpdateLayer: Bool { true }
    public override func updateLayer() { layer?.backgroundColor = HoverStyle.color.cgColor }
    public override func viewDidChangeEffectiveAppearance() { needsDisplay = true }
    public override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// A table row that shows the hover tint while `isHovered`, never while selected.
public final class HoverRowView: NSTableRowView {
    public let hoverFill = HoverFill()
    public var isHovered = false {
        didSet { update() }
    }

    public override var isSelected: Bool {
        didSet { update() }
    }

    public override init(frame: NSRect) {
        super.init(frame: frame)
        addSubview(hoverFill, positioned: .below, relativeTo: nil)  // under the cells the table adds
    }

    public required init?(coder: NSCoder) { nil }

    public override func layout() {
        super.layout()
        hoverFill.frame = bounds.insetBy(dx: 6, dy: 1)
    }

    private func update() { hoverFill.isHovered = isHovered && !isSelected }
}
