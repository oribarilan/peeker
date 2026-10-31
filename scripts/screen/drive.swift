// Drives Peeker and Finder for hand-style checks: window lists, screenshots, Finder selection, key presses, and the
// Accessibility tree (menus, toolbar pop-ups). Needs Accessibility and Screen Recording for the terminal running it,
// and an unlocked screen for everything except `locked`.
//
// usage: drive locked                              exit 0 when the screen is locked (prints yes/no)
//        drive windows [owner]                     on-screen windows: id, owner, layer, size, title
//        drive shot <owner> <out.png> [title]      screenshot of the owner's largest window (or the one with that title)
//        drive select <path>                       activate Finder and select <path>
//        drive tree <process> [depth]              print the Accessibility tree of the process's windows
//        drive choose <process> <item>             pick <item> in the front window's toolbar pop-up (Open With)
//        drive menu <process> <menu> <item>        press a menu item, e.g. Peeker "File" "Close", and wait for the menu to close
//        drive menuextra <process> [item]          open the process's menu bar icon menu and print it, or press <item>
//        drive row <process> <title>               select the sidebar row titled <title> in any window
//        drive press <process> <label>             press the control (button, switch) labeled <label> in any window
//        drive fill <process> <label> <text>       focus the field with that placeholder or label and set its text
//        drive enabled <process> <label>           print whether the control labeled <label> is enabled
//        drive frame <process> <role> [label]      print the screen frame (x y width height) of the first such element
//        drive click <process> <x> <y> [count]     click at a screen point, only while <process> is in front
//        drive type <process> <text>               type <text>, only while <process> is in front
//        drive drag <process> <x y>...             press at the first point, drag through the rest, release at the last
//        drive keys <process> <combo>              press a combo such as opt+space, ctrl+cmd+h or return, only while <process> is in front
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
            set picked to (POSIX file "\(escaped)" as alias)
            -- Reuse the front window when it already shows the folder, rather than opening one per file.
            if (count of Finder windows) > 0 and ((target of front Finder window) as alias) is ((container of picked) as alias) then
                select picked
            else
                reveal picked
                select picked
            end if
        end tell
        """)?.executeAndReturnError(&error)
    if let error { fail("finder: \(error[NSAppleScript.errorMessage] ?? error)") }
}

/// Clicks and keys go to whichever app is in front, so they're sent only when it's the one under test.
func requireFront(_ process: String) {
    let front = NSWorkspace.shared.frontmostApplication?.localizedName ?? "nothing"
    if front != process { fail("\(process) isn't in front (\(front) is): not sending input") }
}

func click(at point: CGPoint, count: Int) {
    let source = CGEventSource(stateID: .hidSystemState)
    for index in 1...count {
        for type in [CGEventType.leftMouseDown, .leftMouseUp] {
            let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left)
            event?.setIntegerValueField(.mouseEventClickState, value: Int64(index))
            event?.flags = []  // a plain click, whatever modifiers the system thinks are held
            event?.post(tap: .cghidEventTap)
            usleep(30_000)
        }
    }
}

func drag(through points: [CGPoint]) {
    let source = CGEventSource(stateID: .hidSystemState)
    for (index, point) in points.enumerated() {
        let type: CGEventType = index == 0 ? .leftMouseDown : index == points.count - 1 ? .leftMouseUp : .leftMouseDragged
        let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left)
        event?.flags = []
        event?.post(tap: .cghidEventTap)
        usleep(16_000)
    }
}

/// ANSI key codes for the keys a combo can name.
let comboKeys: [String: CGKeyCode] = {
    var keys: [String: CGKeyCode] = ["space": 49, "return": 36, "tab": 48, "escape": 53, "delete": 51]
    for (key, code) in zip("asdfhgzxcv", [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]) { keys[String(key)] = CGKeyCode(code) }
    for (key, code) in zip("bqweryt123465=97-80]ou[ip", [11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35]) { keys[String(key)] = CGKeyCode(code) }
    for (key, code) in zip("lj'k;\\,/nm.", [37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47]) { keys[String(key)] = CGKeyCode(code) }
    return keys
}()

func pressCombo(_ combo: String) {
    var flags: CGEventFlags = []
    var code: CGKeyCode?
    for part in combo.lowercased().split(separator: "+").map(String.init) {
        switch part {
        case "cmd": flags.insert(.maskCommand)
        case "opt": flags.insert(.maskAlternate)
        case "ctrl": flags.insert(.maskControl)
        case "shift": flags.insert(.maskShift)
        default: code = comboKeys[part]
        }
    }
    guard let code else { fail("no key in “\(combo)”") }
    let source = CGEventSource(stateID: .hidSystemState)
    for down in [true, false] {
        let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down)
        event?.flags = flags
        event?.post(tap: .cghidEventTap)
        usleep(30_000)
    }
    releaseModifiers(source)
}

/// Posts the release of each modifier key. A key event's own flags leave them set in the system's state, so later
/// typing, from this run or the user's, would arrive as shortcuts.
func releaseModifiers(_ source: CGEventSource?) {
    for code: CGKeyCode in [55, 56, 58, 59] {  // command, shift, option, control
        let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false)
        event?.type = .flagsChanged
        event?.flags = []
        event?.post(tap: .cghidEventTap)
    }
}

func type(_ text: String) {
    let source = CGEventSource(stateID: .hidSystemState)
    for character in text.utf16 {
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: down)
            var unit = character
            event?.keyboardSetUnicodeString(stringLength: 1, unicodeString: &unit)
            event?.flags = []  // text, not shortcuts, whatever modifiers the system thinks are held
            event?.post(tap: .cghidEventTap)
            usleep(15_000)
        }
    }
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
    // A button that closes its sheet is gone by the time the call returns, which reports an error after it worked.
    if result != .success && result != .cannotComplete && result != .actionUnsupported { fail("\(action) failed: \(result.rawValue)") }
}

/// Opens a menu-owning element, then presses the item titled `item` inside it, or prints the menu when `item` is nil.
func pick(in owner: AXUIElement, item: String?) {
    // A menu tracks modally, so the press reports "cannot complete" even though the menu opened; don't wait on it.
    AXUIElementSetMessagingTimeout(owner, 0.5)
    let result = AXUIElementPerformAction(owner, kAXPressAction as CFString)
    if result != .success && result != .cannotComplete { fail("press failed: \(result.rawValue)") }
    usleep(400_000)
    guard let item else {
        dump(owner, depth: 0, max: 4)
        // DRIVE_HOLD=<seconds> keeps the menu open, for a screenshot taken meanwhile.
        usleep(UInt32((Double(ProcessInfo.processInfo.environment["DRIVE_HOLD"] ?? "") ?? 0) * 1_000_000))
        press(comboKeys["escape"]!)
        return
    }
    guard let found = find(owner, where: { role($0) == kAXMenuItemRole && label($0) == item }) else {
        press(comboKeys["escape"]!)
        fail("no item “\(item)”")
    }
    press(found)
}

/// The first button, switch, checkbox or menu button labeled `title` in any of the process's windows.
func control(_ process: String, _ title: String) -> AXUIElement? {
    let roles: Set<String> = [kAXButtonRole, kAXCheckBoxRole, "AXSwitch", kAXMenuButtonRole, kAXRadioButtonRole]
    let isControl = { (element: AXUIElement) in roles.contains(role(element)) }
    return axWindows(application(process)).lazy.compactMap { window in
        find(window, where: { isControl($0) && label($0) == title }) ?? controlAfterText(title, in: window, isControl: isControl)
    }.first
}

/// A form row's control whose label is a separate text, as SwiftUI lays out a `Toggle` in a grouped `Form`: the first
/// control after the text in the same parent.
func controlAfterText(_ title: String, in root: AXUIElement, isControl: (AXUIElement) -> Bool) -> AXUIElement? {
    guard let text = find(root, where: { role($0) == kAXStaticTextRole && (attr($0, kAXValueAttribute) as String?) == title }),
          let parent: AXUIElement = attr(text, kAXParentAttribute) else { return nil }
    let siblings = children(parent)
    guard let index = siblings.firstIndex(where: { CFEqual($0, text) }) else { return nil }
    return siblings[(index + 1)...].first(where: isControl)
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
    // The menu can stay drawn for a moment after the press, and a click or key sent meanwhile would land on it.
    // Open menus are windows at the pop-up menu level (101).
    var waits = 0
    while waits < 60, windows(owner: arg(1)).contains(where: { $0.layer == 101 }) {
        usleep(50_000)
        waits += 1
    }
case "menuextra":
    guard let extras: AXUIElement = attr(application(arg(1)), "AXExtrasMenuBar"), let icon = children(extras).first else { fail("no menu bar icon") }
    pick(in: icon, item: args.count > 2 ? args[2] : nil)
case "row":
    let isRow = { (element: AXUIElement) in
        role(element) == kAXRowRole && find(element, where: { label($0) == arg(2) || (attr($0, kAXValueAttribute) as String?) == arg(2) }) != nil
    }
    guard let row = axWindows(application(arg(1))).lazy.compactMap({ find($0, where: isRow) }).first else { fail("no sidebar row “\(arg(2))”") }
    let result = AXUIElementSetAttributeValue(row, kAXSelectedAttribute as CFString, kCFBooleanTrue)
    if result != .success { fail("can't select “\(arg(2))”: \(result.rawValue)") }
case "press":
    guard let control = control(arg(1), arg(2)) else { fail("no control “\(arg(2))”") }
    press(control)
case "fill":
    let isField = { (element: AXUIElement) in role(element) == kAXTextFieldRole }
    guard let field = axWindows(application(arg(1))).lazy.compactMap({ window in
        find(window, where: { isField($0) && ((attr($0, kAXPlaceholderValueAttribute) as String?) == arg(2) || label($0) == arg(2)) })
            ?? controlAfterText(arg(2), in: window, isControl: isField)
    }).first
    else { fail("no field “\(arg(2))”") }
    // Sets the text only: a Return key would go to whichever app is in front, which may not be this one.
    AXUIElementSetAttributeValue(field, kAXFocusedAttribute as CFString, kCFBooleanTrue)
    AXUIElementSetAttributeValue(field, kAXValueAttribute as CFString, arg(3) as CFString)
case "enabled":
    guard let control = control(arg(1), arg(2)) else { fail("no control “\(arg(2))”") }
    print((attr(control, kAXEnabledAttribute) as Bool?) ?? false)
case "frame":
    let wanted = args.count > 3 ? args[3] : nil
    // Every window, front first: a panel or another document may be in front of the one wanted.
    guard let element = axWindows(application(arg(1))).lazy.compactMap({ window in
        find(window, where: { role($0) == arg(2) && (wanted == nil || label($0).contains(wanted!)) })
    }).first else { fail("no \(arg(2)) \(wanted ?? "")") }
    var origin = CGPoint.zero, size = CGSize.zero
    if let value: AXValue = attr(element, kAXPositionAttribute) { AXValueGetValue(value, .cgPoint, &origin) }
    if let value: AXValue = attr(element, kAXSizeAttribute) { AXValueGetValue(value, .cgSize, &size) }
    print(Int(origin.x), Int(origin.y), Int(size.width), Int(size.height))
case "click":
    requireFront(arg(1))
    guard let x = Double(arg(2)), let y = Double(arg(3)) else { fail("click needs numbers") }
    click(at: CGPoint(x: x, y: y), count: args.count > 4 ? Int(args[4]) ?? 1 : 1)
case "type":
    requireFront(arg(1))
    type(arg(2))
case "keys":
    requireFront(arg(1))
    pressCombo(arg(2))
case "drag":
    requireFront(arg(1))
    let numbers = args.dropFirst(2).compactMap(Double.init)
    guard numbers.count >= 4, numbers.count.isMultiple(of: 2) else { fail("drag needs at least two x y points") }
    drag(through: stride(from: 0, to: numbers.count, by: 2).map { CGPoint(x: numbers[$0], y: numbers[$0 + 1]) })
default:
    fail("usage: drive locked|windows|shot|select|tree|choose|menu|menuextra|row|press|fill|enabled|frame|click|type|keys|drag ...; see the top of drive.swift")
}
