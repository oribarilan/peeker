import AppKit
import PDFKit

/// The sidebar's page thumbnails. Several can be selected. In Edit mode they can be dragged to reorder (when the
/// file allows page changes, on macOS 27 and later), Delete removes the selected pages, and a right-click shows the
/// page commands.
final class PageThumbnails: PDFThumbnailView, NSMenuItemValidation {
    var isEditing = false {
        didSet { update() }
    }
    var allowsPageChanges = true {
        didSet { update() }
    }
    /// Runs a page command by id; false when it was refused.
    var onCommand: ((String) -> Bool)?
    /// Whether a page command can run now.
    var canRun: ((String) -> Bool)?
    private let pageMenu = NSMenu()

    init(commands: [(id: String, title: String)]) {
        super.init(frame: .zero)
        allowsMultipleSelection = true
        for command in commands {
            let item = NSMenuItem(title: command.title, action: #selector(runCommand(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = command.id
            pageMenu.addItem(item)
        }
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// Whether a thumbnail drag can reorder pages: from macOS 27. Before, PDFKit's copy of a dragged page isn't tied to
    /// the original, so a move can't be told from a page dropped in from elsewhere.
    nonisolated static let dragsReorderPages = ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 0))

    private func update() {
        allowsDragging = isEditing && allowsPageChanges && Self.dragsReorderPages
        menu = isEditing ? pageMenu : nil
    }

    override func deleteBackward(_ sender: Any?) {
        guard isEditing, onCommand?("delete-page") == true else { return NSSound.beep() }
    }

    @objc private func runCommand(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String, onCommand?(id) == true else { return NSSound.beep() }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let id = menuItem.representedObject as? String else { return true }
        return canRun?(id) ?? false
    }
}
