import AppKit
import os
import ServiceManagement

/// Launches the app at login, so Space in Finder keeps working. Backed by `SMAppService.mainApp`.
enum LoginItem {
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "dev.peeker", category: "login")

    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }
    /// Registered, but the user still has to allow it in System Settings.
    static var needsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    /// Opens System Settings' Login Items when approval is pending; otherwise registers or unregisters.
    static func toggle() throws {
        switch SMAppService.mainApp.status {
        case .requiresApproval: SMAppService.openSystemSettingsLoginItems()
        case .enabled: try SMAppService.mainApp.unregister()
        default: try SMAppService.mainApp.register()
        }
    }

    /// `toggle()`, with a failure shown in an alert.
    static func toggleReportingErrors() {
        do { try toggle() } catch {
            log.error("can't change Open at Login: \(error.localizedDescription, privacy: .public)")
            let alert = NSAlert()
            alert.messageText = "Couldn't change Open at Login"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    static func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}
