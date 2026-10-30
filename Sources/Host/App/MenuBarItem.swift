import AppKit

/// Peeker's icon in the menu bar, there whenever it runs: Settings, Open at Login and Quit, and a red dot while the
/// config has problems.
final class MenuBarItem {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let problemsItem: NSMenuItem
    private let dot = CALayer()

    init(target: AppDelegate) {
        problemsItem = NSMenuItem(title: "", action: #selector(AppDelegate.showSettings(_:)), keyEquivalent: "")
        problemsItem.target = target
        problemsItem.isHidden = true
        let menu = NSMenu()
        menu.addItem(problemsItem)
        for (title, action) in [("Settings…", #selector(AppDelegate.showSettings(_:))), ("Open at Login", #selector(AppDelegate.toggleOpenAtLogin(_:)))] {
            menu.addItem(withTitle: title, action: action, keyEquivalent: "").target = target
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Peeker", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        guard let button = item.button else { return }
        let image = NSImage(systemSymbolName: "eye", accessibilityDescription: "Peeker")
        image?.isTemplate = true
        button.image = image
        button.wantsLayer = true
        dot.backgroundColor = NSColor.systemRed.cgColor
        dot.cornerRadius = 3
        dot.isHidden = true
        button.layer?.addSublayer(dot)
    }

    /// Shows or hides the red dot and the problems line.
    func show(problems count: Int) {
        if let button = item.button {
            // Top right of the icon; the button has its size by now, which it may not have had at creation.
            dot.frame = CGRect(x: button.bounds.maxX - 8, y: button.isFlipped ? 2 : button.bounds.maxY - 8, width: 6, height: 6)
        }
        dot.isHidden = count == 0
        problemsItem.isHidden = count == 0
        problemsItem.title = Self.problemsTitle(count: count)
        item.button?.setAccessibilityLabel(count == 0 ? "Peeker" : "Peeker, \(Self.problemsTitle(count: count).lowercased())")
    }

    static func problemsTitle(count: Int) -> String {
        "Config has \(count) \(count == 1 ? "problem" : "problems")"
    }
}
