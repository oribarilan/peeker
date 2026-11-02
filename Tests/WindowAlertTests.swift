import AppKit
import PeekerImage
import PeekerKit
@testable import PeekerText
import Testing

/// The no-plugin alert's Open Settings shows where the file could be taken in.
@Suite struct UnopenableFileSettings {
    private let entries = [PluginEntry(ImagePlugin.self), PluginEntry(TextPlugin.self)]

    @Test func aTurnedOffPluginThatListsItShowsItsPane() {
        var config = Config()
        config.disabled = ["image"]
        let catalog = PluginCatalog(entries: entries, config: config)
        #expect(AppDelegate.settingsPane(forUnopenable: URL(filePath: "/tmp/photo.png"), in: catalog) == .plugin("image"))
    }

    @Test func otherwisePlainText() {
        let catalog = PluginCatalog(entries: entries, config: Config())
        #expect(AppDelegate.settingsPane(forUnopenable: URL(filePath: "/tmp/movie.mp4"), in: catalog) == .plugin("text"))
    }
}

/// Recovery notices and save failures: a short title naming the file, the reason as the detail.
@Suite(.serialized) struct WindowAlertTexts {
    @Test func aRecoveryNoticeHasAShortTitle() async throws {
        let controller = try await documentWindow(for: TextPlugin.self, name: "notes.txt")
        defer { controller.close() }
        var shown: [(String, String)] = []
        controller.present = { _, title, detail in shown.append((title, detail)) }
        controller.report(.restored(fileChangedSince: true))
        try await waitUntil(seconds: 1) { !shown.isEmpty }
        #expect(shown.first?.0 == "Recovered edits for “notes.txt”")
        #expect(shown.first?.1.contains("changed on disk") == true)
    }

    @Test func aFailedSaveHasAShortTitle() async throws {
        let controller = try await documentWindow(for: TextPlugin.self, name: "notes.txt")
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: controller.url.path)
            controller.close()
        }
        var shown: [(String, String)] = []
        controller.present = { _, title, detail in shown.append((title, detail)) }
        try #require(controller.current).type("mine")
        try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: controller.url.path)
        controller.saveDocument(nil)
        try await waitUntil(seconds: 2) { !shown.isEmpty }
        #expect(shown.first?.0 == "Couldn't save “notes.txt”")
        #expect(shown.first?.1.isEmpty == false)
    }
}
