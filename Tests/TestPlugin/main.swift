import Foundation

/// A plugin that misbehaves on request, keyed by the `open` path, for testing how the host copes.
struct TestPlugin: PluginHandler {
    func open(_ doc: DocumentID, path: String, maxPixels: Int) throws(PluginFailure) -> Reply {
        // An editable text document whose save crashes the plugin mid-request.
        if URL(filePath: path).lastPathComponent == "crash-on-save.txt" {
            return Reply(view: .text(SharedText(file: try SharedFile.create(Data("mine\n".utf8)), editable: true, note: nil)))
        }
        switch path {
        case "echo":
            break
        case "crash":
            abort()
        case "hang":
            while true { sleep(.max) }
        case "garbage":
            // A well-formed reply follows; the host must stop at the first bad line instead of accepting it.
            FileHandle.standardOutput.write(Data("not json\n".utf8))
        case "stderr":
            FileHandle.standardError.write(Data("hello from plugin\n".utf8))
        default:
            throw PluginFailure("unknown mode \(path)")
        }
        return Reply(sidebar: [.info([InfoRow(label: "pid", value: "\(getpid())")])])
    }

    func save(_ doc: DocumentID, _ payload: SavePayload) throws(PluginFailure) -> Reply {
        abort()
    }
}

PluginMain.run(TestPlugin())
