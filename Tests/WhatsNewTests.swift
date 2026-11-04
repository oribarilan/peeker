import Foundation
import Testing

private let changelog = """
    # Changelog

    Some words about the file.

    ## [Unreleased]

    - Not out yet.

    ## [0.10.0] - 2027-03-01

    - Ten.

    ## [0.9.0] - 2027-02-01

    - Nine, first line.
    - Nine, second line.

    ## [0.3.0] - 2027-01-01

    - Three.
    """

@Suite struct ChangelogReading {
    @Test func listsTheVersionsAfterTheLastOneRunNewestFirst() {
        let releases = Changelog.releases(in: changelog, after: "0.3.0", upTo: "0.10.0")
        #expect(releases.map(\.version) == ["0.10.0", "0.9.0"])
        #expect(releases.last?.notes == ["Nine, first line.", "Nine, second line."])
    }

    @Test func comparesVersionsAsNumbers() {
        #expect(Changelog.isNewer("0.10.0", than: "0.9.0"))
        #expect(!Changelog.isNewer("0.9.0", than: "0.10.0"))
        #expect(!Changelog.isNewer("0.9.0", than: "0.9.0"))
        #expect(Changelog.isNewer("1.0.0", than: "0.99.9"))
    }

    @Test func stopsAtTheRunningVersion() {
        #expect(Changelog.releases(in: changelog, after: "0.3.0", upTo: "0.9.0").map(\.version) == ["0.9.0"])
    }

    @Test func aVersionMissingFromTheFileIsSkipped() {
        #expect(Changelog.releases(in: changelog, after: "0.1.0", upTo: "0.5.0").map(\.version) == ["0.3.0"])
    }

    @Test func nothingInTheRangeGivesNothing() {
        #expect(Changelog.releases(in: changelog, after: "0.10.0", upTo: "0.11.0").isEmpty)
        #expect(Changelog.releases(in: "", after: "0.1.0", upTo: "0.2.0").isEmpty)
    }
}

@Suite struct WhatsNewTiming {
    private func timing(last: String?, running: String = "0.4.0", enabled: Bool = true, quiet: Bool = false, atLogin: Bool = false) -> WhatsNew.Timing {
        WhatsNew.timing(lastRun: last, running: running, enabled: enabled, installedQuietly: quiet, atLogin: atLogin)
    }

    @Test func aFirstRunShowsNothing() { #expect(timing(last: nil) == .never) }
    @Test func theSameOrAnOlderVersionShowsNothing() {
        #expect(timing(last: "0.4.0") == .never)
        #expect(timing(last: "0.5.0") == .never)
    }
    @Test func aDevelopmentBuildShowsNothing() { #expect(timing(last: "0.3.0", running: "0.4.0-dev") == .never) }
    @Test func turnedOffShowsNothing() { #expect(timing(last: "0.3.0", enabled: false) == .never) }
    @Test func anUpdateInstalledByTheUserOrALaunchByHandShowsAtOnce() { #expect(timing(last: "0.3.0") == .now) }
    @Test func aQuietInstallWaitsForTheFirstWindow() { #expect(timing(last: "0.3.0", quiet: true) == .withFirstWindow) }
    @Test func aLaunchAtLoginWaitsForTheFirstWindow() { #expect(timing(last: "0.3.0", atLogin: true) == .withFirstWindow) }
}

@Suite struct UpdateMarks {
    @Test func marksAreReadOnceThenCleared() throws {
        let defaults = try #require(UserDefaults(suiteName: "UpdateMarks"))
        defaults.removePersistentDomain(forName: "UpdateMarks")
        defaults.set(true, forKey: Updater.quietInstallKey)
        defaults.set(true, forKey: Updater.relaunchKey)
        #expect(WhatsNew.takeMarks(from: defaults) == .init(installedQuietly: true, relaunched: true))
        #expect(WhatsNew.takeMarks(from: defaults) == .init(installedQuietly: false, relaunched: false))
    }

    @Test func aRelaunchForAnUpdateLeavesAMark() throws {
        let defaults = try #require(UserDefaults(suiteName: "UpdateMarks.relaunch"))
        defaults.removePersistentDomain(forName: "UpdateMarks.relaunch")
        Updater(version: "0.1.0", build: "100", defaults: defaults).noteRelaunch()
        #expect(defaults.bool(forKey: Updater.relaunchKey))
    }
}

@Suite @MainActor struct WhatsNewWindow {
    private let releases = [Changelog.Release(version: "0.4.0", notes: ["Four."]), Changelog.Release(version: "0.3.0", notes: ["Three, with `code`."])]

    @Test func isTitledWithTheVersionAndListsTheReleasesInOrder() throws {
        let controller = WhatsNewWindowController(version: "0.4.0", releases: releases)
        defer { controller.close() }
        #expect(controller.window?.title == "Updated to Peeker 0.4.0")
        #expect(controller.releases.map(\.version) == ["0.4.0", "0.3.0"])
    }

    @Test func doneClosesIt() throws {
        let controller = WhatsNewWindowController(version: "0.4.0", releases: releases)
        controller.showWindow(nil)
        #expect(controller.window?.isVisible == true)
        controller.done()
        #expect(controller.window?.isVisible == false)
    }
}
