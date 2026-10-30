import AppKit
@preconcurrency import ApplicationServices
@preconcurrency import CoreGraphics

/// Watches the keyboard system-wide (needs the Accessibility permission) for the quick-look key.
///
/// A bare key (e.g. Space) only fires while Finder is frontmost and no text field has focus, so typing anywhere
/// else is untouched. A key with modifiers fires from any app. While the panel is up, Escape and the same key
/// close it, and arrow keys pass through to Finder and then refresh the panel.
final class HotkeyMonitor {
    /// Marks events this app posts itself, so the tap lets them through.
    nonisolated static let ownEventMarker: Int64 = 0x5050_5050

    struct KeyEvent: Sendable {
        let type: CGEventType
        let keyCode: Int64
        let flags: CGEventFlags
        let isRepeat: Bool
        let isOwn: Bool
    }

    private let shortcut: Shortcut
    private var tap: CFMachPort?
    private var swallowedKeyUp: Int64?

    var onTrigger: (() -> Void)?
    var onDismiss: (() -> Void)?
    var onSelectionMayHaveChanged: (() -> Void)?
    var isPanelVisible: () -> Bool = { false }

    init(shortcut: Shortcut) {
        self.shortcut = shortcut
    }

    static func requestTrust() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    /// Returns false until the user grants Accessibility.
    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
            // The tap's run loop source is on the main run loop. Only plain values cross into the actor.
            let key = KeyEvent(type: type, keyCode: event.getIntegerValueField(.keyboardEventKeycode), flags: event.flags,
                               isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0,
                               isOwn: event.getIntegerValueField(.eventSourceUserData) == HotkeyMonitor.ownEventMarker)
            let swallow = MainActor.assumeIsolated { monitor.shouldSwallow(key) }
            return swallow ? nil : Unmanaged.passUnretained(event)
        }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                          eventsOfInterest: CGEventMask(mask), callback: callback,
                                          userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        self.tap = tap
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    /// Removes the event tap. Safe to call when it isn't running.
    func stop() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        CFMachPortInvalidate(tap)
        self.tap = nil
    }

    /// Hands the key to Finder after all, for files no plugin supports, so Quick Look still works for them.
    func passKeyToFinder() {
        guard let keyCode = shortcut.keyCode else { return }
        let source = CGEventSource(stateID: .hidSystemState)
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: down)
            event?.setIntegerValueField(.eventSourceUserData, value: Self.ownEventMarker)
            event?.post(tap: .cgSessionEventTap)
        }
    }

    private func shouldSwallow(_ key: KeyEvent) -> Bool {
        if key.type == .tapDisabledByTimeout || key.type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        }
        guard !key.isOwn else { return false }

        if key.type == .keyUp {
            guard key.keyCode == swallowedKeyUp else { return false }
            swallowedKeyUp = nil
            return true
        }

        let modifiers = key.flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl])
        let finderIsFrontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder"

        if isPanelVisible(), finderIsFrontmost, modifiers.isEmpty {
            if key.keyCode == 53 {  // Escape
                swallowedKeyUp = key.keyCode
                DispatchQueue.main.async { self.onDismiss?() }
                return true
            }
            if (123...126).contains(key.keyCode) {  // arrows: let Finder move its selection, then follow it
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { self.onSelectionMayHaveChanged?() }
                return false
            }
        }

        guard key.keyCode == shortcut.keyCode, modifiers == Self.cgFlags(shortcut.modifiers) else { return false }
        if key.isRepeat { return isPanelVisible() }
        if shortcut.modifiers.isEmpty {
            guard finderIsFrontmost, !Self.isTextInputFocused() else { return false }
        }
        swallowedKeyUp = key.keyCode
        if isPanelVisible() {
            DispatchQueue.main.async { self.onDismiss?() }
        } else {
            DispatchQueue.main.async { self.onTrigger?() }
        }
        return true
    }

    private static func cgFlags(_ modifiers: NSEvent.ModifierFlags) -> CGEventFlags {
        var flags: CGEventFlags = []
        if modifiers.contains(.command) { flags.insert(.maskCommand) }
        if modifiers.contains(.shift) { flags.insert(.maskShift) }
        if modifiers.contains(.option) { flags.insert(.maskAlternate) }
        if modifiers.contains(.control) { flags.insert(.maskControl) }
        return flags
    }

    /// True while the user is typing in Finder (rename field, search field), where Space must stay a space.
    private static func isTextInputFocused() -> Bool {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.1)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return false }
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(focused as! AXUIElement, kAXRoleAttribute as CFString, &role)
        return ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"].contains(role as? String ?? "")
    }
}
