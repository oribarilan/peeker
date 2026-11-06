import Foundation
import PeekerKit

/// The delimiter and header row picked for each file in the View menu, kept in the app's preferences by path, the
/// most recent 500.
@MainActor struct FileChoices {
    struct Choice: Codable, Equatable {
        var delimiter: Delimiter
        var header: Bool
    }

    private struct Entry: Codable {
        let path: String
        let choice: Choice
    }

    private let preferences: PluginPreferences?
    private static let key = "files", limit = 500

    init(_ preferences: PluginPreferences?) {
        self.preferences = preferences
    }

    func choice(for url: URL) -> Choice? {
        entries.last { $0.path == url.path }?.choice
    }

    func remember(_ choice: Choice, for url: URL) {
        guard let preferences else { return }
        let kept = (entries.filter { $0.path != url.path } + [Entry(path: url.path, choice: choice)]).suffix(Self.limit)
        guard let data = try? JSONEncoder().encode(Array(kept)), let json = String(data: data, encoding: .utf8) else { return }
        preferences.set(json, for: Self.key)
    }

    /// Anything unreadable counts as nothing remembered.
    private var entries: [Entry] {
        guard let json = preferences?.string(Self.key) else { return [] }
        return (try? JSONDecoder().decode([Entry].self, from: Data(json.utf8))) ?? []
    }
}
