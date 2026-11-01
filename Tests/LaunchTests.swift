import Testing

/// Opening Peeker by hand with nothing to show brings up Settings, so it doesn't look as if it didn't start; a launch
/// at login stays quiet.
@Suite struct LaunchSettings {
    @Test func aHandLaunchWithNothingOpenShowsSettings() {
        #expect(AppDelegate.showsSettingsAtLaunch(openedWindows: 0, atLogin: false))
    }

    @Test func aLaunchThatOpenedSomethingDoesNot() {
        #expect(!AppDelegate.showsSettingsAtLaunch(openedWindows: 1, atLogin: false))
    }

    @Test func aLaunchAtLoginStaysQuiet() {
        #expect(!AppDelegate.showsSettingsAtLaunch(openedWindows: 0, atLogin: true))
    }

    @Test func reopeningWithNoWindowShowsSettings() {
        #expect(AppDelegate.showsSettingsOnReopen(hasVisibleWindows: false))
        #expect(!AppDelegate.showsSettingsOnReopen(hasVisibleWindows: true))
    }
}
