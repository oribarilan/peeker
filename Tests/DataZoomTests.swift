import AppKit
import PeekerKit
@testable import PeekerData
import Testing

@MainActor private func open(_ text: String = #"{"name": "app", "deps": {"a": 1}}"#, preferences: PluginPreferences? = nil) async throws -> (DataDocument, NSWindow) {
    let url = try TempFile.make(Data(text.utf8), name: "z.json")
    let document = try await openDocument(url, with: DataPlugin.self, as: DataDocument.self, preferences: preferences)
    let window = offscreenWindow(holding: document.contentView)
    document.contentView.layoutSubtreeIfNeeded()
    return (document, window)
}

/// The size the first row's key draws at in the tree.
@MainActor private func treeSize(_ document: DataDocument) throws -> CGFloat {
    try #require(document.tree.outlineView.view(atColumn: 0, row: 0, makeIfNecessary: true) as? TreeCell).font.pointSize
}

@MainActor private func textSize(_ document: DataDocument) throws -> CGFloat { try #require(document.textView.font).pointSize }

@Suite(.serialized) struct DataZoomTests {
    /// Today's sizes: the tree in the system font, the text a point smaller in the monospaced one.
    private let tree = NSFont.systemFontSize, text: CGFloat = 12

    @Test func zoomToolsAreMenuOnlyWithTheirShortcuts() {
        let zoom = DataPlugin.tools.filter { $0.id.hasPrefix("zoom-") }
        #expect(zoom.map(\.id) == ["zoom-in", "zoom-out", "zoom-actual"])
        #expect(zoom.map(\.title) == ["Zoom In", "Zoom Out", "Actual Size"])
        #expect(zoom.map(\.shortcut) == ["cmd+=", "cmd+-", "cmd+0"])
        #expect(zoom.allSatisfy { !$0.showsInToolbar && !$0.isEditTool })
    }

    @Test func zoomInGrowsTheTreeAndTheTextTogether() async throws {
        let scratch = ScratchDefaults()
        defer { scratch.close() }
        let (document, window) = try await open(preferences: scratch.preferences("data"))
        defer { window.close() }
        let outline = document.tree.outlineView
        let row = outline.rowHeight, header = try #require(outline.headerView).frame.height
        #expect(try treeSize(document) == tree && textSize(document) == text)
        #expect(document.perform("zoom-in"))
        let font = try #require(outline.view(atColumn: 0, row: 0, makeIfNecessary: true) as? TreeCell).font
        #expect(font.pointSize > tree && outline.rowHeight > row)
        #expect(outline.rowHeight >= ceil(font.ascender - font.descender + font.leading), "no clipped text")
        #expect(try #require(outline.headerView).frame.height > header)
        #expect(outline.numberOfRows == 3, "the open items stay open")
        #expect(document.perform("show-text"))
        #expect(try textSize(document) == text + 1)
        #expect(document.perform("zoom-actual"))
        #expect(try textSize(document) == text)
        #expect(document.perform("show-text"))
        #expect(try treeSize(document) == tree && outline.rowHeight == row)
    }

    @Test func syntaxColorsStayAtTheNewSize() async throws {
        let (document, window) = try await open()
        defer { window.close() }
        let color = { document.textView.layoutManager?.temporaryAttribute(.foregroundColor, atCharacterIndex: 2, effectiveRange: nil) as? NSColor }
        let before = try #require(color())
        #expect(document.perform("show-text") && document.perform("zoom-in"))
        #expect(color() == before)
    }

    @Test func editingAValueWorksAtALargerSize() async throws {
        let (document, window) = try await open()
        defer { window.close() }
        document.setZoom(200, around: nil)
        let node = try #require(document.root?.children.first)
        document.tree.edit(node, key: false)
        let field = document.tree.editor
        #expect(field.superview != nil && field.font?.pointSize == tree * 2)
        field.stringValue = "web"
        document.tree.controlTextDidEndEditing(Notification(name: NSControl.textDidEndEditingNotification, object: field))
        #expect(document.text.contains(#""name": "web""#))
    }

    @Test func theSizeIsRememberedForTheNextFileOnly() async throws {
        let scratch = ScratchDefaults()
        defer { scratch.close() }
        let (first, window) = try await open(preferences: scratch.preferences("data"))
        defer { window.close() }
        let (already, other) = try await open(preferences: scratch.preferences("data"))
        defer { other.close() }
        #expect(first.perform("zoom-in") && first.perform("zoom-in"))
        #expect(scratch.preferences("data").double("fontSize") == Double(text + 2))
        #expect(try treeSize(already) == tree && textSize(already) == text && already.zoomPercent == 100, "a file already open keeps its size")
        let (next, third) = try await open(preferences: scratch.preferences("data"))
        defer { third.close() }
        #expect(try textSize(next) == text + 2 && treeSize(next) > tree)
    }

    @Test func zoomingReportsAndSetsAPercentage() async throws {
        let scratch = ScratchDefaults()
        defer { scratch.close() }
        let (document, window) = try await open(preferences: scratch.preferences("data"))
        defer { window.close() }
        var changes = 0
        document.onZoomChange = { changes += 1 }
        #expect(document.zoomPercent == 100 && !document.pinchesNatively)
        #expect(document.zoomRange == 50...600)
        document.setZoom(125, around: nil)
        #expect(document.zoomPercent == 125 && changes == 1)
        #expect(try textSize(document) == 15 && treeSize(document) == tree * 1.25)
        #expect(scratch.preferences("data").double("fontSize") == 15)
        document.setZoom(125, around: nil)
        #expect(changes == 1, "no change, no call")
        document.setZoom(1, around: nil)
        #expect(try textSize(document) == 6 && changes == 2)
        #expect(document.perform("zoom-out") && changes == 2, "at the limit nothing changes")
        #expect(document.perform("zoom-in") && changes == 3)
        #expect(document.perform("zoom-actual") && document.zoomPercent == 100 && changes == 4)
    }
}
