import AppKit

/// Peeker's icon in the menu bar, there whenever it runs: Open, Settings, Check for Updates, Open at Login and Quit. A red dot
/// shows while the config has problems or the Peek panel is missing Accessibility, an accent dot while an update waits,
/// each with a menu line saying which.
final class MenuBarItem {
    enum Dot { case red, accent }

    /// What the icon and its menu show.
    struct State: Equatable {
        let dot: Dot?
        let problemsLine: String?
        let accessibilityLine: Bool
        let updateLine: String?

        init(dot: Dot?, problemsLine: String?, accessibilityLine: Bool, updateLine: String? = nil) {
            self.dot = dot
            self.problemsLine = problemsLine
            self.accessibilityLine = accessibilityLine
            self.updateLine = updateLine
        }

        /// The red dot wins over the accent one: a problem needs fixing, an update can wait.
        init(problems: Int, needsAccessibility: Bool, update: String? = nil) {
            let dot: Dot? = problems > 0 || needsAccessibility ? .red : update != nil ? .accent : nil
            self.init(
                dot: dot, problemsLine: problems > 0 ? MenuBarItem.problemsTitle(count: problems) : nil,
                accessibilityLine: needsAccessibility, updateLine: update.map { "Update to \($0)…" })
        }

        /// What VoiceOver reads for the icon: "Peeker", then what the dot is about.
        var accessibilityLabel: String {
            let notes = [problemsLine?.lowercased(), accessibilityLine ? "needs Accessibility" : nil, updateLine == nil ? nil : "update available"]
            return (["Peeker"] + notes.compactMap { $0 }).joined(separator: ", ")
        }
    }

    /// The menu lines that show only when there's something to say, hidden until then.
    struct Lines {
        let update: NSMenuItem
        let problems: NSMenuItem
        let accessibility: NSMenuItem
        var all: [NSMenuItem] { [update, problems, accessibility] }
    }

    /// The menu line shown while Accessibility is missing; it opens the Permissions pane.
    static let accessibilityTitle = "The Peek panel needs Accessibility…"

    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let lines: Lines
    private let dot = CALayer()

    init(target: AppDelegate) {
        lines = Self.lines(target: target)
        item.menu = Self.menu(target: target, lines: lines.all)
        guard let button = item.button else { return }
        let image = NSImage(systemSymbolName: "viewfinder", accessibilityDescription: "Peeker")
        image?.isTemplate = true
        button.image = image
        button.wantsLayer = true
        dot.cornerRadius = 3
        dot.isHidden = true
        button.layer?.addSublayer(dot)
    }

    static func lines(target: AppDelegate) -> Lines {
        let lines = Lines(
            update: NSMenuItem(title: "", action: #selector(AppDelegate.checkForUpdates(_:)), keyEquivalent: ""),
            problems: NSMenuItem(title: "", action: #selector(AppDelegate.showConfigFileSettings(_:)), keyEquivalent: ""),
            accessibility: NSMenuItem(title: accessibilityTitle, action: #selector(AppDelegate.showPermissionsSettings(_:)), keyEquivalent: ""))
        for line in lines.all {
            line.target = target
            line.isHidden = true
        }
        return lines
    }

    /// The icon's menu: the status `lines` (hidden until there's something to say), then the app's commands.
    static func menu(target: AppDelegate, lines: [NSMenuItem]) -> NSMenu {
        let menu = NSMenu()
        lines.forEach(menu.addItem)
        let commands = [
            ("Open…", #selector(AppDelegate.showOpenPanel(_:))), ("Settings…", #selector(AppDelegate.showSettings(_:))),
            ("Check for Updates…", #selector(AppDelegate.checkForUpdates(_:))),
            ("Open at Login", #selector(AppDelegate.toggleOpenAtLogin(_:))),
        ]
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
            button.effectiveAppearance.performAsCurrentDrawingAppearance {
                dot.backgroundColor = (state.dot == .accent ? NSColor(named: "AccentColor") ?? .controlAccentColor : .systemRed).cgColor
            }
        }
        dot.isHidden = state.dot == nil
        lines.update.isHidden = state.updateLine == nil
        lines.update.title = state.updateLine ?? ""
        lines.problems.isHidden = state.problemsLine == nil
        lines.problems.title = state.problemsLine ?? ""
        lines.accessibility.isHidden = !state.accessibilityLine
        item.button?.setAccessibilityLabel(state.accessibilityLabel)
    }

    static func problemsTitle(count: Int) -> String {
        "Config has \(count) \(count == 1 ? "problem" : "problems")"
    }
}
