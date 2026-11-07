import AppKit
import PeekerKit
@testable import PeekerData
import Testing

@MainActor private func open(_ data: Data, name: String) async throws -> (DataDocument, URL, NSWindow) {
    let url = try TempFile.make(data, name: name)
    let document = try await openDocument(url, with: DataPlugin.self, as: DataDocument.self)
    let window = offscreenWindow(holding: document.contentView)
    document.contentView.layoutSubtreeIfNeeded()
    return (document, url, window)
}

@MainActor private func open(_ text: String, name: String) async throws -> (DataDocument, URL, NSWindow) {
    try await open(Data(text.utf8), name: name)
}

@Suite struct DataFormatChoice {
    @Test func byExtensionThenByTheFirstCharacter() {
        #expect(DataFormat(fileExtension: "YML", text: "") == .yaml && DataFormat(fileExtension: "toml", text: "") == .toml)
        #expect(DataFormat(fileExtension: "plist", text: "") == .plist && DataFormat(fileExtension: "jsonc", text: "") == .json)
        #expect(DataFormat(fileExtension: "geojson", text: "\n  <a/>") == .xml && DataFormat(fileExtension: "geojson", text: "{}") == .json)
    }
}

@Suite(.serialized) struct DataOtherFormats {
    @Test func yamlOpensAsATreeThatChangesInTheText() async throws {
        let (document, url, window) = try await open("name: app\nports:\n  - 80\n  - 443\n", name: "c.yaml")
        defer { window.close() }
        #expect(document.root?.children.map(\.key) == ["name", "ports"] && !document.tree.isHidden)
        #expect(document.root?.children[1].children.map(\.value) == ["80", "443"])
        #expect(document.unavailableReason(for: "add-item") == "Edit YAML in the text: View > Show Text.")
        #expect(!document.perform("add-item") && !document.perform("delete-item"))
        document.tree.edit(try #require(document.root?.children[0]), key: false)
        #expect(document.tree.editor.superview == nil, "the tree doesn't edit YAML")
        let range = (document.text as NSString).range(of: "app")
        document.textView.insertText("web", replacementRange: range)
        document.reparse()
        #expect(document.root?.children[0].value == "web")
        try await document.save(try #require(document.unsavedEdits()), accepting: nil)
        #expect(try String(contentsOf: url, encoding: .utf8) == "name: web\nports:\n  - 80\n  - 443\n")
    }

    @Test func tomlAndXMLOpenAsTrees() async throws {
        let (toml, _, window) = try await open("[dependencies]\nserde = \"1\"\n", name: "Cargo.toml")
        defer { window.close() }
        #expect(toml.root?.children.first?.key == "dependencies" && toml.root?.children.first?.children.first?.value == "1")
        #expect(DataTreeView.shown(try #require(toml.root?.children.first)) == "1 key")
        let (xml, _, other) = try await open(#"<project><version>1.0</version><build lang="java"><x/></build></project>"#, name: "pom.xml")
        defer { other.close() }
        #expect(xml.root?.children.map(\.key) == ["version", "build"] && xml.root?.children[0].value == "1.0")
        #expect(DataTreeView.shown(try #require(xml.root?.children[1])) == "2 children")
        #expect(xml.unavailableReason(for: "add-item") == "Edit XML in the text: View > Show Text.")
    }

    @Test func anXMLFileHoldingAPropertyListShowsItsKeys() async throws {
        let plist = #"<?xml version="1.0"?><plist version="1.0"><dict><key>CFBundleName</key><string>Peeker</string></dict></plist>"#
        let (document, _, window) = try await open(plist, name: "Info.xml")
        defer { window.close() }
        #expect(document.root?.children.first?.key == "CFBundleName" && document.root?.children.first?.value == "Peeker")
        #expect(document.isEditable, "an XML property list's text edits")
    }

    @Test func aBinaryPropertyListShowsItsXMLReadOnly() async throws {
        let data = try PropertyListSerialization.data(fromPropertyList: ["CFBundleName": "Peeker", "Count": 3], format: .binary, options: 0)
        let (document, url, window) = try await open(data, name: "Info.plist")
        defer { window.close() }
        #expect(document.root?.children.map(\.key) == ["CFBundleName", "Count"])
        #expect(document.text.contains("<key>CFBundleName</key>") && !document.textView.isEditable)
        #expect(document.editability == .readOnly("Binary property lists show as XML, read-only."))
        #expect(document.info.first?.value == "Binary property list")
        let copy = url.deletingLastPathComponent().appending(path: "Copy.plist")
        try await document.saveAs(document.unsavedEdits(), to: copy, accepting: nil)
        #expect(try Data(contentsOf: copy) == data)
    }

    @Test func aBrokenYAMLFileOpensInTheText() async throws {
        let (document, _, window) = try await open("a: \"open\nb: 2\n", name: "c.yaml")
        defer { window.close() }
        #expect(document.root == nil && document.error != nil && document.tree.isHidden)
    }
}

/// Found in review: a property list that grows huge as XML, an empty property list, and a format that changes.
@Suite(.serialized) struct DataFormatsReviewFixes {
    @Test func aPropertyListThatRepeatsOneValueIsRefusedBeforeItsXMLIsWritten() async throws {
        let inner = Array(repeating: String(repeating: "x", count: 1024), count: 1000)
        let data = try PropertyListSerialization.data(fromPropertyList: Array(repeating: inner, count: 1000), format: .binary, options: 0)
        #expect(data.count < 4_000_000, "the binary form stores the string once")
        let url = try TempFile.make(data, name: "bomb.plist")
        let started = Date()
        await #expect(throws: PluginError.self) { _ = try await DataPlugin.load(url) }
        #expect(Date().timeIntervalSince(started) < 1)
    }

    @Test func anEmptyPropertyListShowsItsTextWithTheError() async throws {
        let (document, _, window) = try await open("", name: "empty.plist")
        defer { window.close() }
        #expect(document.root == nil && document.error != nil && document.isEditable)
    }

    @Test func savingUnderAnotherExtensionReadsTheTextAsThatFormat() async throws {
        let (document, url, window) = try await open("a: 1\n", name: "notes.cfg")
        defer { window.close() }
        #expect(document.format == .json && document.root == nil)
        let yaml = url.deletingLastPathComponent().appending(path: "notes.yaml")
        try await document.saveAs(document.unsavedEdits(), to: yaml, accepting: nil)
        #expect(document.format == .yaml && document.root?.children.first?.key == "a")
    }
}
