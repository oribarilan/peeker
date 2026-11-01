import AppKit
import PeekerKit

/// Stacks a document's sidebar panels.
enum Sidebar {
    /// Stacks a document's panels, or nil without any.
    static func make(_ panels: [SidebarPanel]) -> NSView? {
        panels.isEmpty ? nil : Column(panels)
    }

    /// Stacks the panels top to bottom by hand: info panels take the height of their text, list panels (outline,
    /// thumbnails) share what's left.
    private final class Column: NSView {
        private let panels: [SidebarPanel]
        private static let insets = NSEdgeInsets(top: 8, left: 10, bottom: 10, right: 10)
        private static let spacing: CGFloat = 14
        private static let minimumFillHeight: CGFloat = 80

        init(_ panels: [SidebarPanel]) {
            self.panels = panels
            super.init(frame: .zero)
            for panel in panels { addSubview(panel.view) }
        }

        required init?(coder: NSCoder) { fatalError("not used") }
        override var isFlipped: Bool { true }

        override func layout() {
            super.layout()
            let insets = Self.insets
            let width = max(0, bounds.width - insets.left - insets.right)
            let top = insets.top + safeAreaInsets.top
            let heights = panels.map { panel -> CGFloat? in
                guard panel.sizing == .fit else { return nil }
                if let field = panel.view as? NSTextField {
                    return ceil(field.cell?.cellSize(forBounds: NSRect(x: 0, y: 0, width: width, height: .greatestFiniteMagnitude)).height ?? 0)
                }
                return panel.view.fittingSize.height
            }
            let fixed = heights.compactMap { $0 }.reduce(0, +) + Self.spacing * CGFloat(panels.count - 1)
            let fillCount = CGFloat(heights.count { $0 == nil })
            let fillHeight = max(Self.minimumFillHeight, (bounds.height - top - insets.bottom - fixed) / max(fillCount, 1))
            var y = top
            for (panel, height) in zip(panels, heights) {
                let height = height ?? fillHeight
                panel.view.frame = NSRect(x: insets.left, y: y, width: width, height: height)
                y += height + Self.spacing
            }
        }
    }
}
