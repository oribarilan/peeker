import AppKit
import CoreGraphics
import PDFKit
import PeekerKit
import UniformTypeIdentifiers

public enum PDFPlugin: Plugin {
    public static let id = "pdf"
    public static let name = "PDF"
    public static let symbol = "doc.richtext"
    public static let defaultExtensions = ["pdf"]
    public static let readableTypes = [UTType.pdf]
    public static let tools =
        [
            ToolSpec(id: "zoom-in", title: "Zoom In", symbol: "plus.magnifyingglass", shortcut: "cmd+=", showsInToolbar: false),
            ToolSpec(id: "zoom-out", title: "Zoom Out", symbol: "minus.magnifyingglass", shortcut: "cmd+-", showsInToolbar: false),
            ToolSpec(
                id: "zoom-fit", title: "Zoom to Fit", symbol: "arrow.up.left.and.down.right.magnifyingglass", shortcut: "cmd+9", showsInToolbar: false
            ),
            ToolSpec(id: "zoom-actual", title: "Actual Size", symbol: "1.magnifyingglass", shortcut: "cmd+0", showsInToolbar: false),
            // Single letters, as Crop's C: they run only while nothing that takes typing has the keyboard.
            ToolSpec(
                id: "markup", title: "Markup", symbol: "pencil.tip.crop.circle", shortcut: "m", isEditTool: true,
                tip: "Pick a tool, or press its key, then click or drag on the page. Hold Option for an ellipse."),
            ToolSpec(
                id: "sign", title: "Sign", symbol: "signature", shortcut: "s", isEditTool: true,
                tip: "Draw your signature, then click where it goes."),
            ToolSpec(
                id: "highlight", title: "Highlight", symbol: "highlighter", shortcut: "h", isEditTool: true,
                tip: "Select text and press {key}, or drag across text while Highlight is on.",
                choices: highlightColors, choicesTitle: "Highlight Color"),
            ToolSpec(id: "rotate-left", title: "Rotate Left", symbol: "rotate.left", isEditTool: true),
            ToolSpec(id: "rotate-right", title: "Rotate Right", symbol: "rotate.right", isEditTool: true),
            ToolSpec(id: "delete-page", title: "Delete Page", symbol: "trash", isEditTool: true),
            ToolSpec(id: "insert-pages", title: "Insert Pages from File…", isEditTool: true, showsInToolbar: false, menu: .file),
            ToolSpec(id: "save-selected-pages", title: "Save Selected Pages As…", isEditTool: true, showsInToolbar: false, menu: .file),
            ToolSpec(id: "split", title: "Split…", isEditTool: true, showsInToolbar: false, menu: .file),
        ] + markupTools.map { ToolSpec(id: $0.id, title: $0.title, symbol: $0.symbol, shortcut: $0.key, isEditTool: true, showsInToolbar: false) }

    /// The markup strip's tools in its order, each in the Tools menu with its key. Keys image markup has too (T, P, L,
    /// A, B) are the same there. Text Box keeps the id it had as a toolbar tool, so shortcuts set for it still work.
    nonisolated static let markupTools: [(id: String, title: String, symbol: String, key: String, shape: PDFDrawing.Shape?)] = [
        ("text-box", "Text Box", "character.textbox", "t", nil), ("markup-pen", "Pen", "scribble", "p", .pen),
        ("markup-line", "Line", "line.diagonal", "l", .line), ("markup-arrow", "Arrow", "arrow.up.right", "a", .arrow),
        ("markup-box", "Box", "rectangle", "b", .box), ("markup-x", "X", "xmark", "x", .x), ("markup-check", "Check", "checkmark", "v", .check),
        ("markup-circle", "Circle", "circle", "o", .circle), ("markup-dot", "Dot", "circle.fill", "d", .dot),
    ]

    /// Preview's five, Yellow first and the default. Opaque: PDFKit drops alpha when writing and draws highlights with
    /// multiply, so text stays readable and a highlight looks the same before and after saving.
    static let highlightColors = [
        ("Yellow", RGBA(red: 1, green: 0.8, blue: 0, alpha: 1)),
        ("Green", RGBA(red: 0.4, green: 0.85, blue: 0.35, alpha: 1)),
        ("Blue", RGBA(red: 0.35, green: 0.65, blue: 1, alpha: 1)),
        ("Pink", RGBA(red: 1, green: 0.45, blue: 0.65, alpha: 1)),
        ("Purple", RGBA(red: 0.72, green: 0.5, blue: 1, alpha: 1)),
    ].map { ToolSpec.Choice(id: "highlight-\($0.0.lowercased())", title: $0.0, color: $0.1) }

    public static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument {
        guard let checked = try await check(url) else {
            return LockedPDFDocument(url: url, canUnlock: context.allowsEditing, preferences: context.preferences)
        }
        guard let document = PeekerPDFDocument(url: url) else { throw PluginError("This file isn't a readable PDF.") }
        return PDFPluginDocument(
            url: url, document: document, info: checked.info, editable: context.allowsEditing,
            uneditableReason: uneditableReason(checked, document), preferences: context.preferences)
    }

