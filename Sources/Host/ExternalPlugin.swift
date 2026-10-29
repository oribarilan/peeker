import AppKit
import PreviewPPKit
import UniformTypeIdentifiers

/// `manifest.json` shared by web (`.pppweb`) and process (`.pppproc`) plugins.
struct ExternalManifest: Decodable {
    struct CommandSpec: Decodable {
        let id: String
        let title: String
        let symbol: String?
        let shortcut: String?
    }

    let id: String
    let name: String
    /// UTType identifiers, e.g. "public.comma-separated-values-text".
    let types: [String]
    let commands: [CommandSpec]?
    /// Web plugins: HTML page inside the folder. Process plugins: executable inside the folder.
    let entry: String

    static func load(from folder: URL) throws -> ExternalManifest {
        try JSONDecoder().decode(ExternalManifest.self, from: Data(contentsOf: folder.appending(path: "manifest.json")))
    }

    var pluginManifest: PluginManifest {
        PluginManifest(id: id, name: name, fileTypes: types.map { UTType($0) ?? UTType(importedAs: $0) })
    }

    func commands(run: @escaping (String) -> Void) -> [Command] {
        (commands ?? []).map { spec in
            Command(id: spec.id, title: spec.title, symbolName: spec.symbol, shortcut: spec.shortcut.flatMap(Shortcut.init(parsing:))) {
                run(spec.id)
            }
        }
    }

    /// Resolves `entry` and refuses paths that escape the plugin folder.
    func entryURL(in folder: URL) throws -> URL {
        let url = folder.appending(path: entry).standardizedFileURL.resolvingSymlinksInPath()
        guard url.path.hasPrefix(folder.standardizedFileURL.resolvingSymlinksInPath().path + "/") else {
            throw CocoaError(.fileReadNoPermission, userInfo: [NSLocalizedDescriptionKey: "entry '\(entry)' is outside the plugin folder"])
        }
        return url
    }
}

protocol ExternalPlugin {
    var runtime: Runtime { get }
    func open(_ url: URL, host: any PluginHost) throws -> Viewer
}

/// Shown in place of content when a plugin fails to open or dies.
final class MessageViewController: NSViewController {
    private let message: String

    init(_ message: String) {
        self.message = message
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func loadView() {
        let label = NSTextField(wrappingLabelWithString: message)
        label.alignment = .center
        label.textColor = .secondaryLabelColor
        let container = NSView()
        container.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.widthAnchor.constraint(lessThanOrEqualTo: container.widthAnchor, constant: -40),
        ])
        view = container
    }
}
