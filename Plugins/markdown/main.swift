import Foundation

final class MarkdownPlugin: PluginHandler {
    private var paths: [String: String] = [:]

    func open(doc: String, path: String, params: [String: Any]) throws -> [String: Any] {
        paths[doc] = path
        return try render(path)
    }

    func command(doc: String, id: String, args: [String: Any]) throws -> [String: Any] {
        guard let path = paths[doc] else { throw PluginFailure("unknown document") }
        switch id {
        case "toggle-task":
            guard let line = args["line"] as? Int else { throw PluginFailure("toggle-task needs a line") }
            try MarkdownTree.toggleTask(atLine: line, inFile: path)
            return try render(path)
        default:
            throw PluginFailure("unknown command \(id)")
        }
    }

    func close(doc: String) {
        paths[doc] = nil
    }

    private func render(_ path: String) throws -> [String: Any] {
        let source = try String(contentsOfFile: path, encoding: .utf8)
        let blocks = MarkdownTree.blocks(from: source)
        let tasks = MarkdownTree.taskCounts(in: blocks)
        let words = source.split { $0.isWhitespace }.count
        var info = [["Words", words.formatted()]]
        if tasks.total > 0 { info.append(["Tasks", "\(tasks.done) of \(tasks.total) done"]) }
        return [
            "view": ["type": "markdown", "blocks": blocks],
            "sidebar": [
                ["type": "outline", "items": MarkdownTree.outline(of: blocks)],
                ["type": "info", "rows": info],
            ],
        ]
    }
}

PluginMain.run(MarkdownPlugin())
