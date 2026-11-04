import AppKit
import Sparkle

/// Peeker's updates, through Sparkle: a daily check while the config allows it, and a check whenever the user asks.
/// An update a scheduled check finds while Peeker isn't active waits in the menu bar instead of opening a window.
/// A development build (a version ending in -dev, such as 0.1.0-dev) never starts Sparkle and never contacts the
/// update feed.
final class Updater: NSObject, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    static let developmentVersion = "0.0.0-dev"
    /// The version and build number this app reports, such as "0.1.0" and "100".
    let version: String
    let build: String
    /// Says something to the user; an alert unless a test replaces it.
    var tell: (_ message: String, _ detail: String) -> Void = { message, detail in
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = detail
        alert.runModal()
    }
    private(set) var checksAutomatically = true
    private(set) var downloadsAutomatically = false
    /// Whether Peeker is the active app; scheduled updates open their window only then.
    var isAppActive: () -> Bool = { NSApp.isActive }
    /// Called with the version of an update waiting in the menu bar, and with nil once the user has seen it.
    var onUpdateAvailable: (String?) -> Void = { _ in }
    /// Whether nothing is open that a relaunch would close: no window and no Peek panel.
    var isIdle: () -> Bool = { false }
    /// Set when Peeker installs an update quietly, so the next launch knows it wasn't asked for.
    static let quietInstallKey = "updates.installedQuietly"
    /// Set when Sparkle relaunches Peeker to finish an update.
    static let relaunchKey = "updates.relaunched"
    private let defaults: UserDefaults
    private var controller: SPUStandardUpdaterController?
    /// Sparkle's handler that installs a downloaded update and relaunches, kept until Peeker is idle.
    private var pendingInstall: (() -> Void)?

    init(version: String, build: String, defaults: UserDefaults = .standard) {
        self.version = version
        self.build = build
        self.defaults = defaults
    }

    convenience init(bundle: Bundle = .main) {
        self.init(version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? Updater.developmentVersion,
                  build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0")
    }

    /// Whether this build updates itself: only released builds do.
    var updatesThisBuild: Bool { !version.hasSuffix("-dev") }
    /// Whether Sparkle is running.
    var isRunning: Bool { controller != nil }
    /// "Version 0.1.0 (100)", for Settings.
    var versionLine: String { updatesThisBuild ? "Version \(version) (\(build))" : "Development build (\(version))" }
    /// False while a check is already running.
    var canCheck: Bool { controller?.updater.canCheckForUpdates ?? true }

    /// Takes the config's update mode: off, check (and ask) or download (and install).
    func apply(_ config: Config) {
        checksAutomatically = config.automaticUpdates != "off"
        downloadsAutomatically = config.automaticUpdates == "download"
        applySettings()
    }

    /// The config is the only store: whatever Sparkle remembered from before, the config's choice wins.
    private func applySettings() {
        controller?.updater.automaticallyChecksForUpdates = checksAutomatically
        controller?.updater.automaticallyDownloadsUpdates = downloadsAutomatically
    }

    /// Starts Sparkle, which then checks on its daily schedule while automatic checks are on. Not in a development build.
    func start() {
        guard updatesThisBuild, controller == nil else { return }
        let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: self)
        self.controller = controller
        applySettings()
        controller.startUpdater()
    }

    /// Checks right away, whether automatic checks are on or off; Sparkle says what it found.
    func checkNow() {
        guard updatesThisBuild else {
            return tell("Development builds don't update", "Updates come only with released builds of Peeker. This one is \(version).")
        }
        start()
        controller?.checkForUpdates(nil)
    }

    // MARK: Gentle reminders

    /// Whether Sparkle opens its window for an update a scheduled check found.
    var showsScheduledUpdateWindow: Bool { isAppActive() }

    /// An update is about to be offered, in Sparkle's window or, when not, in the menu bar.
    func updateWillShow(_ version: String, inWindow: Bool) {
        if !inWindow { onUpdateAvailable(version) }
    }

    /// The user has seen the update window, or the update session ended.
    func updateSeen() { onUpdateAvailable(nil) }

    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        showsScheduledUpdateWindow
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        updateWillShow(update.displayVersionString, inWindow: handleShowingUpdate)
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) { updateSeen() }

    func standardUserDriverWillFinishUpdateSession() { updateSeen() }

    // MARK: Quiet installs

    /// Keeps `install` until Peeker is idle and runs it then, or now if it already is. Returns true: Peeker, not
    /// Sparkle's schedule, decides when. Quitting installs it anyway.
    func installWhenIdle(_ install: @escaping () -> Void) -> Bool {
        pendingInstall = install
        installIfIdle()
        return true
    }

    /// Installs a downloaded update and relaunches, if one is waiting and nothing is open.
    func installIfIdle() {
        guard let install = pendingInstall, isIdle() else { return }
        defaults.set(true, forKey: Self.quietInstallKey)
        install()
    }

    /// Leaves a mark so the relaunched app doesn't open Settings as a launch with nothing to show would.
    func noteRelaunch() { defaults.set(true, forKey: Self.relaunchKey) }

    func updaterWillRelaunchApplication(_ updater: SPUUpdater) { noteRelaunch() }

    func updater(_ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem, immediateInstallationBlock immediateInstallHandler: @escaping () -> Void) -> Bool {
        installWhenIdle(immediateInstallHandler)
    }
}
