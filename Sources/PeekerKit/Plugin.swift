import AppKit
import UniformTypeIdentifiers

/// The extension-list entry for files that have none, such as `.zshrc` or `Makefile`.
public nonisolated let noExtension = "noExtension"

/// A format plugin built into the app. The host routes files to it by extension and shows the document it opens.
/// A plugin may use only this kit, Apple frameworks and its own packages; never the host or another plugin.
public protocol Plugin {
    static var id: String { get }
    static var name: String { get }
    /// The SF Symbol beside the plugin's pane in Settings. Default: a puzzle piece.
    static var symbol: String { get }
    /// The extensions this plugin opens unless the user's config gives it another list: lowercase, without the dot,
    /// and `noExtension` for files that have none. No two plugins list the same one.
    static var defaultExtensions: [String] { get }
    /// The file types this plugin can show, so Open With offers it for files another plugin owns. Default: none, so
    /// it's offered only for the files it owns.
    static var readableTypes: [UTType] { get }
    /// Every tool the plugin's documents can offer; a document may offer fewer (a view-only one, say). The config
    /// checks shortcut settings against this list, and the config schema lists it.
    static var tools: [ToolSpec] { get }

    /// Reads and decodes `url` off the main thread, then builds the document's views. Checks for cancellation
    /// between steps: the host cancels when the tab closes or the Peek panel moves on.
    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument

    /// Recovered edits as plain text, for the clipboard when they can't go back into a document; nil when they have
    /// no text form.
    static func recoveryText(from edits: Data) -> String?
}

public extension Plugin {
    static var symbol: String { "puzzlepiece.extension" }
    static var readableTypes: [UTType] { [] }
    static func recoveryText(from edits: Data) -> String? { nil }
}

public struct OpenContext: Sendable {
    /// The largest image dimension worth decoding: the biggest connected screen, in pixels.
    public let maxPixels: Int
    /// False in the Peek panel, which only views.
    public let allowsEditing: Bool
    /// Where the plugin keeps settings between launches; nil in tests and benchmarks, which keep nothing.
    public let preferences: PluginPreferences?

    public init(maxPixels: Int, allowsEditing: Bool, preferences: PluginPreferences? = nil) {
        self.maxPixels = maxPixels
        self.allowsEditing = allowsEditing
        self.preferences = preferences
    }
}

/// One open file, owned by its plugin. The host puts `contentView` in the window and the sidebar panels beside it,
/// and lists the tools in the toolbar and menus.
@MainActor public protocol PluginDocument: AnyObject, Sendable {
    var contentView: NSView { get }
    /// The view that takes keyboard focus when the document appears, so Cmd+F works without a click first.
    var focusView: NSView? { get }
    /// Builds the sidebar panels. The host calls it when the document appears, after a save and after a reload, and
    /// replaces the panels it showed before.
    func makeSidebar() -> [SidebarPanel]
    /// Set by the host: call it when the sidebar's contents changed at another time, such as an outline that follows
    /// typing; the host then calls `makeSidebar()` again. The default ignores it.
    var onSidebarChange: (() -> Void)? { get set }
    var tools: [ToolSpec] { get }
    /// Runs the tool with `id`. Returns false for an id it doesn't know.
    func perform(_ id: String) -> Bool
    /// Why the tool with `id` can't run right now, shown as its tooltip while its menu item and button are greyed
    /// out; nil (the default) when it can. Asked on every menu check, so it must be cheap.
    func unavailableReason(for tool: String) -> String?
    /// Re-reads the file after it changed on disk, keeping the view (scroll position, zoom) as it is. The host calls
    /// it only while there are no unsaved edits, and makes the sidebar again afterwards. Returns false when the document
    /// can't reload in place; the host then opens the file again.
    func reload() async throws(PluginError) -> Bool
    /// Makes the print job for what's on screen, unsaved edits included, from the print info the host passes. Nil
    /// (the default) when the document can't print; the host then greys out Print. A closure so the menu check is
    /// free and the job is built only when Print is chosen; it returns nil if printing turns out to be impossible.
    var printJob: ((NSPrintInfo) -> NSPrintOperation?)? { get }

    /// Set by the host: call it with another document for the same file to be shown instead of this one, such as a
    /// PDF unlocked from its lock screen. The default ignores it.
    var onReplace: ((any PluginDocument) -> Void)? { get set }

    /// The tool waiting for the user, such as one waiting for its click or drag; the window shows it as selected.
    /// Nil when none, the default.
    var activeTool: String? { get }
    /// Set by the host: call it whenever `activeTool` changes. The default ignores it.
    var onActiveToolChange: (() -> Void)? { get set }
    /// Whether a tool that turns something on and off, such as Wrap Lines, is on now: the host checks its menu item
    /// and draws its toolbar button pressed while it is. Nil, the default, for a tool that isn't such a switch. Asked
    /// on every menu check, so it must be cheap.
    func isOn(_ tool: String) -> Bool?

    // Editing. A view-only document keeps the defaults. Before a save, a print or the unsaved-changes question, the
    // host takes the keyboard focus from the views of a document with edit tools, so typing in progress (a text box,
    // a form field) must count as an edit once its view loses focus.

    /// Whether the user can change this file, decided when it opens: the Editor shows a read-only document's edit
    /// tools greyed out with the reason. `.notEditable`, the default, for a document that never takes edits.
    var editability: Editability { get }

