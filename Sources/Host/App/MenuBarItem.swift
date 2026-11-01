import AppKit

/// Peeker's icon in the menu bar, there whenever it runs: Settings, Check for Updates, Open at Login and Quit, and a red dot while the
/// config has problems or Space in Finder is missing Accessibility, with a menu line saying which.
final class MenuBarItem {
    /// What the icon and its menu show.
    struct State: Equatable {
        let dot: Bool
        let problemsLine: String?
        let accessibilityLine: Bool

        init(dot: Bool, problemsLine: String?, accessibilityLine: Bool) {
            self.dot = dot
            self.problemsLine = problemsLine
            self.accessibilityLine = accessibilityLine
        }

        init(problems: Int, needsAccessibility: Bool) {
            self.init(dot: problems > 0 || needsAccessibility, problemsLine: problems > 0 ? MenuBarItem.problemsTitle(count: problems) : nil,
                      accessibilityLine: needsAccessibility)
        }
    }

    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let problemsItem: NSMenuItem
    private let accessibilityItem: NSMenuItem
    private let dot = CALayer()

    init(target: AppDelegate) {
        problemsItem = NSMenuItem(title: "", action: #selector(AppDelegate.showConfigFileSettings(_:)), keyEquivalent: "")
        accessibilityItem = NSMenuItem(title: "Space in Finder needs Accessibility…", action: #selector(AppDelegate.showPermissionsSettings(_:)), keyEquivalent: "")
        for line in [problemsItem, accessibilityItem] {
            line.target = target
            line.isHidden = true
        }
        item.menu = Self.menu(target: target, lines: [problemsItem, accessibilityItem])
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

    /// The icon's menu: the status `lines` (hidden until there's something to say), then the app's commands.
    static func menu(target: AppDelegate, lines: [NSMenuItem]) -> NSMenu {
        let menu = NSMenu()
        lines.forEach(menu.addItem)
        let commands = [("Settings…", #selector(AppDelegate.showSettings(_:))), ("Check for Updates…", #selector(AppDelegate.checkForUpdates(_:))),
                        ("Open at Login", #selector(AppDelegate.toggleOpenAtLogin(_:)))]
        for (title, action) in commands {
            menu.addItem(withTitle: title, action: action, keyEquivalent: "").target = target
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Peeker", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    func show(_ state: State) {
        if let button = item.button {
            // Top right of the icon; the button has its size by now, which it may not have had at creation.
            dot.frame = CGRect(x: button.bounds.maxX - 8, y: button.isFlipped ? 2 : button.bounds.maxY - 8, width: 6, height: 6)
        }
        dot.isHidden = !state.dot
        problemsItem.isHidden = state.problemsLine == nil
        problemsItem.title = state.problemsLine ?? ""
        accessibilityItem.isHidden = !state.accessibilityLine
        let notes = [state.problemsLine?.lowercased(), state.accessibilityLine ? "needs Accessibility" : nil].compactMap { $0 }
        item.button?.setAccessibilityLabel((["Peeker"] + notes).joined(separator: ", "))
    }

    static func problemsTitle(count: Int) -> String {
        "Config has \(count) \(count == 1 ? "problem" : "problems")"
    }
}
