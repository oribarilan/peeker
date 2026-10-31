import AppKit
import ApplicationServices
import CoreServices

/// Whether a permission is granted, as the Permissions pane shows it.
enum PermissionState: Equatable {
    case granted, notGranted, notAsked

    /// From `AEDeterminePermissionToAutomateTarget`. Nil when it can't tell, such as when Finder isn't running.
    init?(appleEventStatus status: OSStatus) {
        switch status {
        case noErr: self = .granted
        case OSStatus(errAEEventNotPermitted): self = .notGranted
        case OSStatus(errAEEventWouldRequireUserConsent): self = .notAsked
        default: return nil
        }
    }
}

/// Reads the permissions Space in Finder needs, and opens where they're granted.
enum PermissionChecks {
    static var accessibility: PermissionState { AXIsProcessTrusted() ? .granted : .notGranted }

    /// Whether Peeker may send Finder Apple Events. With `asking`, macOS shows its request when it hasn't asked yet.
    /// Can block, so call it off the main thread.
    nonisolated static func finderStatus(asking: Bool) -> OSStatus {
        var target = AEAddressDesc()
        let bundleID = "com.apple.finder"
        let created = bundleID.withCString { AECreateDesc(typeApplicationBundleID, $0, bundleID.utf8.count, &target) }
        guard created == noErr else { return OSStatus(created) }
        defer { AEDisposeDesc(&target) }
        return AEDeterminePermissionToAutomateTarget(&target, typeWildCard, typeWildCard, asking)
    }

    /// Opens a Privacy & Security page of System Settings, such as `Privacy_Accessibility`.
    static func openPrivacySettings(_ anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else { return }
        NSWorkspace.shared.open(url)
    }
}
