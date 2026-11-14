import AppKit
import Testing

@Suite struct AppChoicesOrder {
    private func app(_ id: String, _ name: String) -> AppChoice {
        AppChoice(bundleID: id, name: name, url: URL(filePath: "/Applications/\(name).app"))
    }

    @Test func theDefaultComesFirstThenAToZWithoutExcludedOrRepeatedApps() {
        let xcode = app("com.apple.dt.Xcode", "Xcode"), edit = app("com.apple.TextEdit", "TextEdit")
        let bb = app("com.barebones.bbedit", "BBEdit"), peeker = app("dev.peeker.Peeker", "Peeker")
        let sorted = AppChoices.sorted([edit, peeker, xcode, bb, edit], systemDefault: xcode.bundleID, excluding: [peeker.bundleID])
        #expect(sorted.map(\.name) == ["Xcode", "BBEdit", "TextEdit"])
    }
}