    /// Why `document` can't be edited, if it can't. The edit tools add annotations and fill in fields, so it needs those
    /// two permissions, not "changes" to the pages.
    static func uneditableReason(_ checked: Checked, _ document: PDFDocument) -> String? {
        checked.uneditableReason ?? (document.allowsCommenting && document.allowsFormFieldEntry ? nil : "This PDF's permissions don't allow changes.")
    }

    nonisolated struct Checked: Sendable {
        let info: [InfoRow]
        let uneditableReason: String?
    }

    /// Checks with CoreGraphics, which starts faster than PDFKit, that `url` is a readable PDF, and reads what the
    /// info panel shows and whether its form rules out editing. Nil when it needs a password.
    @concurrent nonisolated static func check(_ url: URL) async throws(PluginError) -> Checked? {
        try check(url, password: nil)
    }

    /// The same check for a locked PDF, unlocked with `password`; nil when the password doesn't open it.
    nonisolated static func check(_ url: URL, password: String?) throws(PluginError) -> Checked? {
        guard let document = CGPDFDocument(url as CFURL) else { throw PluginError("This file isn't a readable PDF.") }
        if !document.isUnlocked {
            guard let password, document.unlockWithPassword(password) else { return nil }
        }
        var major: Int32 = 0, minor: Int32 = 0
        document.getVersion(majorVersion: &major, minorVersion: &minor)
        var info = [InfoRow(label: "Pages", value: document.numberOfPages.formatted()), InfoRow(label: "PDF version", value: "\(major).\(minor)")]
        for (key, label) in [("Title", "Title"), ("Author", "Author"), ("Creator", "Created with")] {
            if let value = string(document.info, key), !value.isEmpty { info.append(InfoRow(label: label, value: value)) }
        }
        if document.isEncrypted { info.append(InfoRow(label: "Encrypted", value: "Yes")) }
        return Checked(info: info, uneditableReason: uneditableReason(document))
    }

    /// An XFA form can't be filled with PDFKit, and changing a signed PDF breaks its signatures (`SigFlags` bit 1).
    private nonisolated static func uneditableReason(_ document: CGPDFDocument) -> String? {
        var form: CGPDFDictionaryRef?
        guard let catalog = document.catalog, CGPDFDictionaryGetDictionary(catalog, "AcroForm", &form), let form else { return nil }
        var xfa: CGPDFObjectRef?
        if CGPDFDictionaryGetObject(form, "XFA", &xfa) { return "This form uses XFA, which Peeker can't fill." }
        var flags: CGPDFInteger = 0
        if CGPDFDictionaryGetInteger(form, "SigFlags", &flags), flags & 1 != 0 {
            return "This PDF is digitally signed; changing it would break the signature."
        }
        return nil
    }

    /// Applies `edits` in order to a fresh copy of the file at `path` and writes it. Writes nothing if any edit doesn't
    /// fit the file, and says which. Loads its own copy, so it's safe off the main thread.
    /// Applies `edits` to the PDF at `source` (by default `path`) and writes the result to `path`.
    /// Unlocks a password-protected source with `lock`, keeping its lock in what it writes. Returns a note to show the
    /// user once, when the lock had to change.
    @discardableResult
    @concurrent nonisolated static func write(_ edits: [PDFEdit], from source: String? = nil, to path: String, lock: PDFLock? = nil)
        async throws(PluginError) -> String?
    {
        let saved = try saved(edits, from: source ?? path, lock: lock)
        try FileReplacement.replaceContents(ofFileAt: path, with: saved.data)
        return saved.note
    }

    /// Writes the pages of each run, from the PDF at `source` with `edits` applied, to its file. For Save Selected
    /// Pages As… and Split….
    @concurrent nonisolated static func writePages(_ runs: [(pages: [Int], path: String)], edits: [PDFEdit], from source: String)
        async throws(PluginError)
    {
        guard let full = PDFDocument(data: try edited(edits, from: source)) else {
            throw PluginError("“\(URL(filePath: source).lastPathComponent)” couldn't be read.")
        }
        for run in runs {
            let part = PDFDocument()
            for index in run.pages.sorted() { if let page = full.page(at: index)?.copy() as? PDFPage { part.insert(page, at: part.pageCount) } }
            guard part.pageCount > 0, let data = part.dataRepresentation() else {
                throw PluginError("“\(URL(filePath: run.path).lastPathComponent)” couldn't be written.")
            }
            try FileReplacement.replaceContents(ofFileAt: run.path, with: data)
        }
    }

    /// The PDF at `path` with `edits` applied, as data.
    /// Doesn't keep an encrypted file's lock: for new files made from its pages (Split…, Save Selected Pages As…).
    nonisolated static func edited(_ edits: [PDFEdit], from path: String) throws(PluginError) -> Data {
        try saved(edits, from: path, lock: nil, keepingLock: false).data
    }

