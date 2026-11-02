import AppKit
import SwiftUI

/// What already uses `shortcut`, for a recorder of `command`: a fixed menu item, or another command of
/// the same plugin (with its shortcut as the config has it now), or Edit Mode's Cmd+E. Nil when it's free.
func shortcutConflict(_ shortcut: Shortcut, command: String, plugin: PluginEntry, config: Config, menu: [(title: String, shortcut: Shortcut)]) -> String? {
    if shortcut == .editMode { return "Edit Mode" }
    if let item = menu.first(where: { $0.shortcut == shortcut }) { return item.title }
    return plugin.commands.first { other in
        other.id != command && config.shortcut(for: other, of: plugin.id) == shortcut
    }?.title
}

/// The shortcuts of every item in `menu` and its submenus, except plugin commands, which the document fills in.
func menuShortcuts(in menu: NSMenu) -> [(title: String, shortcut: Shortcut)] {
    menu.items.flatMap { item -> [(title: String, shortcut: Shortcut)] in
        if let submenu = item.submenu { return menuShortcuts(in: submenu) }
        guard item.action != #selector(DocumentWindowController.runCommand(_:)) else { return [] }
        guard let character = item.keyEquivalent.first, item.keyEquivalent.count == 1 else { return [] }
        var modifiers = item.keyEquivalentModifierMask.intersection([.control, .option, .shift, .command])
        if character.isUppercase { modifiers.insert(.shift) }  // AppKit reads an uppercase key equivalent as Shift
        return [(item.title, Shortcut(key: .character(Character(character.lowercased())), modifiers: modifiers))]
    }
}

/// Why the last key was refused, shown under the recorder until the next recording and announced to VoiceOver.
@Observable
final class RefusalNote {
    private(set) var text: String?
    /// Speaks the reason; tests replace it.
    @ObservationIgnored var announce: (String) -> Void = { reason in
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                             userInfo: [.announcement: reason, .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }

    func show(_ reason: String) {
        text = reason
        announce(reason)
    }

    func clear() { text = nil }
}

/// A button showing a shortcut; click it, then press keys to record a new one. Escape cancels. A key the rules or
/// `conflict` refuse is shown as a short message under it, announced, and the shortcut stays.
struct KeyRecorder: View {
    let shortcut: Shortcut?
    let rules: Shortcut.Rules
    var conflict: (Shortcut) -> String? = { _ in nil }
    /// Which recorder is listening, shared by all of them; this one listens while it holds `id`.
    @Binding var listening: String?
    let id: String
    let onRecord: (Shortcut) -> Void

    private var isRecording: Bool { listening == id }
    @State private var monitor: Any?
    @State private var refusal = RefusalNote()

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Button { isRecording ? stop() : start() } label: {
                Text(isRecording ? "Type a shortcut…" : shortcut.map(\.displayText) ?? "None")
                    .frame(minWidth: 120)
            }
            .buttonStyle(.bordered)
            .tint(isRecording ? .accentColor : nil)
            .accessibilityLabel(isRecording ? "Recording a shortcut" : "Shortcut \(shortcut.map(\.displayText) ?? "none"), click to record")
            if let text = refusal.text { Text(text).font(.caption).foregroundStyle(.red).multilineTextAlignment(.trailing) }
        }
        .onChange(of: isRecording) { _, recording in recording ? listen() : unlisten() }
        .onDisappear {
            stop()
            unlisten()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in stop() }
    }

    private func start() {
        refusal.clear()
        listening = id
    }

    private func stop() {
        if isRecording { listening = nil }
    }

    private func listen() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            MainActor.assumeIsolated { handle(event) }
            return nil
        }
    }

    private func unlisten() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func handle(_ event: NSEvent) {
        if event.keyCode == 53, event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty { return stop() }
        guard let recorded = Shortcut(event: event) else { return refuse("Peeker can't use that key. Try a letter, digit, Space, Tab or Return.") }
        if let reason = rules.refusal(for: recorded) { return refuse(reason) }
        if let owner = conflict(recorded) { return refuse("\(recorded.displayText) is used by \(owner).") }
        stop()
        onRecord(recorded)
    }

    private func refuse(_ reason: String) {
        stop()
        refusal.show(reason)
    }
}
