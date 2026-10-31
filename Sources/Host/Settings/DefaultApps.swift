import AppKit
import PeekerKit
import UniformTypeIdentifiers

/// The app that opens one extension by default.
struct ExtensionDefault: Equatable {
    let ext: String
    /// Nil when the system has no file type for it (`noExtension`, or a dynamic type such as `conf`), so it can't be set.
    let type: UTType?
    let appName: String?
    let isPeeker: Bool
}

/// Whether Peeker is the default app for a plugin's extensions, counting only the ones that can be set.
enum DefaultAppSummary: Equatable {
    case all, some(Int, of: Int), none, cantSet

    init(of extensions: [ExtensionDefault]) {
        let settable = extensions.filter { $0.type != nil }
        let peeker = settable.count { $0.isPeeker }
        if settable.isEmpty { self = .cantSet }
        else if peeker == settable.count { self = .all }
        else if peeker == 0 { self = .none }
        else { self = .some(peeker, of: settable.count) }
    }
}

/// Reads and changes the default app for extensions, through Launch Services.
enum DefaultApps {
    static func check(_ extensions: [String]) -> [ExtensionDefault] {
        let peeker = Bundle.main.bundleIdentifier
        return extensions.map { ext in
            guard ext != noExtension, let type = UTType(filenameExtension: ext), !type.isDynamic else {
                return ExtensionDefault(ext: ext, type: nil, appName: nil, isPeeker: false)
            }
            let app = NSWorkspace.shared.urlForApplication(toOpen: type)
            // Compared by bundle id, not path, so a build in build/ counts as Peeker too.
            let isPeeker = app.flatMap { Bundle(url: $0)?.bundleIdentifier } == peeker
            let name = app.map { $0.deletingPathExtension().lastPathComponent }
            return ExtensionDefault(ext: ext, type: type, appName: name, isPeeker: isPeeker)
        }
    }

    /// Makes Peeker the default app for each type. Extensions sharing a type (jpg, jpeg) are set once.
    static func makePeekerDefault(for types: [UTType]) async throws {
        var seen: Set<String> = []
        for type in types where seen.insert(type.identifier).inserted {
            try await NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpen: type)
        }
    }
}
