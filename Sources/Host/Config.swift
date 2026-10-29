import Foundation
import PreviewPPKit

/// The user's dotfile: `~/.config/previewpp/config`, or `$PPP_CONFIG`.
///
///     # comments start with #
///     disable = csv, csv-web
///     open.csv = csv-proc
///     key.markdown.toggle-source = cmd+shift+e
struct Config {
    var disabled: Set<String> = []
    /// Lowercased file extension -> plugin id.
    var routes: [String: String] = [:]
    /// "pluginID.commandID" -> shortcut override.
    var keys: [String: Shortcut] = [:]
    var pluginDirectories: [URL] = []

    static var defaultURL: URL {
        if let path = ProcessInfo.processInfo.environment["PPP_CONFIG"] { return URL(filePath: path) }
        return FileManager.default.homeDirectoryForCurrentUser.appending(path: ".config/previewpp/config")
    }

    static func load(from url: URL = defaultURL) -> Config {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return Config() }
        return Config(parsing: text)
    }

    init() {}

    init(parsing text: String) {
        for (number, rawLine) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = rawLine.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0].trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2, !parts[1].isEmpty else {
                Self.warn("line \(number + 1): expected key = value")
                continue
            }
            let (key, value) = (parts[0], parts[1])
            switch key {
            case "disable":
                disabled.formUnion(value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
            case "plugins.dir":
                pluginDirectories.append(URL(filePath: (value as NSString).expandingTildeInPath))
            case _ where key.hasPrefix("open."):
                routes[String(key.dropFirst(5)).lowercased()] = value
            case _ where key.hasPrefix("key."):
                if let shortcut = Shortcut(parsing: value) { keys[String(key.dropFirst(4))] = shortcut }
                else { Self.warn("line \(number + 1): can't parse shortcut '\(value)'") }
            default:
                Self.warn("line \(number + 1): unknown key '\(key)'")
            }
        }
    }

    private static func warn(_ message: String) {
        FileHandle.standardError.write(Data("config: \(message)\n".utf8))
    }
}
