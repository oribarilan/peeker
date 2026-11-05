import Foundation

/// Small settings a plugin keeps between launches, such as a text size, in the app's preferences under
/// `plugins.<id>.`. Anything can write that file, so check what you read and fall back to your default.
public struct PluginPreferences: Sendable {
    private let defaults: UserDefaults
    private let prefix: String

    public init(pluginID: String, defaults: UserDefaults) {
        self.defaults = defaults
        prefix = "plugins.\(pluginID)."
    }

    public func double(_ key: String) -> Double? { defaults.object(forKey: prefix + key) as? Double }
    public func bool(_ key: String) -> Bool? { defaults.object(forKey: prefix + key) as? Bool }
    public func string(_ key: String) -> String? { defaults.object(forKey: prefix + key) as? String }
    public func set(_ value: String, for key: String) { defaults.set(value, forKey: prefix + key) }
    public func set(_ value: Double, for key: String) { defaults.set(value, forKey: prefix + key) }
    public func set(_ value: Bool, for key: String) { defaults.set(value, forKey: prefix + key) }
}
