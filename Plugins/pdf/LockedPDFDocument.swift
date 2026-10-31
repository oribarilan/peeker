import AppKit
import PDFKit
import PeekerKit

/// A password-protected PDF before it's unlocked: a lock, the file's name and a password field. The right password
/// hands the host a view-only `PDFPluginDocument`; nothing keeps the password. The Space panel only says what it is.
final class LockedPDFDocument: PluginDocument {
    static let viewOnlyReason = "This PDF is password protected, so Peeker opens it view-only."
    private let url: URL
    /// False in the Space panel, which can't take typing.
    let canUnlock: Bool
    var onReplace: ((any PluginDocument) -> Void)?
    private let root = NSView()
    private let field = NSSecureTextField()
    private let messageLabel = NSTextField(wrappingLabelWithString: "")

    init(url: URL, canUnlock: Bool) {
        self.url = url
        self.canUnlock = canUnlock
        let lock = NSImageView(image: NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "Locked") ?? NSImage())
        lock.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 40, weight: .regular)
        lock.contentTintColor = .secondaryLabelColor
        let name = NSTextField(labelWithString: "“\(url.lastPathComponent)” is password protected.")
        name.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        messageLabel.alignment = .center
        messageLabel.textColor = .secondaryLabelColor
        var views: [NSView] = [lock, name]
        if canUnlock {
            field.placeholderString = "Password"
            field.setAccessibilityLabel("Password")
            field.target = self
            field.action = #selector(unlockClicked(_:))
            field.widthAnchor.constraint(equalToConstant: 220).isActive = true
            let unlock = NSButton(title: "Unlock", target: self, action: #selector(unlockClicked(_:)))
            unlock.keyEquivalent = "\r"
            views += [field, unlock, messageLabel]
        } else {
            messageLabel.stringValue = "Open it in a window to unlock it."
            views.append(messageLabel)
        }
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: root.centerYAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualTo: root.widthAnchor, constant: -40),
        ])
    }

    var contentView: NSView { root }
    var focusView: NSView? { canUnlock ? field : nil }
    var message: String { messageLabel.stringValue }
    var password: String { field.stringValue }

    @objc private func unlockClicked(_ sender: Any?) {
        _ = unlock(with: field.stringValue)
    }

    /// Opens the PDF with `password` and hands it to the host. False, saying so, when the password is wrong.
    func unlock(with password: String) -> Bool {
        field.stringValue = ""
        guard canUnlock else { return false }
        let checked = try? PDFPlugin.check(url, password: password)
        guard let checked, let document = PeekerPDFDocument(url: url), document.unlock(withPassword: password) else {
            messageLabel.stringValue = "Wrong password."
            NSSound.beep()
            return false
        }
        onReplace?(PDFPluginDocument(url: url, document: document, info: checked.info, editable: true, uneditableReason: Self.viewOnlyReason))
        return true
    }
}
