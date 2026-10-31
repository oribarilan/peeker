import ApplicationServices
import Foundation
import Observation

/// Whether Peeker has Accessibility, which the quick-look key needs. While the key is on it's re-checked every
/// 2 seconds, so a grant (or a revoke) shows within moments: the red dots, and the key starting to work.
@Observable
final class AccessibilityStatus {
    private(set) var isTrusted = AXIsProcessTrusted()
    /// True while the quick-look key is on, the only time Peeker needs the permission.
    private(set) var isNeeded = false
    /// Called when `isTrusted` changes.
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private var timer: Timer?

    var isMissing: Bool { isNeeded && !isTrusted }

    func watch(_ needed: Bool) {
        isNeeded = needed
        timer?.invalidate()
        timer = nil
        refresh()
        guard needed else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func refresh() {
        let trusted = AXIsProcessTrusted()
        guard trusted != isTrusted else { return }
        isTrusted = trusted
        onChange?()
    }
}
