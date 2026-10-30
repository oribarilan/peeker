// Drives Peeker and Finder for hand-style checks: window lists, screenshots, Finder selection, key presses, and the
// Accessibility tree (menus, toolbar pop-ups). Needs Accessibility and Screen Recording for the terminal running it,
// and an unlocked screen for everything except `locked`.
//
// usage: drive locked                              exit 0 when the screen is locked (prints yes/no)
//        drive windows [owner]                     on-screen windows: id, owner, layer, size, title
//        drive shot <owner> <out.png> [title]      screenshot of the owner's largest window (or the one with that title)
//        drive select <path>                       activate Finder and select <path>
//        drive key <space|escape|down|up|return>   press a key, as the keyboard would
//        drive tree <process> [depth]              print the Accessibility tree of the process's windows
//        drive choose <process> <item>             pick <item> in the front window's toolbar pop-up (Open With)
//        drive menu <process> <menu> <item>        press a menu item, e.g. Peeker "File" "Close"
//        drive menuextra <process> [item]          open the process's menu bar icon menu and print it, or press <item>
import AppKit
import ApplicationServices
import CoreGraphics

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

// MARK: Screen and windows

func screenLocked() -> Bool {
    (CGSessionCopyCurrentDictionary() as? [String: Any])?["CGSSessionScreenIsLocked"] as? Bool ?? false
}

struct Window {
    let id: Int, owner: String, layer: Int, width: Int, height: Int, title: String
}

func windows(owner: String? = nil) -> [Window] {
    let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    return list.compactMap { info in
        guard let id = info[kCGWindowNumber as String] as? Int, let name = info[kCGWindowOwnerName as String] as? String,
              owner == nil || name == owner, let bounds = info[kCGWindowBounds as String] as? [String: Double] else { return nil }
        return Window(id: id, owner: name, layer: info[kCGWindowLayer as String] as? Int ?? 0, width: Int(bounds["Width"] ?? 0),
                      height: Int(bounds["Height"] ?? 0), title: info[kCGWindowName as String] as? String ?? "")
    }
}

func run(_ path: String, _ arguments: [String]) -> Int32 {
    let process = Process()
    process.executableURL = URL(filePath: path)
    process.arguments = arguments
    do { try process.run() } catch { fail("can't run \(path): \(error)") }
    process.waitUntilExit()
    return process.terminationStatus
}

// MARK: Keyboard and Finder

let keyCodes: [String: CGKeyCode] = ["space": 49, "escape": 53, "down": 125, "up": 126, "return": 36]

func press(_ keyCode: CGKeyCode) {
    for down in [true, false] {
        CGEvent(keyboardEventSource: CGEventSource(stateID: .hidSystemState), virtualKey: keyCode, keyDown: down)?.post(tap: .cghidEventTap)
        usleep(20_000)
    }
}

func selectInFinder(_ path: String) {
    let escaped = URL(filePath: path).standardizedFileURL.path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    var error: NSDictionary?
    NSAppleScript(source: """
        tell application "Finder"
            activate
            reveal (POSIX file "\(escaped)" as alias)
            select (POSIX file "\(escaped)" as alias)
        end tell
        """)?.executeAndReturnError(&error)
    if let error { fail("finder: \(error[NSAppleScript.errorMessage] ?? error)") }
}

// MARK: Accessibility

func attr<T>(_ element: AXUIElement, _ name: String) -> T? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
    return value as? T
}

func children(_ element: AXUIElement) -> [AXUIElement] { attr(element, kAXChildrenAttribute) ?? [] }
func role(_ element: AXUIElement) -> String { attr(element, kAXRoleAttribute) ?? "" }

func label(_ element: AXUIElement) -> String {
    [kAXTitleAttribute, kAXDescriptionAttribute, kAXHelpAttribute].compactMap { attr(element, $0) as String? }.first { !$0.isEmpty } ?? ""
}

func application(_ name: String) -> AXUIElement {
    guard AXIsProcessTrusted() else { fail("not trusted: grant Accessibility to this terminal") }
    guard let running = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == name }) else { fail("\(name) isn't running") }
    return AXUIElementCreateApplication(running.processIdentifier)
}

func axWindows(_ app: AXUIElement) -> [AXUIElement] {
    (attr(app, kAXWindowsAttribute) as [AXUIElement]? ?? []).filter { role($0) == kAXWindowRole }
}

