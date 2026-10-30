import Foundation

final class MarkdownPlugin: PluginHandler {
    private var paths: [DocumentID: String] = [:]

    func open(_ doc: DocumentID, path: String, maxPixels: Int) throws(PluginFailure) -> Reply {
        paths[doc] = path
        return try render(path)
    }

    func command(_ doc: DocumentID, id: String, args: [String: Int]) throws(PluginFailure) -> Reply {
        guard let path = paths[doc] else { throw PluginFailure("unknown document") }
        switch id {
        case "toggle-task":
            guard let line = args["line"] else { throw PluginFailure("toggle-task needs a line") }
            try MarkdownTree.toggleTask(atLine: line, inFile: path)
            return try render(path)
        default:
            throw PluginFailure("unknown command \(id)")
        }
    }

    func close(_ doc: DocumentID) {
        paths[doc] = nil
    }

    private func render(_ path: String) throws(PluginFailure) -> Reply {
        let source = try PluginFailure.catching { try String(contentsOfFile: path, encoding: .utf8) }
        let blocks = MarkdownTree.blocks(from: source)
        let tasks = MarkdownTree.taskCounts(in: blocks)
        let words = source.split { $0.isWhitespace }.count
        var info = [InfoRow(label: "Words", value: words.formatted())]
        if tasks.total > 0 { info.append(InfoRow(label: "Tasks", value: "\(tasks.done) of \(tasks.total) done")) }
        return Reply(view: .markdown(blocks), sidebar: [.outline(MarkdownTree.outline(of: blocks)), .info(info)])
    }
}
