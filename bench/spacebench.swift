// Presses Space in Finder on a selected file and times until a preview panel appears, so Finder's own Quick Look
// and Preview++'s hotkey panel are measured the same way. Needs Accessibility for the app running this (to post
// keys) and Automation for Finder (to select the file).
//
// usage: spacebench <file> [runs]       prints one line per run: owner and milliseconds to the new window
import AppKit
import CoreGraphics

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write(Data("usage: spacebench <file> [runs]\n".utf8))
    exit(2)
}
let file = URL(filePath: args[1]).standardizedFileURL
let runs = args.count > 2 ? Int(args[2]) ?? 5 : 5

guard AXIsProcessTrusted() else {
    print("not trusted: grant Accessibility to the app running this harness (System Settings > Privacy & Security > Accessibility)")
    exit(1)
}

func finder(_ source: String) {
    var error: NSDictionary?
    NSAppleScript(source: source)?.executeAndReturnError(&error)
    if let error { print("finder error: \(error[NSAppleScript.errorMessage] ?? error)") }
}

func press(_ keyCode: CGKeyCode) {
    for down in [true, false] {
        CGEvent(keyboardEventSource: CGEventSource(stateID: .hidSystemState), virtualKey: keyCode, keyDown: down)?.post(tap: .cghidEventTap)
    }
}

typealias Window = (id: Int, owner: String, area: Double)

func windows() -> [Window] {
    let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    return list.compactMap { info in
        guard let id = info[kCGWindowNumber as String] as? Int, let owner = info[kCGWindowOwnerName as String] as? String,
              let bounds = info[kCGWindowBounds as String] as? [String: Double] else { return nil }
        return (id, owner, (bounds["Width"] ?? 0) * (bounds["Height"] ?? 0))
    }
}

let escapedPath = file.path.replacingOccurrences(of: "\"", with: "\\\"")
finder("""
    tell application "Finder"
        activate
        reveal (POSIX file "\(escapedPath)" as alias)
        select (POSIX file "\(escapedPath)" as alias)
    end tell
    """)
usleep(800_000)

for run in 0...runs {  // run 0 is a warm-up
    let before = Set(windows().map(\.id))
    let start = DispatchTime.now()
    press(49)  // Space
    var found: Window?
    while found == nil, DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds < 5_000_000_000 {
        found = windows().first { !before.contains($0.id) && $0.area > 200 * 200 && $0.owner != "Window Server" }
        if found == nil { usleep(500) }
    }
    let ms = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1e6
    if run > 0 { print(found.map { "\($0.owner)\t\(String(format: "%.1f", ms))" } ?? "timeout") }
    usleep(300_000)
    press(53)  // Escape closes either panel
    usleep(700_000)
}
