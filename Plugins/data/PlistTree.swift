import Foundation

/// A property list's values read from its XML: a `dict` keeps its keys in file order, each value keyed by the `<key>`
/// before it. Strings keep their whitespace, as `PropertyListSerialization` does.
nonisolated extension XMLReader.Reader {

    /// The value inside `<plist>`, or an empty dictionary when there's none.
    mutating func plist(_ tag: XMLReader.Tag) throws(ParseFailure) -> DataNode {
        var root: DataNode?
        if !tag.selfClosing {
            var run = XMLReader.Run()
            while case .open(let child) = try next(in: tag, run: &run) {
                try noText(in: run, "Expected a value, not text")
                guard root == nil else { throw ParseFailure("A property list holds only one value", child.start) }
                root = try plistValue(child, key: nil, start: child.start, depth: 1)
                run = XMLReader.Run()
            }
            try noText(in: run, "Expected a value, not text")
        }
        return root ?? DataNode(kind: .object, key: nil, value: nil, start: tag.start)
    }

    private mutating func plistValue(_ tag: XMLReader.Tag, key: String?, start: Int, depth: Int) throws(ParseFailure) -> DataNode {
        guard depth < DataNode.maxDepth else { throw ParseFailure("Nested too deeply", tag.start) }
        switch tag.name {
        case "dict":
            var children: [DataNode] = [], pending: (key: String, start: Int)?
            var run = XMLReader.Run()
            while !tag.selfClosing, case .open(let child) = try next(in: tag, run: &run) {
                try noText(in: run, "Expected a <key>, not text")
                if child.name == "key" {
                    if let pending { throw ParseFailure("This key has no value", pending.start) }
                    pending = (string(try textOnly(child), trim: false), child.start)
                } else {
                    guard let key = pending else { throw ParseFailure("This value has no <key> before it", child.start) }
                    children.append(try plistValue(child, key: key.key, start: key.start, depth: depth + 1))
                    pending = nil
                }
                run = XMLReader.Run()
            }
            try noText(in: run, "Expected a <key>, not text")
            if let pending { throw ParseFailure("This key has no value", pending.start) }
            return DataNode(kind: .object, key: key, value: nil, start: start, children: children)
        case "array":
            var children: [DataNode] = []
            var run = XMLReader.Run()
            while !tag.selfClosing, case .open(let child) = try next(in: tag, run: &run) {
                try noText(in: run, "Expected a value, not text")
                children.append(try plistValue(child, key: nil, start: child.start, depth: depth + 1))
                run = XMLReader.Run()
            }
            try noText(in: run, "Expected a value, not text")
            return DataNode(kind: .array, key: key, value: nil, start: start, children: children)
        case "string":
            return DataNode(kind: .string, key: key, value: string(try textOnly(tag), trim: false), start: start)
        case "date":
            return DataNode(kind: .string, key: key, value: string(try textOnly(tag), trim: true), start: start)
        case "data":
            let base64 = string(try textOnly(tag), trim: false).utf8.filter { !XMLReader.isSpace($0) }
            return DataNode(kind: .string, key: key, value: String(decoding: base64, as: UTF8.self), start: start)
        case "integer", "real":
            return DataNode(kind: .number, key: key, value: string(try textOnly(tag), trim: true), start: start)
        case "true", "false":
            try noText(in: try textOnly(tag), "Expected nothing inside <\(tag.name)>")
            return DataNode(kind: .bool, key: key, value: tag.name, start: start)
        case "key":
            throw ParseFailure("A <key> belongs in a <dict>", tag.start)
        default:
            throw ParseFailure("A property list can't hold <\(tag.name)>", tag.start)
        }
    }

    /// The text of an element that may hold only text.
    private mutating func textOnly(_ tag: XMLReader.Tag) throws(ParseFailure) -> XMLReader.Run {
        var run = XMLReader.Run()
        if !tag.selfClosing, case .open(let child) = try next(in: tag, run: &run) {
            throw ParseFailure("Expected text in <\(tag.name)>, not an element", child.start)
        }
        return run
    }

    private func noText(in run: XMLReader.Run, _ message: String) throws(ParseFailure) {
        if let visible = run.visible { throw ParseFailure(message, visible) }
    }
}
