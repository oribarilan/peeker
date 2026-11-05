import AppKit
import PeekerKit

/// The one-line trail under an Editor window's toolbar: every place in the tab's history, the current one marked.
/// Clicking a crumb goes there, as Back or Forward would, and the one under the pointer shows the hover tint. When it
/// doesn't fit, the oldest crumbs are cut first.
final class HistoryTrail: NSView {
    var onSelect: ((Int) -> Void)?
    private let stack = NSStackView()
    private(set) var crumbs: [NSButton] = []
    let hoverFill = HoverFill()
    private var current = 0

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 400, height: 24))
        stack.orientation = .horizontal
        stack.spacing = 4
        stack.setClippingResistancePriority(.defaultLow, for: .horizontal)  // crumbs truncate; the window stays resizable
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hoverFill)
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: 24),
        ])
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
                                       owner: self))
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func show(_ history: NavigationHistory) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        hoverFill.isHovered = false
        current = history.index
        crumbs = history.entries.enumerated().map { index, entry in
            crumb(entry, at: index, current: index == history.index)
        }
        for (index, crumb) in crumbs.enumerated() {
            if index > 0 { stack.addArrangedSubview(separator()) }
            stack.addArrangedSubview(crumb)
        }
    }

    private func crumb(_ entry: NavigationHistory.Entry, at index: Int, current: Bool) -> NSButton {
        let button = NSButton(title: entry.label, target: self, action: #selector(select(_:)))
        button.isBordered = false
        button.tag = index
        button.attributedTitle = NSAttributedString(string: entry.label, attributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: current ? .semibold : .regular),
            .foregroundColor: current ? NSColor.labelColor : NSColor.secondaryLabelColor,
        ])
        button.lineBreakMode = .byTruncatingTail
        // Later crumbs hold their width longer, so the oldest truncate first.
        button.setContentCompressionResistancePriority(NSLayoutConstraint.Priority(250 + Float(min(index, 400))), for: .horizontal)
        let detail = entry.title.map { "\(entry.url.lastPathComponent) › \($0)" } ?? entry.url.lastPathComponent
        button.toolTip = detail
        button.setAccessibilityLabel(current ? "\(detail), current" : detail)
        return button
    }

    private func separator() -> NSTextField {
        let label = NSTextField(labelWithString: "›")
        label.font = .systemFont(ofSize: 11)
        label.textColor = .tertiaryLabelColor
        label.setAccessibilityElement(false)
        return label
    }

    override func mouseMoved(with event: NSEvent) { hover(at: convert(event.locationInWindow, from: nil)) }
    override func mouseEntered(with event: NSEvent) { hover(at: convert(event.locationInWindow, from: nil)) }
    override func mouseExited(with event: NSEvent) { hoverFill.isHovered = false }

    /// Tints the crumb under `point`, except the current place.
    private func hover(at point: NSPoint) {
        let frames = crumbs.map { convert($0.frame, from: $0.superview) }
        guard let index = frames.firstIndex(where: { $0.contains(point) }), index != current else {
            hoverFill.isHovered = false
            return
        }
        hoverFill.frame = NSRect(x: frames[index].minX - 6, y: bounds.midY - 10, width: frames[index].width + 12, height: 20)
        hoverFill.isHovered = true
    }

    @objc private func select(_ sender: NSButton) {
        onSelect?(sender.tag)
    }
}