func dump(_ element: AXUIElement, depth: Int, max: Int) {
    var line = String(repeating: "  ", count: depth) + role(element)
    let text = label(element)
    if !text.isEmpty { line += " “\(text)”" }
    if let value: String = attr(element, kAXValueAttribute), !value.isEmpty {
        line += " = " + value.prefix(120).replacingOccurrences(of: "\n", with: "⏎")
    }
    print(line)
    guard depth < max else { return }
    for child in children(element) { dump(child, depth: depth + 1, max: max) }
}

func find(_ element: AXUIElement, depth: Int = 0, where match: (AXUIElement) -> Bool) -> AXUIElement? {
    if match(element) { return element }
    guard depth < 30 else { return nil }
    for child in children(element) {
        if let found = find(child, depth: depth + 1, where: match) { return found }
    }
    return nil
}

func press(_ element: AXUIElement, _ action: String = kAXPressAction) {
    let result = AXUIElementPerformAction(element, action as CFString)
    if result != .success { fail("\(action) failed: \(result.rawValue)") }
}

/// Opens a menu-owning element, then presses the item titled `item` inside it, or prints the menu when `item` is nil.
func pick(in owner: AXUIElement, item: String?) {
    press(owner)
    usleep(400_000)
    guard let item else {
        dump(owner, depth: 0, max: 4)
        // DRIVE_HOLD=<seconds> keeps the menu open, for a screenshot taken meanwhile.
        usleep(UInt32((Double(ProcessInfo.processInfo.environment["DRIVE_HOLD"] ?? "") ?? 0) * 1_000_000))
        press(owner, kAXCancelAction)
        return
    }
    guard let found = find(owner, where: { role($0) == kAXMenuItemRole && label($0) == item }) else {
        AXUIElementPerformAction(owner, kAXCancelAction as CFString)
        fail("no item “\(item)”")
    }
    press(found)
}

// MARK: Commands

let args = Array(CommandLine.arguments.dropFirst())
func arg(_ index: Int) -> String {
    guard args.indices.contains(index) else { fail("missing argument; see the usage at the top of drive.swift") }
    return args[index]
}

switch args.first ?? "" {
case "locked":
    print(screenLocked() ? "yes" : "no")
    exit(screenLocked() ? 0 : 1)
case "windows":
    for w in windows(owner: args.count > 1 ? args[1] : nil) { print(w.id, w.owner, "layer", w.layer, "\(w.width)x\(w.height)", w.title) }
case "shot":
    if screenLocked() { fail("the screen is locked: macOS captures nothing until it's unlocked") }
    let candidates = windows(owner: arg(1)).filter { args.count < 4 || $0.title == args[3] }
    guard let window = candidates.max(by: { $0.width * $0.height < $1.width * $1.height }) else { fail("no window for \(arg(1))") }
    exit(run("/usr/sbin/screencapture", ["-x", "-o", "-l\(window.id)", arg(2)]))
case "select":
    selectInFinder(arg(1))
case "key":
    guard let code = keyCodes[arg(1)] else { fail("keys: \(keyCodes.keys.sorted().joined(separator: ", "))") }
    press(code)
case "tree":
    let app = application(arg(1))
    for window in axWindows(app) { dump(window, depth: 0, max: args.count > 2 ? Int(args[2]) ?? 12 : 12) }
case "choose":
    guard let window = axWindows(application(arg(1))).first else { fail("no window") }
    guard let popup = find(window, where: { role($0) == kAXPopUpButtonRole }) else { fail("no pop-up in the front window") }
    pick(in: popup, item: arg(2))
case "menu":
    guard let bar: AXUIElement = attr(application(arg(1)), kAXMenuBarAttribute),
          let menu = children(bar).first(where: { label($0) == arg(2) }),
          let item = find(menu, where: { role($0) == kAXMenuItemRole && label($0) == arg(3) }) else { fail("no menu item \(arg(2)) > \(arg(3))") }
    press(item)
case "menuextra":
    guard let extras: AXUIElement = attr(application(arg(1)), "AXExtrasMenuBar"), let icon = children(extras).first else { fail("no menu bar icon") }
    pick(in: icon, item: args.count > 2 ? args[2] : nil)
default:
    fail("usage: drive locked|windows|shot|select|key|tree|choose|menu|menuextra ...; see the top of drive.swift")
}
