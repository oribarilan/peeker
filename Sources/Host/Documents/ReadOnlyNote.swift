import AppKit

/// A read-only document's content in the Editor, with a one-line note above it, under the toolbar, giving the reason.
final class ReadOnlyNote: NSView {
    let reason: String

    init(reason: String, content: NSView) {
        self.reason = reason
        super.init(frame: .zero)
        let label = NSTextField(labelWithString: reason)
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byTruncatingTail
        label.toolTip = reason  // the whole reason when the window is too narrow for it
        for view in [label, content] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -10),
            label.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 5),
            content.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 5),
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }
}
