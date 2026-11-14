import AppKit
import PeekerKit
@testable import PeekerTable
import Testing

/// Cmd-C over the Peek panel copies what's selected in it; the host only asks the panel's focused view.
@Suite(.serialized) struct PeekPanelCopy {
    private func panelWithTable() async throws -> (PeekPanel, TableView, NSPasteboard, () -> Void) {
        let (defaults, name) = scratchDefaults()
        let url = try TempFile.make(Data("name,price\nTea,3.50\nCake,4.20\n".utf8), name: "p.csv")
        let document = try await openDocument(url, with: TablePlugin.self, as: TableDocument.self, editing: false)
        let view = try #require(document.contentView as? TableView)
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("peeker-test-\(UUID().uuidString)"))
        view.pasteboard = pasteboard
        let panel = PeekPanel(defaults: defaults)
        panel.contentView = view
        view.layoutSubtreeIfNeeded()
        panel.makeFirstResponder(view.tableView)
        #expect(panel.firstResponder === view.tableView, "a click focuses the table, as GridView's mouseDown asks")
        let done = {
            withExtendedLifetime(document) {}
            panel.close()
            defaults.removePersistentDomain(forName: name)
        }
        return (panel, view, pasteboard, done)
    }

    @Test func aTableCopiesOnlyOnceACellIsClicked() async throws {
        let (panel, view, pasteboard, done) = try await panelWithTable()
        defer { done() }
        #expect(!panel.canCopy, "before a click, Cmd-C stays Finder's")
        #expect(!view.tableView.needsPanelToBecomeKey, "a click leaves the keyboard with Finder, so the arrows keep browsing")
        view.click(CellPosition(row: 1, column: 1), extending: false)
        #expect(panel.canCopy)
        panel.copySelection()
        #expect(pasteboard.string(forType: .string) == "4.20")
    }

    @Test func selectedTextCopiesToo() {
        let (defaults, name) = scratchDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let panel = PeekPanel(defaults: defaults)
        defer { panel.close() }
        let text = NSTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 100))
        text.string = "Release notes"
        text.isEditable = false
        panel.contentView = text
        panel.makeFirstResponder(text)
        #expect(!panel.canCopy, "nothing selected")
        text.setSelectedRange(NSRange(location: 0, length: 7))
        #expect(panel.canCopy)
    }

    @Test func aSheetsEndGivesFinderTheKeyboardBack() async throws {
        let (defaults, name) = scratchDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let panel = PeekPanel(defaults: defaults)
        defer { panel.close() }
        var finder = 0
        var showing = true
        panel.activateFinder = { finder += 1 }
        panel.isShowing = { _ in showing }
        let sheet = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100), styleMask: [.titled], backing: .buffered, defer: false)
        panel.beginSheet(sheet, completionHandler: nil)
        #expect(panel.tookKeyboardForSheet)
        panel.endSheet(sheet)
        try await waitUntil(seconds: 1) { finder == 1 }
        panel.beginSheet(sheet, completionHandler: nil)
        panel.endSheet(sheet)
        showing = false  // as Other…'s completion closes the panel right after its sheet ends
        try await Task.sleep(for: .milliseconds(100))
        #expect(finder == 1, "a panel that's gone leaves the focus where the sheet put it")
    }
}