    // What a locked save can need. The offers mark the error so the document asks for the password itself and retries;
    // they never reach the host.
    nonisolated static let openPasswordOffer = SaveOffer(id: "open-password", button: "Enter Password…", detail: "")
    nonisolated static let permissionsPasswordOffer = SaveOffer(id: "permissions-password", button: "Enter Password…", detail: "")
    nonisolated static let needsOpenPassword = "Saving this PDF needs its open password too, since it was unlocked with its permissions password."
    nonisolated static let needsPermissionsPassword = "Saving this PDF needs its permissions password, since it limits printing, copying or changes."
    nonisolated static let olderEncryptionNote = "This PDF is now saved with 128-bit RC4 encryption, older than the AES-256 it had."
    nonisolated static let openPasswordGuardsNote =
        "Its open password now also guards its permissions, since Peeker didn't have its permissions password; it limits nothing, so nothing changes for anyone opening it."
    nonisolated static let permissionsPasswordReplacedNote =
        "Its permissions password was replaced, since Peeker didn't have it; it limits nothing, so nothing changes for anyone opening it."

    /// The PDF at `path` with `edits` applied, as data, locked as the file was, and a note when its lock had to change.
    /// An encrypted file is written as PDFKit does by default, which keeps AES-128 and 128-bit RC4 locks as they were;
    /// when that doesn't keep it (RC4-40), it's written with 128-bit RC4 and both passwords. AES-256 always is: its
    /// default write can look right through the permissions password yet no longer open with the open one.
    nonisolated static func saved(_ edits: [PDFEdit], from path: String, lock: PDFLock?, keepingLock: Bool = true) throws(PluginError) -> (
        data: Data, note: String?
    ) {
        let name = URL(filePath: path).lastPathComponent
        guard let bytes = try? Data(contentsOf: URL(filePath: path), options: .mappedIfSafe), let document = PDFDocument(data: bytes) else {
            throw PluginError("“\(name)” is no longer a readable PDF.")
        }
        let needsPassword = document.isLocked
        if needsPassword {
            guard let lock, document.unlock(withPassword: lock.password) else { throw PluginError("This PDF is password protected.") }
        }
        let source = LockState(document, needsPassword: needsPassword)
        let stash = PageStash()
        for edit in edits { try PDFEditing.apply(edit, to: document, fileName: name, stash: stash) }
        let movesPages = edits.contains(where: \.movesPages)
        let kept = movesPages ? MovedPageRepair.kept(in: document) : []
        func written(_ options: [PDFDocumentWriteOption: Any], password: String) throws(PluginError) -> Data {
            guard var data = options.isEmpty ? document.dataRepresentation() : document.dataRepresentation(options: options) else {
                throw PluginError("“\(name)” couldn't be written as a PDF.")
            }
            if movesPages {
                guard let repaired = MovedPageRepair.repaired(data, kept: kept, password: password) else {
                    throw PluginError("“\(name)” couldn't be written as a PDF.")
                }
                data = repaired
            }
            return data
        }
        let plain = try written([:], password: lock?.password ?? "")
        guard let source, keepingLock else { return (plain, nil) }
        let encryption = PDFEncryption(bytes)
        if encryption?.isAES256 != true, source.isKept(by: plain, password: lock?.password ?? "", encryption: encryption) { return (plain, nil) }

        // The file's own lock wasn't kept: write 128-bit RC4 with both passwords and the file's own permission bits.
        guard let encryption else { throw PluginError("“\(name)” couldn't be saved with its password.") }
        let open: String
        if !needsPassword {
            open = ""
        } else if let known = lock?.openPassword {
            open = known
        } else {
            throw PluginError(needsOpenPassword, offer: openPasswordOffer)
        }
        var notes = encryption.isAES256 ? [olderEncryptionNote] : []
        let owner: String
        if let known = lock?.permissionsPassword {
            owner = known
        } else if encryption.limitsNothing {
            owner = needsPassword ? open : UUID().uuidString
            notes.append(needsPassword ? openPasswordGuardsNote : permissionsPasswordReplacedNote)
        } else {
            throw PluginError(needsPermissionsPassword, offer: permissionsPasswordOffer)
        }
        let data = try written(
            [.userPasswordOption: open, .ownerPasswordOption: owner, .accessPermissionsOption: encryption.pdfKitPermissions], password: owner)
        guard let written = PDFEncryption(data), written.hasSamePermissions(as: encryption),
            let asOpen = PDFDocument(data: data), asOpen.isLocked == needsPassword, !needsPassword || asOpen.unlock(withPassword: open),
            owner == open || asOpen.permissionsStatus == .user,  // the open password mustn't get the permissions password's rights
            let asOwner = PDFDocument(data: data), asOwner.unlock(withPassword: owner), asOwner.permissionsStatus == .owner
        else {
            throw PluginError("“\(name)” couldn't be saved with its password.")
        }
        return (data, notes.isEmpty ? nil : notes.joined(separator: " "))
    }

    private nonisolated static func string(_ dictionary: CGPDFDictionaryRef?, _ key: String) -> String? {
        guard let dictionary else { return nil }
        var value: CGPDFStringRef?
        guard CGPDFDictionaryGetString(dictionary, key, &value), let value else { return nil }
        return CGPDFStringCopyTextString(value) as String?
    }
}
