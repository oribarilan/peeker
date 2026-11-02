import AppKit

/// Whether document windows show the info sidebar, and how wide it is: one choice for every window, kept across
/// launches in the app's preferences. It's window state rather than a setting, so it stays out of the config file.
final class SidebarMemory {
    static let shared = SidebarMemory(defaults: .standard)
    /// Posted, with the memory as its object, when the choice changes.
    static let didChange = Notification.Name("SidebarMemoryDidChange")

    private let defaults: UserDefaults?
    private var values: [String: Any] = [:]

    /// Without `defaults`, it remembers only while it exists, for tests and benchmarks.
    init(defaults: UserDefaults?) {
        self.defaults = defaults
    }

    var isHidden: Bool { value("sidebarHidden") as? Bool ?? false }
    var width: CGFloat? { (value("sidebarWidth") as? Double).map { CGFloat($0) } }

    /// Keeps a choice the user made in some window and tells the other windows; nil keeps the width as it was.
    func remember(hidden: Bool, width: CGFloat?) {
        let widthChanged = width.map { new in self.width.map { abs($0 - new) >= 1 } ?? true } ?? false
        guard hidden != isHidden || widthChanged else { return }
        set(hidden, "sidebarHidden")
        if let width, widthChanged { set(Double(width), "sidebarWidth") }
        NotificationCenter.default.post(name: Self.didChange, object: self)
    }

    private func value(_ key: String) -> Any? { defaults?.object(forKey: key) ?? values[key] }

    private func set(_ value: Any, _ key: String) {
        if let defaults { defaults.set(value, forKey: key) } else { values[key] = value }
    }
}
