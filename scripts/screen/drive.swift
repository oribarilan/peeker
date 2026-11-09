// Drives Peeker and Finder for hand-style checks: window lists, screenshots, Finder selection, key presses, and the
// Accessibility tree (menus, toolbar pop-ups). Needs Accessibility and Screen Recording for the terminal running it,
// and an unlocked screen for everything except `locked`.
//
// usage: drive locked                              exit 0 when the screen is locked (prints yes/no)
//        drive windows [owner]                     on-screen windows: id, owner, layer, size, title
//        drive shot <owner> <out.png> [title]      screenshot of the owner's largest window (or the one with that title)
//        drive select <path>                       activate Finder and select <path>
//        drive tree <process> [depth]              print the Accessibility tree of the process's windows
//        drive choose <process> [item] [label]     pick <item> in the front window's toolbar pop-up (Open With), or in
//                                                  the pop-up labeled <label> in any window (a Settings pop-up); without
//                                                  <item>, print the front window's pop-up and its items
//        drive menu <process> <menu> <item>        press a menu item, e.g. Peeker "File" "Close", and wait for the menu to close;
//                                                  <item> may be a path into a submenu, "Highlight Color>Green"
//        drive menuitems <process> [menu]          print the menu bar's menus, or open <menu> and print its items, "✓ "
//                                                  before checked ones, then close it (DRIVE_HOLD=<s> waits first);
//                                                  needs <process> in front
//        drive menuextra <process> [item]          open the process's menu bar icon menu and print it, or press <item>
//        drive menuextraclick <process> <item>     the same with real mouse clicks, which macOS counts as the user's own
//                                                  action (an Accessibility press doesn't let an app make itself active)
//        drive row <process> <title>               select the sidebar row titled <title> in any window
//        drive press <process> <label> [role]      press the control (button, switch) labeled <label> in any window,
//                                                  or only inside the first element with that role, e.g. AXScrollArea,
//                                                  or with that role and label, e.g. "AXRadioGroup=Text appearance"
//        drive marked <process>                    print the text of each selected row in the process's lists and outlines
//        drive fill <process> <label> <text>       focus the field with that placeholder or label and set its text
//        drive enabled <process> <label>           print whether the control labeled <label> is enabled
//        drive placeholders <process>              print the placeholder of each text field in the process's windows
//        drive frame <process> <role> [label]      print the screen frame (x y width height) of the first such element
//                                                  whose label contains <label> or whose value is <label> once leading
//                                                  and trailing spaces are dropped (an outline row's indented title)
//        drive value <process>                     print the text of the process's focused text area, or else the first
//                                                  text area in its key window, then in any window (the Peek panel's)
//        drive textframe <process> <text>          print the screen frame (x y width height, as frame does) of the
//                                                  first <text> in that text area
//        drive selection <process>                 print that text area's selected range and the line it starts on,
//                                                  as "location length line N": UTF-16 offsets and a 0-based line
//                                                  counted as laid out, so a wrapped line counts more than once
//        drive click <process> <x> <y> [count]     click at a screen point, only while <process> is in front
//        drive cmdclick <process> <x> <y>          Cmd-click at a screen point, only while <process> is in front
//        drive move <process> <x> <y>              move the pointer to a screen point without clicking, only while
//                                                  <process> is in front
//        drive scroll <process> <x> <y> <lines> [cmd]
//                                                  scroll the wheel <lines> notches at a screen point (up is positive),
//                                                  holding Command with cmd, only while <process> is in front
//        drive type <process> <text>               type <text>, only while <process> is in front
//        drive drag <process> <x y>...             press at the first point, drag through the rest, release at the last
//        drive keys <process> <combo>              press a combo such as opt+space, ctrl+cmd+h, return or cmd+up, only while <process> is in front
//        drive wait <process> <kind> [label] [--gone] [--timeout s]
//                                                  wait (5 s by default) for a window (title containing label), sheet,
//                                                  menu or control (labeled like press finds it) to appear, or with
//                                                  --gone to go away; exit 1 naming what it waited for on timeout
//        drive loginlaunch <app> [NAME=value]...   launch <app> as macOS does a login item (an open-application event
//                                                  marked as a login launch), with those environment variables
//        drive focus <process>                     print the front app, the process's key window and focused element
//        drive pixel <png> <x> <y>                 print the sRGB color (RRGGBB) at a point of an image given as fractions
//                                                  of its width and height from the top left: 0.5 0.5 is the middle
//        drive closest <png> <x> <y> <w> <h> <RRGGBB>
//                                                  in a full-screen capture, the pixel inside the rectangle (screen points,
//                                                  as textframe prints) nearest the color: "distance RRGGBB", distance
//                                                  being the largest channel difference
//        drive stripes <out.png> <width> <height>  write a gray PNG of one-pixel black and white columns
//        drive contrast <png>                      print how much neighbouring pixels in a row differ on average, 0 to
//                                                  255, in a 200-pixel square from the middle of an image: sharp
//                                                  one-pixel stripes read near 255, enlarged or blurred ones far lower
//        drive diff <a.png> <b.png>                print the largest difference of any color channel between two
//                                                  captures of the same size, 0 to 255 (glass picks up what's behind a
//                                                  window, so captures of the same view rarely match byte for byte)
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
            -- Reuse the front window when it already shows the folder, rather than opening one per file. A window
            -- showing Recents or another search has no folder to compare, so it errors and the file is revealed.
            set reuse to false
            try
                set reuse to ((target of front Finder window) as alias) is ((container of picked) as alias)
            end try
            if reuse then
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

