import Foundation
import Testing

/// Released builds are only checked here as far as they don't start Sparkle: a test run must never reach the feed.
@Suite struct UpdaterTests {
    @Test(arguments: ["0.0.0-dev", "0.1.0-dev"])
    func aDevelopmentBuildNeverStartsOrChecks(version: String) {
        let updater = Updater(version: version, build: "0")
        var told: [String] = []
        updater.tell = { message, _ in told.append(message) }
        updater.start()
        updater.checkNow()
        #expect(!updater.updatesThisBuild)
        #expect(!updater.isRunning)
        #expect(told == ["Development builds don't update"])
    }

    @Test func automaticChecksFollowTheConfig() {
        let updater = Updater(version: "0.1.0", build: "100")
        #expect(updater.checksAutomatically)
        var config = Config()
        config.automaticUpdates = "off"
        updater.apply(config)
        #expect(!updater.checksAutomatically)
        updater.apply(Config())
        #expect(updater.checksAutomatically)
    }

    @Test(arguments: [("off", false, false), ("check", true, false), ("download", true, true)])
    func eachModeSetsChecksAndDownloads(mode: String, checks: Bool, downloads: Bool) {
        let updater = Updater(version: "0.1.0", build: "100")
        var config = Config()
        config.automaticUpdates = mode
        updater.apply(config)
        #expect(updater.checksAutomatically == checks)
        #expect(updater.downloadsAutomatically == downloads)
    }

    @Test func aScheduledUpdateShowsItsWindowOnlyWhilePeekerIsActive() {
        let updater = Updater(version: "0.1.0", build: "100")
        var active = false
        updater.isAppActive = { active }
        #expect(!updater.showsScheduledUpdateWindow)
        active = true
        #expect(updater.showsScheduledUpdateWindow)
    }

    @Test func anUpdateLeftToTheMenuBarIsAnnouncedUntilSeen() {
        let updater = Updater(version: "0.1.0", build: "100")
        var announced: [String?] = []
        updater.onUpdateAvailable = { announced.append($0) }
        updater.updateWillShow("0.3.0", inWindow: true)
        #expect(announced.isEmpty, "Sparkle's window shows it, so nothing waits in the menu bar")
        updater.updateWillShow("0.3.0", inWindow: false)
        updater.updateSeen()
        #expect(announced == ["0.3.0", nil])
    }

    @Test func aDownloadedUpdateInstallsOnlyOnceIdle() throws {
        let defaults = try #require(UserDefaults(suiteName: "UpdaterTests.idle"))
        defaults.removePersistentDomain(forName: "UpdaterTests.idle")
        let updater = Updater(version: "0.1.0", build: "100", defaults: defaults)
        var idle = false, installs = 0
        updater.isIdle = { idle }
        #expect(updater.installWhenIdle { installs += 1 }, "Peeker takes over choosing when to install")
        #expect(installs == 0)
        updater.installIfIdle()
        #expect(installs == 0)
        idle = true
        updater.installIfIdle()
        #expect(installs == 1)
        #expect(defaults.bool(forKey: Updater.quietInstallKey))
    }

    @Test func aDownloadedUpdateInstallsAtOnceWhenAlreadyIdle() throws {
        let defaults = try #require(UserDefaults(suiteName: "UpdaterTests.already"))
        defaults.removePersistentDomain(forName: "UpdaterTests.already")
        let updater = Updater(version: "0.1.0", build: "100", defaults: defaults)
        var installs = 0
        updater.isIdle = { true }
        updater.installIfIdle()
        #expect(installs == 0, "nothing to install yet")
        #expect(!defaults.bool(forKey: Updater.quietInstallKey))
        _ = updater.installWhenIdle { installs += 1 }
        #expect(installs == 1)
    }

    @Test func theVersionLineNamesTheBuild() {
        #expect(Updater(version: "0.1.0", build: "100").versionLine == "Version 0.1.0 (100)")
        #expect(Updater(version: "0.1.0-dev", build: "0").versionLine == "Development build (0.1.0-dev)")
        #expect(Updater(version: "0.1.0", build: "100").updatesThisBuild)
    }

    @Test func theBundleVersionIsReadFromTheInfoDictionary() {
        // The test bundle has no version keys of ours, so it reads as whatever Xcode generated, never crashing.
        let updater = Updater(bundle: Bundle(for: BundleMarker.self))
        #expect(!updater.version.isEmpty && !updater.build.isEmpty)
    }
}

private final class BundleMarker {}
