import Foundation

/// The release notes in `CHANGELOG.md`: one `## [x.y.z] - date` section per version, its notes as `- ` lines.
enum Changelog {
    struct Release: Equatable {
        let version: String
        let notes: [String]
    }

    /// The releases after `last` up to and including `current`, newest first. Unreleased and versions the file
    /// doesn't have are left out.
    static func releases(in text: String, after last: String, upTo current: String) -> [Release] {
        var releases: [Release] = []
        var version: String?
        var notes: [String] = []
        func finish() {
            if let version, isNewer(version, than: last), !isNewer(version, than: current) {
                releases.append(Release(version: version, notes: notes))
            }
        }
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("## ") {
                finish()
                version = line.firstMatch(of: /^## \[(\d+\.\d+\.\d+)\]/).map { String($0.1) }
                notes = []
            } else if version != nil, line.hasPrefix("- ") {
                notes.append(String(line.dropFirst(2)))
            }
        }
        finish()
        return releases.sorted { isNewer($0.version, than: $1.version) }
    }

    /// Whether version `a` comes after `b`, comparing each number in turn (0.10.0 after 0.9.0).
    static func isNewer(_ a: String, than b: String) -> Bool {
        let numbers = { (version: String) in version.split(separator: ".").map { Int($0) ?? 0 } }
        return numbers(b).lexicographicallyPrecedes(numbers(a))
    }
}

/// When the "Updated to Peeker" window shows after an update.
enum WhatsNew {
    enum Timing: Equatable { case never, now, withFirstWindow }

    /// What the last launch left behind about how this one came about.
    struct Marks: Equatable {
        let installedQuietly: Bool
        let relaunched: Bool
    }

    /// Where the last version run is kept.
    static let lastRunKey = "lastRunVersion"

    /// Nothing on a first run, the same or an older version, a development build, or with the window turned off.
    /// After a quiet install or at login it waits for a window the user opens; otherwise it shows at launch.
    static func timing(lastRun: String?, running: String, enabled: Bool, installedQuietly: Bool, atLogin: Bool) -> Timing {
        guard enabled, !running.hasSuffix("-dev"), let lastRun, Changelog.isNewer(running, than: lastRun) else { return .never }
        return installedQuietly || atLogin ? .withFirstWindow : .now
    }

    /// Reads the marks the updater left, and clears them so they count for one launch.
    static func takeMarks(from defaults: UserDefaults) -> Marks {
        let marks = Marks(installedQuietly: defaults.bool(forKey: Updater.quietInstallKey), relaunched: defaults.bool(forKey: Updater.relaunchKey))
        defaults.removeObject(forKey: Updater.quietInstallKey)
        defaults.removeObject(forKey: Updater.relaunchKey)
        return marks
    }
}
