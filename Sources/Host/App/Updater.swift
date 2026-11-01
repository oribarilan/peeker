import AppKit
import Sparkle

/// Peeker's updates, through Sparkle: a daily check while the config allows it, and a check whenever the user asks.
/// A development build (version 0.0.0-dev) never starts Sparkle and never contacts the update feed.
final class Updater {
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
    private var controller: SPUStandardUpdaterController?

    init(version: String, build: String) {
        self.version = version
        self.build = build
    }

    convenience init(bundle: Bundle = .main) {
        self.init(version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? Updater.developmentVersion,
                  build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0")
    }

    /// Whether this build updates itself: only released builds do.
    var updatesThisBuild: Bool { version != Self.developmentVersion }
    /// Whether Sparkle is running.
    var isRunning: Bool { controller != nil }
    /// "Version 0.1.0 (100)", for Settings.
    var versionLine: String { updatesThisBuild ? "Version \(version) (\(build))" : "Development build (\(version))" }
    /// False while a check is already running.
    var canCheck: Bool { controller?.updater.canCheckForUpdates ?? true }

    /// Takes the config's choice about automatic checks.
    func apply(_ config: Config) {
        checksAutomatically = config.checkForUpdates
        controller?.updater.automaticallyChecksForUpdates = config.checkForUpdates
    }

    /// Starts Sparkle, which then checks on its daily schedule while automatic checks are on. Not in a development build.
    func start() {
        guard updatesThisBuild, controller == nil else { return }
        let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
        // The config is the only store: whatever Sparkle remembered from before, the config's choice wins.
        controller.updater.automaticallyChecksForUpdates = checksAutomatically
        controller.startUpdater()
        self.controller = controller
    }

    /// Checks right away, whether automatic checks are on or off; Sparkle says what it found.
    func checkNow() {
        guard updatesThisBuild else {
            return tell("Development builds don't update", "Updates come only with released builds of Peeker. This one is \(version).")
        }
        start()
        controller?.checkForUpdates(nil)
    }
}
