import AppKit
import os

/// Reads Finder's selection over Apple Events (needs the Automation permission for Finder).
final class FinderBridge {
    private let script: NSAppleScript?
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "dev.peeker", category: "quicklook")

    init() {
        let source = """
            tell application "Finder" to set picked to selection as alias list
            set paths to ""
            repeat with f in picked
                set paths to paths & POSIX path of f & linefeed
            end repeat
            return paths
            """
        script = NSAppleScript(source: source)
        var error: NSDictionary?
        script?.compileAndReturnError(&error)
    }

    func selection() -> [URL] {
        var error: NSDictionary?
        guard let result = script?.executeAndReturnError(&error) else {
            Self.log.warning("finder: \(String(describing: error?[NSAppleScript.errorMessage] ?? "no selection"), privacy: .public)")
            return []
        }
        return (result.stringValue ?? "").split(separator: "\n").map { URL(filePath: String($0)) }
    }
}