    /// Called after each change the user makes.
    var onEdit: (() -> Void)? { get set }
    /// A snapshot of the unsaved changes, or nil when there are none. Must be cheap: the host takes one to save and
    /// to keep a recovery copy, and encodes it off the main thread.
    func unsavedEdits() -> UnsavedEdits?
    /// Applies edits encoded from an earlier `unsavedEdits()`, such as recovered ones, as if the user had made them.
    /// Returns false when this document can't take them (it's view-only, read-only, or they don't fit the file).
    func restore(encoded edits: Data) -> Bool
    /// Writes `edits`, an earlier result of `unsavedEdits()`, into the file, off the main thread. Once it returns,
    /// those edits are saved; changes made since stay pending. A failure may come with an offer, such as saving in
    /// another encoding; when the user accepts it, the host calls again with that offer.
    func save(_ edits: UnsavedEdits, accepting offer: SaveOffer?) async throws(PluginError)
    /// Drops the unsaved changes, going back to the file as last loaded or saved.
    func revertEdits()
}

public extension PluginDocument {
    var focusView: NSView? { nil }
    func makeSidebar() -> [SidebarPanel] { [] }
    var tools: [ToolSpec] { [] }
    func perform(_ id: String) -> Bool { false }
    func unavailableReason(for tool: String) -> String? { nil }
    func reload() async throws(PluginError) -> Bool { false }
    var printJob: ((NSPrintInfo) -> NSPrintOperation?)? { nil }
    var onSidebarChange: (() -> Void)? {
        get { nil }
        set {}  // a sidebar that changes only on save or reload never calls it
    }
    var onReplace: ((any PluginDocument) -> Void)? {
        get { nil }
        set {}  // a document that never replaces itself ignores it
    }
    var activeTool: String? { nil }
    func isOn(_ tool: String) -> Bool? { nil }
    var onActiveToolChange: (() -> Void)? {
        get { nil }
        set {}  // a document without an active tool never calls it
    }
    var onEdit: (() -> Void)? {
        get { nil }
        set {}  // a view-only document never calls it
    }
    func unsavedEdits() -> UnsavedEdits? { nil }
    func restore(encoded edits: Data) -> Bool { false }
    func save(_ edits: UnsavedEdits, accepting offer: SaveOffer?) async throws(PluginError) {
        throw PluginError("This document can't be saved.")
    }
    func revertEdits() {}
    var editability: Editability { .notEditable }
}

/// A document that follows links to local files, such as Markdown's relative links. The host decides where each
/// link goes (a place in this document, this tab, another tab or another app) and keeps the tab's Back and Forward
/// history; the document resolves its own link syntax and moves its own view.
@MainActor public protocol LinkFollowing: PluginDocument {
    /// Set by the host: call it with a link to a local file, resolved to an absolute file URL, its fragment naming a
    /// place in it. Links to this document's own file come here too. Links with a scheme stay with the document.
    var onFollowLink: ((URL) -> Void)? { get set }
    /// Where the view is now, opaque to the host, handed back to `restore(_:)` when Back or Forward returns here.
    var position: any Sendable { get }
    /// Returns to a position this document gave earlier, as near as the current content allows.
    func restore(_ position: any Sendable)
    /// Goes to the place `name` names, such as a heading; returns its title for the history trail, or nil when there's
    /// no such place. Waits for content still being parsed or drawn.
    func go(to name: String) async -> String?
}

public enum Editability: Sendable, Equatable {
    case editable
    /// The file can't be edited; the reason is shown to the user, such as "This PDF's permissions don't allow changes."
    case readOnly(String)
    /// The document never takes edits, such as rendered Markdown or anything in the Peek panel.
    case notEditable
}

/// A document's unsaved changes at one moment, in the plugin's own type. The host only stores and passes it back;
/// `encoded()` gives the JSON a recovery copy keeps, and is meant to run off the main thread.
public nonisolated struct UnsavedEdits: Sendable {
    public let value: any Encodable & Sendable

    public init(_ value: any Encodable & Sendable) {
        self.value = value
    }

    public func encoded() throws -> Data {
        try JSONEncoder().encode(value)
    }
}

/// What a save can do instead when the plain save failed, such as saving as UTF-8. The host shows the failure's
/// message, `detail` and a button titled `button`.
public nonisolated struct SaveOffer: Sendable, Equatable {
    /// Lets the plugin tell its offers apart.
    public let id: String
    public let button: String
    public let detail: String

    public init(id: String, button: String, detail: String) {
        self.id = id
        self.button = button
        self.detail = detail
    }
}

public struct SidebarPanel {
    public enum Sizing { case fit, fill }

    public let view: NSView
    /// `.fit` takes the height the view needs (info); `.fill` shares what's left (lists).
    public let sizing: Sizing

    public init(_ view: NSView, sizing: Sizing) {
        self.view = view
        self.sizing = sizing
    }
}

public struct ToolSpec: Sendable, Equatable {
    public let id: String
    public let title: String
    public let symbol: String?
    /// Default shortcut, such as `cmd+=`. The user's config can override it.
    public let shortcut: String?
    /// An edit tool, listed in the Tools menu: greyed out with the reason while the document is read-only. Other
    /// tools are view tools, listed in the View menu.
    public let isEditTool: Bool
    /// False keeps the tool out of the toolbar: it's in its menu, with its shortcut, only. Zoom tools are.
    public let showsInToolbar: Bool
    /// What to do next, shown once from the toolbar button the first time the tool runs, for tools that wait for a
    /// selection, a click or a drag. `{key}` stands for the tool's key, which the user may have changed.
    public let tip: String?

    public init(id: String, title: String, symbol: String? = nil, shortcut: String? = nil, isEditTool: Bool = false,
                showsInToolbar: Bool = true, tip: String? = nil) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.shortcut = shortcut
        self.isEditTool = isEditTool
        self.showsInToolbar = showsInToolbar
        self.tip = tip
    }
}
