import AppKit
import SwiftUI

/// What already uses `shortcut`, for a recorder of `command`: a menu item outside Commands, or another command of
/// the same plugin (with its shortcut as the config has it now), or Edit Mode's Cmd+E. Nil when it's free.
func shortcutConflict(_ shortcut: Shortcut, command: String, plugin: PluginEntry, config: Config, menu: [(title: String, shortcut: Shortcut)]) -> String? {
    if shortcut == Shortcut(key: .character("e"), modifiers: .command) { return "Edit Mode" }
    if let item = menu.first(where: { $0.shortcut == shortcut }) { return item.title }
    return plugin.commands.first { other in
        other.id != command && (config.keys["\(plugin.id).\(other.id)"] ?? other.shortcut.flatMap(Shortcut.init(parsing:))) == shortcut
    }?.title
}

/// The shortcuts of every item in `menu` and its submenus, except the Commands menu, which plugins fill.
func menuShortcuts(in menu: NSMenu) -> [(title: String, shortcut: Shortcut)] {
    menu.items.flatMap { item -> [(title: String, shortcut: Shortcut)] in
        if let submenu = item.submenu { return submenu.title == "Commands" ? [] : menuShortcuts(in: submenu) }
        guard let character = item.keyEquivalent.first, item.keyEquivalent.count == 1 else { return [] }
        var modifiers = item.keyEquivalentModifierMask.intersection([.control, .option, .shift, .command])
        if character.isUppercase { modifiers.insert(.shift) }  // AppKit reads an uppercase key equivalent as Shift
        return [(item.title, Shortcut(key: .character(Character(character.lowercased())), modifiers: modifiers))]
    }
}

/// A button showing a shortcut; click it, then press keys to record a new one. Escape cancels. A key the rules or
/// `conflict` refuse is shown as a short message under it and the shortcut stays.
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
    @State private var refusal: String?

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Button { isRecording ? stop() : start() } label: {
                Text(isRecording ? "Type a shortcut…" : shortcut.map(\.displayText) ?? "None")
                    .frame(minWidth: 120)
            }
            .buttonStyle(.bordered)
            .tint(isRecording ? .accentColor : nil)
            .accessibilityLabel(isRecording ? "Recording a shortcut" : "Shortcut \(shortcut.map(\.displayText) ?? "none"), click to record")
            if let refusal { Text(refusal).font(.caption).foregroundStyle(.red).multilineTextAlignment(.trailing) }
        }
        .onChange(of: isRecording) { _, recording in recording ? listen() : unlisten() }
        .onDisappear {
            stop()
            unlisten()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in stop() }
    }

    private func start() {
        refusal = nil
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
        refusal = reason
        Task {
            try? await Task.sleep(for: .seconds(3))
            if refusal == reason { refusal = nil }
        }
    }
}
