import AppKit

/// The Crop and Cancel buttons beside a crop rectangle. They live in the scroll view, not on the zoomed image, so
/// they keep their size at any zoom.
final class CropControls: NSView {
    let crop = NSButton(title: "Crop", target: nil, action: nil)
    let cancel = NSButton(title: "Cancel", target: nil, action: nil)
    var onCrop: () -> Void = {}
    var onCancel: () -> Void = {}

    init() {
        super.init(frame: .zero)
        crop.keyEquivalent = "\r"
        cancel.keyEquivalent = "\u{1b}"
        for button in [crop, cancel] {
            button.target = self
            button.action = #selector(pressed(_:))
        }
        let stack = NSStackView(views: [cancel, crop])
        stack.frame.size = stack.fittingSize
        frame.size = stack.fittingSize
        addSubview(stack)
        isHidden = true
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    @objc private func pressed(_ sender: NSButton) {
        sender === crop ? onCrop() : onCancel()
    }

    /// Where the buttons go, in the coordinates of the view holding them (flipped, like a scroll view, or not):
    /// their trailing edge on the selection's right edge, just below it, or just inside its bottom when that would
    /// leave `visible`; always inside `visible`.
    static func frame(size: CGSize, selection: CGRect, visible: CGRect, flipped: Bool) -> CGRect {
        guard !flipped else {
            let mirror = { (rect: CGRect) in CGRect(x: rect.minX, y: -rect.maxY, width: rect.width, height: rect.height) }
            return mirror(frame(size: size, selection: mirror(selection), visible: mirror(visible), flipped: false))
        }
        let gap: CGFloat = 6
        let below = selection.minY - gap - size.height
        let y = below >= visible.minY ? below : selection.minY + gap
        let x = selection.maxX - size.width
        return CGRect(
            x: min(max(x, visible.minX), visible.maxX - size.width),
            y: min(max(y, visible.minY), visible.maxY - size.height), width: size.width, height: size.height)
    }
}
