import AppKit
import PDFKit
import PeekerKit

/// A password-protected PDF before it's unlocked: a lock, the file's name and a password field. Either password hands
/// the host a `PDFPluginDocument`, editable within the file's permissions, which keeps the password in memory for
/// saving. The Peek panel only says what it is.
final class LockedPDFDocument: PluginDocument {
    private let url: URL
    /// False in the Peek panel, which can't take typing.
    let canUnlock: Bool
    var onReplace: ((any PluginDocument) -> Void)?
    private let root = NSView()
    private let field = NSSecureTextField()
    private let messageLabel = NSTextField(wrappingLabelWithString: "")

    private let preferences: PluginPreferences?
    /// A crash-recovery copy of edits made after an earlier unlock, kept sealed until the PDF is unlocked again.
    private var held: SealedEdits?
    static let unlockToSave = "Unlock this PDF to save its changes."
    static let misfitMessage =
        "The changes recovered for this PDF no longer fit it, since the file changed. Close the window and choose Don't Save to drop them."
    static let otherPasswordMessage =
        "These changes were made after unlocking with this PDF's other password. Type that one to get them back, or close the window and choose Don't Save to drop them."

    init(url: URL, canUnlock: Bool, preferences: PluginPreferences? = nil) {
        self.url = url
        self.canUnlock = canUnlock
        self.preferences = preferences
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
        var key = RecoveryKey(password: password)
        var recovered: Data?
        if let held {
            key = RecoveryKey(password: password, salt: held.salt)
            guard let opened = key.open(held) else {
                messageLabel.stringValue = Self.otherPasswordMessage
                NSSound.beep()
                return false
            }
            recovered = opened
        }
        let lock = PDFLock(password: password, isPermissionsPassword: document.permissionsStatus == .owner)
        let unlocked = PDFPluginDocument(
            url: url, document: document, info: checked.info, editable: true,
            uneditableReason: PDFPlugin.uneditableReason(checked, document), preferences: preferences, lock: lock,
            recoveryKey: key)
        if let recovered, !unlocked.restore(encoded: recovered) {
            messageLabel.stringValue = Self.misfitMessage
            NSSound.beep()
            return false
        }
        onReplace?(unlocked)
        return true
    }

    // Recovered edits wait, sealed, until the PDF is unlocked; the window stays edited meanwhile.

    func restore(encoded edits: Data) -> Bool {
        guard canUnlock, let sealed = try? JSONDecoder().decode(SealedEdits.self, from: edits) else { return false }
        held = sealed
        return true
    }

    func unsavedEdits() -> UnsavedEdits? { held.map(UnsavedEdits.init) }

    func save(_ edits: UnsavedEdits, accepting offer: SaveOffer?) async throws(PluginError) { throw PluginError(Self.unlockToSave) }

    func saveAs(_ edits: UnsavedEdits?, to destination: URL, accepting offer: SaveOffer?) async throws(PluginError) {
        guard edits == nil else { throw PluginError(Self.unlockToSave) }
        try await FileReplacement.copy(url, to: destination)
    }

    func revertEdits() { held = nil }
}