/// The middle of an element on screen, from its Accessibility position and size.
func center(of element: AXUIElement) -> CGPoint {
    var origin = CGPoint.zero, size = CGSize.zero
    if let value: AXValue = attr(element, kAXPositionAttribute) { AXValueGetValue(value, .cgPoint, &origin) }
    if let value: AXValue = attr(element, kAXSizeAttribute) { AXValueGetValue(value, .cgSize, &size) }
    return CGPoint(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
}

func click(at point: CGPoint, count: Int, flags: CGEventFlags = []) {
    let source = CGEventSource(stateID: .hidSystemState)
    for index in 1...count {
        for type in [CGEventType.leftMouseDown, .leftMouseUp] {
            let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left)
            event?.setIntegerValueField(.mouseEventClickState, value: Int64(index))
            event?.flags = flags  // only these modifiers, whatever the system thinks is held
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
    var keys: [String: CGKeyCode] = ["space": 49, "return": 36, "tab": 48, "escape": 53, "delete": 51,
                                     "left": 123, "right": 124, "down": 125, "up": 126, "pageup": 116, "pagedown": 121]
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
        // The key a US keyboard types it with, so the app sees the key code a real press sends; 0 (A) otherwise.
        let key = Unicode.Scalar(character).map { $0 == " " ? 49 : comboKeys[String($0).lowercased()] ?? 0 } ?? 0
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down)
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

/// A menu item's name: its description when it has one (an item whose title starts with a color dot), else its label.
func itemName(_ element: AXUIElement) -> String {
    (attr(element, kAXDescriptionAttribute) as String?).flatMap { $0.isEmpty ? nil : $0 } ?? label(element)
}

/// The menu item at `path` under `menu`: names separated by ">", such as "Highlight Color>Green".
func menuItem(in menu: AXUIElement, path: String) -> AXUIElement? {
    var current = menu
    for name in path.split(separator: ">").map(String.init) {
        guard let item = find(current, where: { role($0) == kAXMenuItemRole && itemName($0) == name }) else { return nil }
        current = item
    }
    return current
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

func parameterized<T>(_ element: AXUIElement, _ name: String, _ parameter: CFTypeRef) -> T? {
    var value: CFTypeRef?
    guard AXUIElementCopyParameterizedAttributeValue(element, name as CFString, parameter, &value) == .success else { return nil }
    return value as? T
}

/// The process's focused text area, or else the first one in its key window, then in any of its windows.
func textArea(_ process: String) -> AXUIElement {
    let app = application(process)
    let isArea = { (element: AXUIElement) in role(element) == kAXTextAreaRole }
    if let focused: AXUIElement = attr(app, kAXFocusedUIElementAttribute), isArea(focused) { return focused }
    let key: AXUIElement? = attr(app, kAXFocusedWindowAttribute)
    guard let area = ([key].compactMap { $0 } + axWindows(app)).lazy.compactMap({ find($0, where: isArea) }).first else {
        fail("no text area in \(process)")
    }
    return area
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
func control(_ process: String, _ title: String, within container: String? = nil) -> AXUIElement? {
    let roles: Set<String> = [kAXButtonRole, kAXCheckBoxRole, "AXSwitch", kAXMenuButtonRole, kAXRadioButtonRole]
    let isControl = { (element: AXUIElement) in roles.contains(role(element)) }
    return axWindows(application(process)).lazy.compactMap { window in
        // "AXRadioGroup=Text appearance" narrows it to the element with that role and label, or labeled by the text
        // just before it, as SwiftUI lays out a picker in a grouped Form.
        guard let root = container.map({ wanted in
            let parts = wanted.split(separator: "=", maxSplits: 1).map(String.init)
            return find(window, where: { role($0) == parts[0] && (parts.count == 1 || label($0) == parts[1] || textBefore($0) == parts[1]) })
        }) ?? window else { return nil }
        return find(root, where: { isControl($0) && label($0) == title }) ?? controlAfterText(title, in: root, isControl: isControl)
    }.first
}

/// The text of the static text just before `element` among its parent's children, or nil.
func textBefore(_ element: AXUIElement) -> String? {
    guard let parent: AXUIElement = attr(element, kAXParentAttribute) else { return nil }
    let siblings = children(parent)
    guard let index = siblings.firstIndex(where: { CFEqual($0, element) }), index > 0, role(siblings[index - 1]) == kAXStaticTextRole else { return nil }
    return attr(siblings[index - 1], kAXValueAttribute)
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
    let isPopUp = { (element: AXUIElement) in role(element) == kAXPopUpButtonRole }
    let appWindows = axWindows(application(arg(1)))
    let popup = args.count > 3
        ? appWindows.lazy.compactMap { find($0, where: { isPopUp($0) && label($0) == arg(3) }) ?? controlAfterText(arg(3), in: $0, isControl: isPopUp) }.first
        : appWindows.first.flatMap { find($0, where: isPopUp) }
    guard let popup else { fail(args.count > 3 ? "no pop-up “\(arg(3))”" : "no pop-up in the front window") }
    pick(in: popup, item: args.count > 2 ? args[2] : nil)
case "menu":
    guard let bar: AXUIElement = attr(application(arg(1)), kAXMenuBarAttribute),
          let menu = children(bar).first(where: { label($0) == arg(2) }),
          let item = menuItem(in: menu, path: arg(3)) else { fail("no menu item \(arg(2)) > \(arg(3))") }
    press(item)
    // The menu can stay drawn for a moment after the press, and a click or key sent meanwhile would land on it.
    // Open menus are windows at the pop-up menu level (101).
    var waits = 0
    while waits < 60, windows(owner: arg(1)).contains(where: { $0.layer == 101 }) {
        usleep(50_000)
        waits += 1
    }
case "menuitems":
    guard let bar: AXUIElement = attr(application(arg(1)), kAXMenuBarAttribute) else { fail("no menu bar") }
    let menus = children(bar).filter { label($0) != "Apple" }
    guard args.count > 2 else {
        menus.map(label).forEach { print($0) }
        break
    }
    guard let menu = menus.first(where: { label($0) == arg(2) }) else { fail("no menu \(arg(2))") }
    requireFront(arg(1))
    // Opening it has the app check its items, which is when their checkmarks are set. A menu tracks modally, so the
    // press reports "cannot complete" though it opened.
    AXUIElementSetMessagingTimeout(menu, 0.5)
    _ = AXUIElementPerformAction(menu, kAXPressAction as CFString)
    usleep(400_000)
    for item in children(menu).flatMap(children) where role(item) == kAXMenuItemRole && !itemName(item).isEmpty {
        let mark: String? = attr(item, kAXMenuItemMarkCharAttribute)
        print((mark?.isEmpty == false ? "✓ " : "") + itemName(item))
    }
    // DRIVE_HOLD=<seconds> keeps the menu open, for a screenshot taken meanwhile.
    usleep(UInt32((Double(ProcessInfo.processInfo.environment["DRIVE_HOLD"] ?? "") ?? 0) * 1_000_000))
    press(comboKeys["escape"]!)
case "menuextra":
    guard let extras: AXUIElement = attr(application(arg(1)), "AXExtrasMenuBar"), let icon = children(extras).first else { fail("no menu bar icon") }
    pick(in: icon, item: args.count > 2 ? args[2] : nil)
case "menuextraclick":
    guard let extras: AXUIElement = attr(application(arg(1)), "AXExtrasMenuBar"), let icon = children(extras).first else { fail("no menu bar icon") }
    click(at: center(of: icon), count: 1)
    usleep(600_000)
    guard let item = find(icon, where: { role($0) == kAXMenuItemRole && label($0) == arg(2) }) else {
        press(comboKeys["escape"]!)
        fail("no item “\(arg(2))”")
    }
    click(at: center(of: item), count: 1)
case "row":
    let isRow = { (element: AXUIElement) in
        role(element) == kAXRowRole && find(element, where: { label($0) == arg(2) || (attr($0, kAXValueAttribute) as String?) == arg(2) }) != nil
    }
    guard let row = axWindows(application(arg(1))).lazy.compactMap({ find($0, where: isRow) }).first else { fail("no sidebar row “\(arg(2))”") }
    let result = AXUIElementSetAttributeValue(row, kAXSelectedAttribute as CFString, kCFBooleanTrue)
    if result != .success { fail("can't select “\(arg(2))”: \(result.rawValue)") }
case "press":
    guard let control = control(arg(1), arg(2), within: args.count > 3 ? args[3] : nil) else { fail("no control “\(arg(2))”") }
    press(control)
case "marked":
    func rows(_ element: AXUIElement, depth: Int = 0) -> [AXUIElement] {
        (role(element) == kAXRowRole && (attr(element, kAXSelectedAttribute) as Bool?) == true ? [element] : [])
            + (depth < 30 ? children(element).flatMap { rows($0, depth: depth + 1) } : [])
    }
    for row in axWindows(application(arg(1))).flatMap({ rows($0) }) {
        let text = find(row, where: { role($0) == kAXStaticTextRole || role($0) == kAXTextFieldRole })
        if let value: String = text.flatMap({ attr($0, kAXValueAttribute) }) { print(value.trimmingCharacters(in: .whitespaces)) }
    }
case "placeholders":
    func fields(_ element: AXUIElement, depth: Int = 0) -> [AXUIElement] {
        (role(element) == kAXTextFieldRole ? [element] : []) + (depth < 30 ? children(element).flatMap { fields($0, depth: depth + 1) } : [])
    }
    for field in axWindows(application(arg(1))).flatMap({ fields($0) }) {
        if let text: String = attr(field, kAXPlaceholderValueAttribute), !text.isEmpty { print(text) }
    }
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
        find(window, where: { element in
            role(element) == arg(2) && (wanted.map { want in
                label(element).contains(want) || (attr(element, kAXValueAttribute) as String?)?.trimmingCharacters(in: .whitespaces) == want
            } ?? true)
        })
    }).first else { fail("no \(arg(2)) \(wanted ?? "")") }
    var origin = CGPoint.zero, size = CGSize.zero
    if let value: AXValue = attr(element, kAXPositionAttribute) { AXValueGetValue(value, .cgPoint, &origin) }
    if let value: AXValue = attr(element, kAXSizeAttribute) { AXValueGetValue(value, .cgSize, &size) }
    print(Int(origin.x), Int(origin.y), Int(size.width), Int(size.height))
case "value":
    guard let text: String = attr(textArea(arg(1)), kAXValueAttribute) else { fail("the text area has no text") }
    print(text)
case "textframe":
    let area = textArea(arg(1))
    let found = (((attr(area, kAXValueAttribute) as String?) ?? "") as NSString).range(of: arg(2))
    guard found.location != NSNotFound else { fail("no “\(arg(2))” in the text area") }
    var range = CFRange(location: found.location, length: found.length)
    guard let bounds: AXValue = parameterized(area, kAXBoundsForRangeParameterizedAttribute, AXValueCreate(.cfRange, &range)!) else {
        fail("no screen frame for “\(arg(2))”")
    }
    var rect = CGRect.zero
    AXValueGetValue(bounds, .cgRect, &rect)
    print(Int(rect.origin.x), Int(rect.origin.y), Int(rect.width), Int(rect.height))
case "selection":
    let area = textArea(arg(1))
    guard let selected: AXValue = attr(area, kAXSelectedTextRangeAttribute) else { fail("the text area has no selection") }
    var range = CFRange()
    AXValueGetValue(selected, .cfRange, &range)
    guard let line: Int = parameterized(area, kAXLineForIndexParameterizedAttribute, NSNumber(value: range.location)) else {
        fail("no line for index \(range.location)")
    }
    print(range.location, range.length, "line", line)
case "click":
    requireFront(arg(1))
    guard let x = Double(arg(2)), let y = Double(arg(3)) else { fail("click needs numbers") }
    click(at: CGPoint(x: x, y: y), count: args.count > 4 ? Int(args[4]) ?? 1 : 1)
case "cmdclick":
    requireFront(arg(1))
    guard let x = Double(arg(2)), let y = Double(arg(3)) else { fail("cmdclick needs numbers") }
    click(at: CGPoint(x: x, y: y), count: 1, flags: .maskCommand)
case "move":
    requireFront(arg(1))
    guard let x = Double(arg(2)), let y = Double(arg(3)) else { fail("move needs numbers") }
    // Two steps, as a real pointer arrives: AppKit sometimes drops a lone jump, and the hover never starts.
    for (dx, pause) in [(-2.0, 50_000 as useconds_t), (0, 0)] {
        CGEvent(mouseEventSource: CGEventSource(stateID: .hidSystemState), mouseType: .mouseMoved, mouseCursorPosition: CGPoint(x: x + dx, y: y),
                mouseButton: .left)?.post(tap: .cghidEventTap)
        usleep(pause)
    }
case "scroll":
    requireFront(arg(1))
    guard let x = Double(arg(2)), let y = Double(arg(3)), let lines = Int32(arg(4)) else { fail("scroll needs numbers") }
    let source = CGEventSource(stateID: .hidSystemState)
    CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: CGPoint(x: x, y: y), mouseButton: .left)?.post(tap: .cghidEventTap)
    usleep(50_000)
    // One notch at a time, as a mouse wheel sends them; up is positive.
    for _ in 0..<abs(lines) {
        let event = CGEvent(scrollWheelEvent2Source: source, units: .line, wheelCount: 1, wheel1: lines > 0 ? 1 : -1, wheel2: 0, wheel3: 0)
        event?.location = CGPoint(x: x, y: y)
        if args.count > 5, arg(5) == "cmd" { event?.flags = .maskCommand }
        event?.post(tap: .cgSessionEventTap)  // a scroll posted at the HID level doesn't reach the window
        usleep(30_000)
    }
    releaseModifiers(source)
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
case "wait":
    var rest = Array(args.dropFirst(3))
    let gone = rest.contains("--gone")
    rest.removeAll { $0 == "--gone" }
    var timeout = 5.0
    if let at = rest.firstIndex(of: "--timeout"), at + 1 < rest.count {
        timeout = Double(rest[at + 1]) ?? timeout
        rest.removeSubrange(at...(at + 1))
    }
    let process = arg(1), kind = arg(2), wanted = rest.first
    // Document windows and panels; not the menu bar icon (layer 25) or open menus (101).
    let present: () -> Bool = switch kind {
    case "window": { windows(owner: process).contains { $0.layer < 25 && (wanted.map($0.title.contains) ?? true) } }
    case "menu": { windows(owner: process).contains { $0.layer == 101 } }
    case "sheet": { axWindows(application(process)).contains { window in find(window, where: { role($0) == "AXSheet" }) != nil } }
    case "control": { control(process, wanted ?? "") != nil }
    default: fail("wait for a window, sheet, menu or control")
    }
    let deadline = Date().addingTimeInterval(timeout)
    while present() == gone {
        guard Date() < deadline else {
            fail("timed out after \(timeout) s waiting for \(kind)\(wanted.map { " “\($0)”" } ?? "")\(gone ? " to go away" : "")")
        }
        usleep(50_000)
    }
case "loginlaunch":
    let event = NSAppleEventDescriptor(eventClass: kCoreEventClass, eventID: kAEOpenApplication, targetDescriptor: nil,
                                       returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
    event.setParam(NSAppleEventDescriptor(enumCode: OSType(keyAELaunchedAsLogInItem)), forKeyword: keyAEPropData)
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.appleEvent = event
    configuration.activates = false
    configuration.environment = Dictionary(uniqueKeysWithValues: args.dropFirst(2).compactMap { pair in
        pair.firstIndex(of: "=").map { (String(pair[..<$0]), String(pair[pair.index(after: $0)...])) }
    })
    var launched: Error?? = nil
    NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: arg(1)), configuration: configuration) { _, error in launched = .some(error) }
    while launched == nil { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
    if case .some(.some(let error)) = launched { fail("can't launch \(arg(1)): \(error.localizedDescription)") }
case "focus":
    let app = application(arg(1))
    let window: AXUIElement? = attr(app, kAXFocusedWindowAttribute)
    let focused: AXUIElement? = attr(app, kAXFocusedUIElementAttribute)
    print("front: \(NSWorkspace.shared.frontmostApplication?.localizedName ?? "nothing")")
    print("key window: \(window.map { (attr($0, kAXTitleAttribute) as String?) ?? "untitled" } ?? "none")")
    print("focused: \(focused.map { "\(role($0)) \(label($0))" } ?? "none")")
case "pixel":
    guard let x = Double(arg(2)), let y = Double(arg(3)), (0...1).contains(x), (0...1).contains(y) else { fail("pixel needs fractions from 0 to 1") }
    // Screenshots are in the display's color space; converting gives the sRGB values the app drew with.
    guard let data = try? Data(contentsOf: URL(filePath: arg(1))),
          let image = NSBitmapImageRep(data: data)?.converting(to: .sRGB, renderingIntent: .default) else { fail("can't read \(arg(1))") }
    let color = image.colorAt(x: min(Int(x * Double(image.pixelsWide)), image.pixelsWide - 1),
                              y: min(Int(y * Double(image.pixelsHigh)), image.pixelsHigh - 1))
    guard let color else { fail("no color there") }
    print([color.redComponent, color.greenComponent, color.blueComponent].map { String(format: "%02X", Int(($0 * 255).rounded())) }.joined())
case "closest":
    // The pixel in a screen capture nearest a color, inside a rectangle given in screen points: antialiased text never
    // draws its exact color, but its darkest or most saturated pixels come close.
    guard let x = Double(arg(2)), let y = Double(arg(3)), let w = Double(arg(4)), let h = Double(arg(5)),
          let wanted = UInt32(arg(6), radix: 16) else { fail("closest needs x y width height in points and RRGGBB") }
    guard let data = try? Data(contentsOf: URL(filePath: arg(1))),
          let image = NSBitmapImageRep(data: data)?.converting(to: .sRGB, renderingIntent: .default),
          let screen = NSScreen.screens.first?.frame else { fail("can't read \(arg(1))") }
    let scale = Double(image.pixelsWide) / screen.width
    let target = [Int(wanted >> 16 & 0xFF), Int(wanted >> 8 & 0xFF), Int(wanted & 0xFF)]
    var best = (distance: 256, hex: "")
    for py in Int(y * scale)..<min(Int((y + h) * scale), image.pixelsHigh) {
        for px in Int(x * scale)..<min(Int((x + w) * scale), image.pixelsWide) {
            guard let color = image.colorAt(x: px, y: py) else { continue }
            let rgb = [color.redComponent, color.greenComponent, color.blueComponent].map { Int(($0 * 255).rounded()) }
            let distance = zip(rgb, target).map { abs($0 - $1) }.max() ?? 256
            if distance < best.distance { best = (distance, rgb.map { String(format: "%02X", $0) }.joined()) }
        }
    }
    print(best.distance, best.hex)
case "stripes":
    guard let width = Int(arg(2)), let height = Int(arg(3)), width > 0, height > 0,
          let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { fail("stripes needs a width and height") }
    context.setFillColor(gray: 1, alpha: 1)
    for x in stride(from: 1, to: width, by: 2) { context.fill(CGRect(x: x, y: 0, width: 1, height: height)) }
    guard let image = context.makeImage(), let destination = CGImageDestinationCreateWithURL(URL(filePath: arg(1)) as CFURL, "public.png" as CFString, 1, nil)
    else { fail("can't write \(arg(1))") }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fail("can't write \(arg(1))") }
case "contrast":
    guard let data = try? Data(contentsOf: URL(filePath: arg(1))),
          let image = NSBitmapImageRep(data: data)?.converting(to: .genericGray, renderingIntent: .default) else { fail("can't read \(arg(1))") }
    let side = min(200, image.pixelsWide - 1, image.pixelsHigh)
    let left = (image.pixelsWide - side) / 2, top = (image.pixelsHigh - side) / 2
    var total = 0.0
    for y in top..<top + side {
        for x in left..<left + side {
            total += abs((image.colorAt(x: x, y: y)?.whiteComponent ?? 0) - (image.colorAt(x: x + 1, y: y)?.whiteComponent ?? 0))
        }
    }
    print(Int((total / Double(side * side) * 255).rounded()))
case "diff":
    guard let first = try? Data(contentsOf: URL(filePath: arg(1))), let second = try? Data(contentsOf: URL(filePath: arg(2))),
          let a = NSBitmapImageRep(data: first), let b = NSBitmapImageRep(data: second) else { fail("can't read \(arg(1)) or \(arg(2))") }
    guard a.pixelsWide == b.pixelsWide, a.pixelsHigh == b.pixelsHigh else { print(255); break }
    var largest = 0.0
    for y in 0..<a.pixelsHigh {
        for x in 0..<a.pixelsWide {
            guard let p = a.colorAt(x: x, y: y), let q = b.colorAt(x: x, y: y) else { continue }
            largest = max(largest, abs(p.redComponent - q.redComponent), abs(p.greenComponent - q.greenComponent), abs(p.blueComponent - q.blueComponent))
        }
    }
    print(Int((largest * 255).rounded()))
default:
    fail("usage: drive locked|windows|shot|select|tree|choose|menu|menuextra|menuextraclick|row|press|fill|enabled|frame|value|textframe|selection|click|move|type|keys|drag|wait|loginlaunch|focus|pixel|closest|stripes|contrast|diff ...; see the top of drive.swift")
}
