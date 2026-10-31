import AppKit

/// The extension-list entry for files that have none, such as `.zshrc` or `Makefile`.
public nonisolated let noExtension = "noExtension"

/// A format plugin built into the app. The host routes files to it by extension and shows the document it opens.
/// A plugin may use only this kit, Apple frameworks and its own packages; never the host or another plugin.
public protocol Plugin {
    static var id: String { get }
    static var name: String { get }
    /// The extensions this plugin opens unless the user's config gives it another list: lowercase, without the dot,
    /// and `noExtension` for files that have none. No two plugins list the same one.
    static var defaultExtensions: [String] { get }
    /// Every command the plugin's documents can offer; a document may offer fewer (a view-only one, say). The config
    /// checks shortcut settings against this list, and the config schema lists it.
    static var commands: [CommandSpec] { get }

    /// Reads and decodes `url` off the main thread, then builds the document's views. Checks for cancellation
    /// between steps: the host cancels when the tab closes or the quick-look panel moves on.
    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument

    /// Recovered edits as plain text, for the clipboard when they can't go back into a document; nil when they have
    /// no text form.
    static func recoveryText(from edits: Data) -> String?
}

public extension Plugin {
    static func recoveryText(from edits: Data) -> String? { nil }
}

public struct OpenContext: Sendable {
    /// The largest image dimension worth decoding: the biggest connected screen, in pixels.
    public let maxPixels: Int
    /// False in the quick-look panel, which only views.
    public let allowsEditing: Bool

    public init(maxPixels: Int, allowsEditing: Bool) {
        self.maxPixels = maxPixels
        self.allowsEditing = allowsEditing
    }
}

/// One open file, owned by its plugin. The host puts `contentView` in the window and the sidebar panels beside it,
/// and lists the commands in the toolbar and menus.
@MainActor public protocol PluginDocument: AnyObject, Sendable {
    var contentView: NSView { get }
    /// The view that takes keyboard focus when the document appears, so Cmd+F works without a click first.
    var focusView: NSView? { get }
    var sidebar: [SidebarPanel] { get }
    var commands: [CommandSpec] { get }
    /// Runs the command with `id`. Returns false for an id it doesn't know.
    func perform(_ id: String) -> Bool
    /// Why the command with `id` can't run right now, shown as its tooltip while its menu item and button are greyed
    /// out; nil (the default) when it can. Asked on every menu check, so it must be cheap.
    func unavailableReason(for command: String) -> String?
    /// Re-reads the file after it changed on disk, keeping the view (scroll position, zoom) as it is. The host calls
    /// it only while there are no unsaved edits, and shows `sidebar` again afterwards. Returns false when the document
    /// can't reload in place; the host then opens the file again.
    func reload() async throws(PluginError) -> Bool
    /// Makes the print job for what's on screen, unsaved edits included, from the print info the host passes. Nil
    /// (the default) when the document can't print; the host then greys out Print. A closure so the menu check is
    /// free and the job is built only when Print is chosen; it returns nil if printing turns out to be impossible.
    var printJob: ((NSPrintInfo) -> NSPrintOperation?)? { get }

    // Editing. A view-only document keeps the defaults.

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

    // Edit mode. A document with one opens in a read view that never changes the file; the host's Edit toggle and
    // Cmd+E switch it on and off, and its edit tools show in the toolbar only while it's on.

    /// `.none` (the default) means no edit mode: edits are allowed whenever the window allows them.
    var editMode: EditMode { get }
    /// Called when Edit mode turns on or off. Only for a document whose `editMode` is `.available`.
    func setEditing(_ on: Bool)
}

public extension PluginDocument {
    var focusView: NSView? { nil }
    var sidebar: [SidebarPanel] { [] }
    var commands: [CommandSpec] { [] }
    func perform(_ id: String) -> Bool { false }
    func unavailableReason(for command: String) -> String? { nil }
    func reload() async throws(PluginError) -> Bool { false }
    var printJob: ((NSPrintInfo) -> NSPrintOperation?)? { nil }
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
    var editMode: EditMode { .none }
    func setEditing(_ on: Bool) {}
}

public enum EditMode: Sendable, Equatable {
    case none
    case available
    /// The file can't be edited; `reason` is shown to the user, such as "This PDF's permissions don't allow changes."
    case unavailable(reason: String)
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

public struct CommandSpec: Sendable, Equatable {
    public let id: String
    public let title: String
    public let symbol: String?
    /// Default shortcut, such as `cmd+=`. The user's config can override it.
    public let shortcut: String?
    /// An Edit mode tool: in the toolbar only while Edit mode is on, and run from the read view (by its shortcut or
    /// menu item) it turns Edit mode on first.
    public let isEditTool: Bool

    public init(id: String, title: String, symbol: String? = nil, shortcut: String? = nil, isEditTool: Bool = false) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.shortcut = shortcut
        self.isEditTool = isEditTool
    }
}
