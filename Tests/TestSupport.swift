import AppKit
import CoreText
import PDFKit
import PeekerKit
@testable import PeekerText
import Testing

enum TempFile {
    /// Writes `bytes` to `name` in a fresh temporary directory.
    static func make(_ bytes: Data, name: String = "f.txt") throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "PeekerTests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: name)
        try bytes.write(to: url)
        return url
    }

    /// A US Letter PDF whose pages say "Page 1", "Page 2" and so on.
    static func makePDF(pages: Int) throws -> URL {
        try makePDF(texts: (1...pages).map { "Page \($0)" })
    }

    /// A US Letter PDF with one page per string, each drawn as a line of text; an empty string makes a page with no text.
    static func makePDF(texts: [String]) throws -> URL {
        let url = try make(Data(), name: "f.pdf")
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { throw CocoaError(.fileWriteUnknown) }
        let font = CTFontCreateWithName("Helvetica" as CFString, 24, nil)
        for text in texts {
            context.beginPDFPage(nil)
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: font]))
            context.textPosition = CGPoint(x: 72, y: 700)
            CTLineDraw(line, context)
            context.endPDFPage()
        }
        context.closePDF()
        return url
    }
}

// MARK: Setup

/// What `plugin` opens for `url`, as `type`. `editing` is false for the Peek panel's view-only documents.
func openDocument<Document>(_ url: URL, with plugin: any Plugin.Type, as type: Document.Type, editing: Bool = true,
                            maxPixels: Int = 0) async throws -> Document {
    try #require(try await plugin.open(url, context: OpenContext(maxPixels: maxPixels, allowsEditing: editing)) as? Document)
}

/// An off-screen window with `view` filling its content area.
func offscreenWindow(holding view: NSView, width: CGFloat = 700, height: CGFloat = 900) -> NSWindow {
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height), styleMask: [.titled], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    view.frame = window.contentView!.bounds
    window.contentView!.addSubview(view)
    return window
}

/// An off-screen window shaped like an Editor window: content runs under a unified toolbar, whose strip
/// `contentLayoutRect` leaves out.
func toolbarWindow(holding view: NSView, width: CGFloat = 700, height: CGFloat = 900) -> NSWindow {
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height), styleMask: [.titled, .fullSizeContentView],
                          backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.toolbar = NSToolbar(identifier: "test-\(UUID().uuidString)")
    window.toolbarStyle = .unified
    view.frame = window.contentView!.bounds
    view.autoresizingMask = [.width, .height]
    window.contentView!.addSubview(view)
    window.contentView!.layoutSubtreeIfNeeded()
    return window
}

/// A document view controller on `url`, opened through `plugin`, with its content (or the failure view) showing.
func loadedDocument(_ url: URL, with plugin: any Plugin.Type, allowsEditing: Bool = true, recovery: RecoveryStore? = nil,
                    recoveryID: String = UUID().uuidString, journalDelay: TimeInterval = 2) async -> DocumentViewController {
    let document = DocumentViewController(url: url, entry: PluginEntry(plugin), config: Config(), allowsEditing: allowsEditing,
                                          recovery: recovery, recoveryID: recoveryID, journalDelay: journalDelay)
    document.loadViewIfNeeded()
    await document.load()
    return document
}

/// An Editor window on a new file named `name`, shown with `plugin`. Waits for the document to open unless `waiting`
/// is false. `others` join its catalog, so Open With has plugins to switch to.
/// The window's sidebar choice is remembered only in `sidebar`, never in the test run's preferences.
func documentWindow(for plugin: any Plugin.Type, name: String = "f.bin", file: URL? = nil, others: [any Plugin.Type] = [], config: Config = Config(), tips: TipStore = TipStore(defaults: nil),
                    waiting: Bool = true, sidebar: SidebarMemory = SidebarMemory(defaults: nil)) async throws -> DocumentWindowController {
    let url = try file ?? TempFile.make(Data("x".utf8), name: name)
    let entry = PluginEntry(plugin)
    let catalog = PluginCatalog(entries: [entry] + others.map { PluginEntry($0) }, config: config)
    let controller = DocumentWindowController(url: url, catalog: catalog, config: config, recovery: nil,
                                              recoveryClipboard: nil, sidebarMemory: sidebar, tips: tips)
    controller.show(with: entry)
    // Until the content has shown, the toolbar has no tool buttons yet.
    if waiting { try await waitUntil(seconds: 2) { controller.current?.hasShownContent == true } }
    return controller
}

