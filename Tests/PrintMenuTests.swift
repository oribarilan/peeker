import AppKit
import PeekerKit
import Testing

/// A plugin whose documents print a fixed view, or don't print when `prints` is false.
private enum PrintingPlugin: Plugin {
    static let id = "printing"
    static let name = "Printing"
    static let defaultExtensions: [String] = []
    static let commands: [CommandSpec] = []
    static var prints = true
    static var openDelay = Duration.zero

    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument {
        try? await Task.sleep(for: openDelay)
        return PrintingDocument(prints: prints)
    }
}

private final class PrintingDocument: PluginDocument {
    let contentView = NSView()
    let prints: Bool
    init(prints: Bool) { self.prints = prints }

    var printJob: ((NSPrintInfo) -> NSPrintOperation?)? {
        prints ? { NSPrintOperation(view: NSView(frame: NSRect(x: 0, y: 0, width: 10, height: 10)), printInfo: $0) } : nil
    }
}

@Suite(.serialized) struct PrintMenu {
    private func menu() -> (NSMenu, AppDelegate) {
        let delegate = AppDelegate()
        return (MainMenu.make(target: delegate), delegate)
    }

    @Test func fileHasPrintAndEditHasFindPrevious() throws {
        let (main, delegate) = menu()
        defer { withExtendedLifetime(delegate) {} }
        let print = try #require(main.item(withTitle: "File")?.submenu?.item(withTitle: "Print…"))
        #expect(print.keyEquivalent == "p" && print.keyEquivalentModifierMask == .command)
        #expect(print.action == #selector(DocumentWindowController.printDocument(_:)))
        let previous = try #require(main.item(withTitle: "Edit")?.submenu?.item(withTitle: "Find Previous"))
        #expect(previous.keyEquivalent == "g" && previous.keyEquivalentModifierMask == [.command, .shift])
        #expect(previous.action == #selector(NSTextView.performFindPanelAction(_:)))
        #expect(previous.tag == Int(NSFindPanelAction.previous.rawValue))
    }

    @Test func settingsRefusesPrintAndFindPreviousForCommands() {
        let (main, delegate) = menu()
        defer { withExtendedLifetime(delegate) {} }
        let shortcuts = menuShortcuts(in: main)
        let entry = PluginEntry(PrintingPlugin.self)
        #expect(shortcutConflict(Shortcut(parsing: "cmd+p")!, command: "x", plugin: entry, config: Config(), menu: shortcuts) == "Print…")
        #expect(shortcutConflict(Shortcut(parsing: "cmd+shift+g")!, command: "x", plugin: entry, config: Config(), menu: shortcuts) == "Find Previous")
    }

    private func window(prints: Bool, wait: Bool = true) async throws -> DocumentWindowController {
        PrintingPlugin.prints = prints
        PrintingPlugin.openDelay = wait ? .zero : .seconds(5)
        return try await documentWindow(for: PrintingPlugin.self, waiting: wait)
    }

    private var printItem: NSMenuItem {
        NSMenuItem(title: "Print…", action: #selector(DocumentWindowController.printDocument(_:)), keyEquivalent: "p")
    }

    @Test func printIsEnabledOnlyForAnOpenedDocumentThatPrints() async throws {
        let printing = try await window(prints: true)
        let silent = try await window(prints: false)
        defer { printing.close(); silent.close() }
        #expect(printing.validateMenuItem(printItem))
        #expect(!silent.validateMenuItem(printItem))
    }

    @Test func printIsDisabledWhileOpening() async throws {
        let opening = try await window(prints: true, wait: false)
        defer { opening.close() }
        #expect(opening.current?.pluginDocument == nil)
        #expect(!opening.validateMenuItem(printItem))
    }
}
