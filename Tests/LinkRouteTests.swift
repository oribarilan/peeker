import Foundation
import Testing

@Suite struct LinkRouting {
    /// A folder holding README.md, other.md, notes.txt, report.numbers and a subfolder.
    private let folder: URL
    private var readme: URL { folder.appending(path: "README.md") }

    init() throws {
        folder = try TempFile.make(Data("# Readme\n".utf8), name: "README.md").deletingLastPathComponent()
        for name in ["other.md", "notes.txt", "report.numbers"] { try Data("x".utf8).write(to: folder.appending(path: name)) }
        try FileManager.default.createDirectory(at: folder.appending(path: "sub"), withIntermediateDirectories: true)
    }

    /// Markdown opens .md, Plain Text opens .txt, nothing opens the rest.
    private func route(_ link: String, openElsewhere: Set<String> = []) throws -> LinkRoute {
        let url = try #require(URL(string: link, relativeTo: readme)?.absoluteURL)
        return LinkRoute(
            link: url, from: readme, plugin: "markdown",
            owner: { url in
                switch url.pathExtension {
                case "md": "markdown";
                case "txt": "text";
                default: nil
                }
            }, isOpenElsewhere: { openElsewhere.contains($0.lastPathComponent) })
    }

    @Test func aMissingFileBeeps() throws {
        #expect(try route("gone.md") == .missing)
        #expect(try route("gone.md#setup") == .missing)
    }

    @Test func theSameFileWithANameIsAPlace() throws {
        #expect(try route("#install") == .place("install"))
        #expect(try route("README.md#install") == .place("install"))
    }

    @Test func theSameFileWithoutANameDoesNothing() throws {
        #expect(try route("README.md") == .stay)
        #expect(try route("README.md#") == .stay)
    }

    @Test func aFileOpenInAnotherWindowComesForward() throws {
        #expect(try route("other.md#setup", openElsewhere: ["other.md"]) == .bringForward(folder.appending(path: "other.md")))
    }

    @Test func aFileTheCurrentPluginOpensStaysInTheTab() throws {
        #expect(try route("other.md") == .sameTab(folder.appending(path: "other.md"), place: nil))
        #expect(try route("other.md#setup") == .sameTab(folder.appending(path: "other.md"), place: "setup"))
    }

    @Test func aFileAnotherPluginOpensGetsItsOwnTab() throws {
        #expect(try route("notes.txt") == .ownTab(folder.appending(path: "notes.txt"), place: nil))
    }

    @Test func aFileNoPluginOpensOrAFolderAsksFirst() throws {
        #expect(try route("report.numbers") == .ask(folder.appending(path: "report.numbers")))
        #expect(try route("sub") == .ask(folder.appending(path: "sub")))
    }

    @Test func symlinksAreSeenThrough() throws {
        let link = folder.appending(path: "readme-link.md"), otherLink = folder.appending(path: "other-link.md")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: readme)
        try FileManager.default.createSymbolicLink(at: otherLink, withDestinationURL: folder.appending(path: "other.md"))
        #expect(try route("readme-link.md#install") == .place("install"))
        #expect(try route("other-link.md", openElsewhere: ["other.md"]) == .bringForward(otherLink))
    }
}