struct TimedOut: Error {}

/// Polls `condition` every 20 ms. If it isn't true within `seconds`, records the failure at the caller's line and
/// throws `TimedOut`.
/// A key press in `window`, as the window's key monitor sees it.
func key(_ character: String, code: UInt16, in window: NSWindow, modifiers: NSEvent.ModifierFlags = []) -> NSEvent {
    NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0, windowNumber: window.windowNumber,
                     context: nil, characters: character, charactersIgnoringModifiers: character, isARepeat: false, keyCode: code)!
}

func waitUntil(seconds: Double, sourceLocation: SourceLocation = #_sourceLocation, _ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now + .seconds(seconds)
    while !condition() {
        guard ContinuousClock.now < deadline else {
            Issue.record("Still waiting after \(seconds) s", sourceLocation: sourceLocation)
            throw TimedOut()
        }
        try await Task.sleep(for: .milliseconds(20))
    }
}

/// Recovery records holding the text plugin's edits.
extension RecoveryRecord {
    init(id: String, url: URL, pluginID: String, fileModified: Date?, text: String) {
        // Text always encodes, so a failure here is a broken test.
        try! self.init(id: id, url: url, pluginID: pluginID, fileModified: fileModified, edits: JSONEncoder().encode(TextEdits(text: text)))
    }

    var text: String? { TextPlugin.recoveryText(from: editsData) }
}

/// Runs `job` without a panel, saving to a PDF file, and returns what it printed.
@MainActor func printed(_ job: (NSPrintInfo) -> NSPrintOperation?, title: String = "f.txt") throws -> PDFDocument {
    let url = try TempFile.make(Data(), name: "printed.pdf")
    let info = NSPrintInfo.shared.copy() as! NSPrintInfo
    info.paperSize = NSSize(width: 612, height: 792)
    info.orientation = .portrait
    info.jobDisposition = .save
    info.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = url
    let operation = try #require(job(info))
    operation.jobTitle = title
    operation.showsPrintPanel = false
    operation.showsProgressPanel = false
    #expect(operation.run())
    return try #require(PDFDocument(url: url))
}

/// Save prompts with set answers, recording which ran.
final class StubPrompts: SavePrompts {
    var overwrite = true
    var utf8 = true
    var recreate = true
    /// Which prompts ran, in order: "overwrite", "recreate", "utf8".
    var asked: [String] = []

    func confirmOverwriteNewerFile(named: String) async -> Bool {
        asked.append("overwrite")
        return overwrite
    }

    func confirm(_ offer: SaveOffer, reason: String) async -> Bool {
        asked.append(offer.id)
        return utf8
    }

    func confirmRecreateMissingFile(named: String) async -> Bool {
        asked.append("recreate")
        return recreate
    }
}

/// A document view controller showing the text plugin, read and edited as the host sees it.
extension DocumentViewController {
    var textDocument: TextDocument? { pluginDocument as? TextDocument }
    var shownText: String? { textDocument?.text }
    var pendingText: String? { (textDocument?.unsavedEdits()?.value as? TextEdits)?.text }

    /// Replaces the whole text, as typing would.
    func type(_ text: String) throws {
        #expect(try #require(textDocument).restore(encoded: JSONEncoder().encode(TextEdits(text: text))))
    }
}

extension RecoveryStore {
    /// A store in a new temporary folder.
    static func temporary() -> RecoveryStore {
        RecoveryStore(directory: FileManager.default.temporaryDirectory.appending(path: "peeker-recovery-\(UUID().uuidString)"))
    }
}

/// Preferences only the caller reads, empty at first; call `removePersistentDomain(forName:)` with `name` when done.
func scratchDefaults() -> (defaults: UserDefaults, name: String) {
    let name = "dev.peeker.tests.\(UUID().uuidString)"
    return (UserDefaults(suiteName: name)!, name)
}
