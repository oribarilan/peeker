import Foundation
import PeekerKit
import Testing

/// The safe-write path every plugin saves through.
@Suite struct FileReplacementTests {
    private let files = FileManager.default

    private func permissions(_ url: URL) throws -> Int {
        try #require(files.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int)
    }

    /// Everything in the file's folder, so a test can tell a temporary file was left behind.
    private func folder(of url: URL) throws -> [String] {
        try files.contentsOfDirectory(atPath: url.deletingLastPathComponent().path).sorted()
    }

    @Test func replacesTheContentsKeepingPermissionsAndLeavesNoTemporaryFile() throws {
        let file = try TempFile.make(Data("old".utf8))
        try files.setAttributes([.posixPermissions: 0o640], ofItemAtPath: file.path)
        try FileReplacement.replaceContents(ofFileAt: file.path, with: Data("new".utf8))
        #expect(try Data(contentsOf: file) == Data("new".utf8))
        #expect(try permissions(file) == 0o640)
        #expect(try folder(of: file) == ["f.txt"])
    }

    @Test func writesThroughASymlinkAndKeepsTheLink() throws {
        let target = try TempFile.make(Data("old".utf8))
        let link = try TempFile.make(Data(), name: "placeholder").deletingLastPathComponent().appending(path: "link.txt")
        try files.createSymbolicLink(at: link, withDestinationURL: target)
        try FileReplacement.replaceContents(ofFileAt: link.path, with: Data("new".utf8))
        #expect(try Data(contentsOf: target) == Data("new".utf8))
        #expect(try files.destinationOfSymbolicLink(atPath: link.path) == target.path)
    }

    @Test func createsAFileDeletedSinceItWasOpened() throws {
        let file = try TempFile.make(Data("old".utf8))
        try files.removeItem(at: file)
        try FileReplacement.replaceContents(ofFileAt: file.path, with: Data("new".utf8))
        #expect(try Data(contentsOf: file) == Data("new".utf8))
        #expect(try folder(of: file) == ["f.txt"])
    }

    @Test func refusesWhenTheFolderIsGone() throws {
        let file = try TempFile.make(Data("old".utf8))
        try files.removeItem(at: file.deletingLastPathComponent())
        #expect(throws: PluginError("“f.txt” can't be saved because its folder no longer exists.")) {
            try FileReplacement.replaceContents(ofFileAt: file.path, with: Data("new".utf8))
        }
    }

    @Test func refusesADanglingLinkAndLeavesIt() throws {
        let target = try TempFile.make(Data("old".utf8))
        let link = target.deletingLastPathComponent().appending(path: "link.txt")
        try files.createSymbolicLink(at: link, withDestinationURL: target.deletingLastPathComponent().appending(path: "gone.txt"))
        #expect(throws: PluginError.self) {
            try FileReplacement.replaceContents(ofFileAt: link.path, with: Data("new".utf8))
        }
        #expect((try? files.destinationOfSymbolicLink(atPath: link.path)) != nil)
        #expect(try folder(of: target) == ["f.txt", "link.txt"])
    }

    @Test func refusesAReadOnlyFileAndLeavesItAsItWas() throws {
        let file = try TempFile.make(Data("old".utf8))
        try files.setAttributes([.posixPermissions: 0o444], ofItemAtPath: file.path)
        #expect(throws: PluginError("You don't have permission to save “f.txt”.", code: .notWritable)) {
            try FileReplacement.replaceContents(ofFileAt: file.path, with: Data("new".utf8))
        }
        #expect(try Data(contentsOf: file) == Data("old".utf8))
    }

    /// The temporary file goes next to the original, so a folder that can't be written to stops the save up front.
    @Test func refusesWhenTheFolderIsReadOnly() throws {
        let file = try TempFile.make(Data("old".utf8))
        let folder = file.deletingLastPathComponent()
        try files.setAttributes([.posixPermissions: 0o555], ofItemAtPath: folder.path)
        defer { try? files.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.path) }
        #expect(throws: PluginError.self) {
            try FileReplacement.replaceContents(ofFileAt: file.path, with: Data("new".utf8))
        }
        #expect(try Data(contentsOf: file) == Data("old".utf8))
        #expect(try self.folder(of: file) == ["f.txt"])
    }
}
