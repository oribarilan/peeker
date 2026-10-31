import AppKit

/// Shown in place of a document that couldn't open: the reason, centered, and a Reopen button.
final class FailureView: NSView {
    private let onReopen: () -> Void

    init(message: String, onReopen: @escaping () -> Void) {
        self.onReopen = onReopen
        super.init(frame: .zero)
        let label = NSTextField(wrappingLabelWithString: message)
        label.alignment = .center
        label.textColor = .secondaryLabelColor
        let retry = NSButton(title: "Reopen", target: self, action: #selector(reopen))
        let stack = NSStackView(views: [label, retry])
        stack.orientation = .vertical
        stack.alignment = .centerX
        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -40),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    @objc private func reopen() { onReopen() }
}
