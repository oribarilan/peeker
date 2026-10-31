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

    /// What to do with a key.
    enum Decision: Equatable {
        /// Let it through.
        case pass
        /// Let it through to Finder, then refresh the panel for the selection it moves to.
        case followSelection
        /// Swallow the key-up of a key swallowed on the way down.
        case swallowKeyUp
        /// Swallow a held key, so it doesn't type or reopen the panel.
        case swallowRepeat
        case trigger
        case dismiss
    }

    /// The decision for `key`, given what's on screen. `typing` is asked only when a bare key could open the panel,
    /// since it costs an Accessibility call.
    static func decide(_ key: KeyEvent, shortcut: Shortcut, panelVisible: Bool, finderInFront: Bool, typing: () -> Bool,
                       swallowedKeyUp: Int64?) -> Decision {
        guard !key.isOwn else { return .pass }
        if key.type == .keyUp { return key.keyCode == swallowedKeyUp ? .swallowKeyUp : .pass }
        let modifiers = key.flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl])
        if panelVisible, finderInFront, modifiers.isEmpty {
            if key.keyCode == 53 { return .dismiss }  // Escape
            if (123...126).contains(key.keyCode) { return .followSelection }  // arrows
        }
        guard key.keyCode == shortcut.keyCode, modifiers == cgFlags(shortcut.modifiers) else { return .pass }
        if key.isRepeat { return panelVisible ? .swallowRepeat : .pass }
        if shortcut.modifiers.isEmpty, !finderInFront || typing() { return .pass }
        return panelVisible ? .dismiss : .trigger
    }

    private func shouldSwallow(_ key: KeyEvent) -> Bool {
        if key.type == .tapDisabledByTimeout || key.type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        }
        let decision = Self.decide(key, shortcut: shortcut, panelVisible: isPanelVisible(),
                                   finderInFront: NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder",
                                   typing: Self.isTextInputFocused, swallowedKeyUp: swallowedKeyUp)
        switch decision {
        case .pass:
            return false
        case .followSelection:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { self.onSelectionMayHaveChanged?() }
            return false
        case .swallowKeyUp:
            swallowedKeyUp = nil
            return true
        case .swallowRepeat:
            return true
        case .trigger, .dismiss:
            swallowedKeyUp = key.keyCode
            let action = decision == .trigger ? onTrigger : onDismiss
            DispatchQueue.main.async { action?() }
            return true
        }
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
