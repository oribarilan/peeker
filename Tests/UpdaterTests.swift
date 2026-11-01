import Foundation
import Testing

/// Released builds are only checked here as far as they don't start Sparkle: a test run must never reach the feed.
@Suite struct UpdaterTests {
    @Test func aDevelopmentBuildNeverStartsOrChecks() {
        let updater = Updater(version: Updater.developmentVersion, build: "0")
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
        config.checkForUpdates = false
        updater.apply(config)
        #expect(!updater.checksAutomatically)
        updater.apply(Config())
        #expect(updater.checksAutomatically)
    }

    @Test func theVersionLineNamesTheBuild() {
        #expect(Updater(version: "0.1.0", build: "100").versionLine == "Version 0.1.0 (100)")
        #expect(Updater(version: Updater.developmentVersion, build: "0").versionLine == "Development build (0.0.0-dev)")
        #expect(Updater(version: "0.1.0", build: "100").updatesThisBuild)
    }

    @Test func theBundleVersionIsReadFromTheInfoDictionary() {
        // The test bundle has no version keys of ours, so it reads as whatever Xcode generated, never crashing.
        let updater = Updater(bundle: Bundle(for: BundleMarker.self))
        #expect(!updater.version.isEmpty && !updater.build.isEmpty)
    }
}

private final class BundleMarker {}
