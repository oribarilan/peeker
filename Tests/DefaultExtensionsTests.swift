import Foundation
import PeekerKit
import Testing
import UniformTypeIdentifiers

/// The built-in plugins' default extension lists, which decide what opens where when the config changes nothing.
@Suite struct DefaultExtensions {
    private let plugins = PluginCatalog.builtIn.map { PluginEntry($0) }

    @Test func entriesAreLowercaseExtensionsWithoutDots() {
        for plugin in plugins {
            for entry in plugin.defaultExtensions where entry != noExtension {
                let bare = !entry.isEmpty && !entry.contains { $0 == "." || $0 == "/" || $0.isWhitespace }
                #expect(bare && entry == entry.lowercased(), "\(plugin.id) lists “\(entry)”")
            }
        }
    }

    @Test func noTwoPluginsShareAnEntry() {
        var owners: [String: String] = [:]
        for plugin in plugins {
            for entry in plugin.defaultExtensions {
                #expect(owners[entry] == nil, "“\(entry)” is on both \(owners[entry] ?? "") and \(plugin.id)")
                owners[entry] = plugin.id
            }
        }
    }

    @Test func plainTextOwnsFilesWithNoExtension() {
        #expect(plugins.filter { $0.defaultExtensions.contains(noExtension) }.map(\.id) == ["text"])
    }

    /// Finder offers Peeker under Open With only for the types the app declares. macOS has no type for some
    /// extensions (such as conf), and those can't be declared without exporting new types, so they're skipped.
    @Test func theAppDeclaresTheTypeOfEveryDefaultExtension() throws {
        let plist = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appending(path: "build/Info-Peeker.plist")
        let info = try #require(try PropertyListSerialization.propertyList(from: Data(contentsOf: plist), format: nil) as? [String: Any])
        let documentTypes = try #require(info["CFBundleDocumentTypes"] as? [[String: Any]])
        let declared = documentTypes.flatMap { $0["LSItemContentTypes"] as? [String] ?? [] }.compactMap { UTType($0) }
        // macOS calls .ts an MPEG-2 video. Plain Text opens TypeScript, but Peeker shouldn't offer itself for videos.
        let undeclared: Set = ["ts"]
        for plugin in plugins {
            for entry in plugin.defaultExtensions where !undeclared.contains(entry) {
                guard let type = UTType(filenameExtension: entry), !type.isDynamic else { continue }
                #expect(declared.contains { type.conforms(to: $0) }, "\(plugin.id): .\(entry) is \(type.identifier), which the app doesn't declare")
            }
        }
    }
}
