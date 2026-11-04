import AppKit

/// Which first-use tips the user has seen, by `plugin.tool`, kept in the app's preferences. Without preferences (tests,
/// benchmarks) it remembers only while it exists.
final class TipStore {
    static let shared = TipStore(defaults: .standard)
    /// Where the seen tips are kept: their ids, one per line. Settings reads it to grey out Show Tips Again.
    static let key = "seenTips"
    private let defaults: UserDefaults?
    private var seen: Set<String>

    init(defaults: UserDefaults?) {
        self.defaults = defaults
        seen = Set((defaults?.string(forKey: Self.key) ?? "").split(separator: "\n").map(String.init))
    }

    var hasShownAny: Bool { !seen.isEmpty }
    func hasShown(_ id: String) -> Bool { seen.contains(id) }

    func markShown(_ id: String) {
        seen.insert(id)
        defaults?.set(seen.sorted().joined(separator: "\n"), forKey: Self.key)
    }

    func reset() {
        seen = []
        defaults?.removeObject(forKey: Self.key)
    }

    /// A plugin's tip with `{key}` filled in with the tool's key; without one, "press {key}" becomes "click <title>".
    static func text(_ tip: String, title: String, key: Shortcut?) -> String {
        guard let key else { return tip.replacingOccurrences(of: "press {key}", with: "click \(title)").replacingOccurrences(of: "{key}", with: title) }
        return tip.replacingOccurrences(of: "{key}", with: key.displayText)
    }
}
