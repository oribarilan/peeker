import Foundation

/// The formats the Data plugin reads, chosen by extension. Another extension given to the plugin in Settings is chosen
/// by the file's first character: XML for `<`, JSON otherwise.
nonisolated enum DataFormat: Sendable {
    case json, yaml, toml, xml, plist

    init(fileExtension: String, text: String) {
        switch fileExtension.lowercased() {
        case "json", "jsonc": self = .json
        case "yaml", "yml": self = .yaml
        case "toml": self = .toml
        case "plist": self = .plist
        case "xml": self = .xml
        default: self = Self.startsWithTag(text) ? .xml : .json
        }
    }

    /// As the edit tools' reason names it.
    var name: String {
        switch self {
        case .json: "JSON"
        case .yaml: "YAML"
        case .toml: "TOML"
        case .xml: "XML"
        case .plist: "property lists"
        }
    }

    /// A property list is read from its XML, so an `xml` file whose root is `plist` shows as one too.
    func parse(_ text: String) -> Result<DataNode, SyntaxError> {
        switch self {
        case .json: JSONParser.parse(text)
        case .yaml: YAMLParser.parse(text)
        case .toml: TOMLParser.parse(text)
        case .xml, .plist: XMLReader.parse(text)
        }
    }

    static func startsWithTag(_ text: String) -> Bool {
        text.utf8.first { $0 != 0x20 && $0 != 0x09 && $0 != 0x0A && $0 != 0x0D && $0 != 0xEF && $0 != 0xBB && $0 != 0xBF } == 0x3C
    }
}
