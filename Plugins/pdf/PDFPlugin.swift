import AppKit
import CoreGraphics
import PDFKit
import PeekerKit

public enum PDFPlugin: Plugin {
    public static let id = "pdf"
    public static let name = "PDF"
    public static let defaultExtensions = ["pdf"]
    public static let commands = [
        CommandSpec(id: "zoom-in", title: "Zoom In", symbol: "plus.magnifyingglass", shortcut: "cmd+="),
        CommandSpec(id: "zoom-out", title: "Zoom Out", symbol: "minus.magnifyingglass", shortcut: "cmd+-"),
        CommandSpec(id: "text-box", title: "Text Box", symbol: "character.textbox", shortcut: "ctrl+cmd+t", isEditTool: true),
        CommandSpec(id: "sign", title: "Sign", symbol: "signature", shortcut: "ctrl+cmd+s", isEditTool: true),
        CommandSpec(id: "highlight", title: "Highlight", symbol: "highlighter", shortcut: "ctrl+cmd+h", isEditTool: true),
        CommandSpec(id: "rotate-left", title: "Rotate Left", symbol: "rotate.left", shortcut: "cmd+l", isEditTool: true),
        CommandSpec(id: "rotate-right", title: "Rotate Right", symbol: "rotate.right", shortcut: "cmd+r", isEditTool: true),
        CommandSpec(id: "delete-page", title: "Delete Page", symbol: "trash", isEditTool: true),
    ]

    public static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument {
        guard let checked = try await check(url) else { return LockedPDFDocument(url: url, canUnlock: context.allowsEditing) }
        guard let document = PeekerPDFDocument(url: url) else { throw PluginError("This file isn't a readable PDF.") }
        // Edit mode adds annotations and fills in fields, so it needs those two permissions, not "changes" to the pages.
        let reason = checked.uneditableReason
            ?? (document.allowsCommenting && document.allowsFormFieldEntry ? nil : "This PDF's permissions don't allow changes.")
        return PDFPluginDocument(url: url, document: document, info: checked.info, editable: context.allowsEditing, uneditableReason: reason)
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
    @concurrent nonisolated static func write(_ edits: [PDFEdit], to path: String) async throws(PluginError) {
        let name = URL(filePath: path).lastPathComponent
        guard let document = PDFDocument(url: URL(filePath: path)) else { throw PluginError("“\(name)” is no longer a readable PDF.") }
        guard !document.isLocked else { throw PluginError("This PDF is password protected.") }
        let stash = PageStash()
        for edit in edits { try PDFEditing.apply(edit, to: document, fileName: name, stash: stash) }
        let movesPages = edits.contains(where: \.movesPages)
        let kept = movesPages ? MovedPageRepair.kept(in: document) : []
        guard var data = document.dataRepresentation() else { throw PluginError("“\(name)” couldn't be written as a PDF.") }
        if movesPages {
            guard let repaired = MovedPageRepair.repaired(data, kept: kept) else { throw PluginError("“\(name)” couldn't be written as a PDF.") }
            data = repaired
        }
        try FileReplacement.replaceContents(ofFileAt: path, with: data)
    }

    private nonisolated static func string(_ dictionary: CGPDFDictionaryRef?, _ key: String) -> String? {
        guard let dictionary else { return nil }
        var value: CGPDFStringRef?
        guard CGPDFDictionaryGetString(dictionary, key, &value), let value else { return nil }
        return CGPDFStringCopyTextString(value) as String?
    }
}
