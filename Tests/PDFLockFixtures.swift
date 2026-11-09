import CoreText
import PDFKit
@testable import PeekerPDF
import Testing

/// Password-protected PDFs for tests, all with the open password "open" and the permissions password "perms".
enum LockedPDF {
    static let open = "open", perms = "perms"
    /// PDFKit's permission bits for everything but printing (low and high quality).
    static let noPrinting: UInt = 252

    enum Cipher { case aes128, rc4_40 }

    /// A page saying "Secret page", locked by Core Graphics: AES-128 with a 128-bit key, RC4 with a 40-bit one.
    static func page(_ cipher: Cipher, printing: Bool = true) throws -> URL {
        let file = try TempFile.make(Data(), name: "locked.pdf")
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        let info: [CFString: Any] = [kCGPDFContextUserPassword: open, kCGPDFContextOwnerPassword: perms,
                                     kCGPDFContextEncryptionKeyLength: cipher == .aes128 ? 128 : 40, kCGPDFContextAllowsPrinting: printing]
        let context = try #require(CGContext(file as CFURL, mediaBox: &box, info as CFDictionary))
        context.beginPDFPage(nil)
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: "Secret page", attributes: [.font: CTFontCreateWithName("Helvetica" as CFString, 24, nil)]))
        context.textPosition = CGPoint(x: 72, y: 700)
        CTLineDraw(line, context)
        context.endPDFPage()
        context.closePDF()
        return file
    }

    /// The test form locked with 128-bit RC4, as PDFKit writes a loaded document.
    static func rc4Form(printing: Bool = true) throws -> URL {
        let document = try #require(PDFDocument(url: try FormPDF.make()))
        var options: [PDFDocumentWriteOption: Any] = [.userPasswordOption: open, .ownerPasswordOption: perms]
        if !printing { options[.accessPermissionsOption] = noPrinting }
        return try TempFile.make(try #require(document.dataRepresentation(options: options)), name: "locked-form.pdf")
    }

    enum Limit: String { case none = "aes256-form", noPrinting = "aes256-form-no-printing", lowResPrinting = "aes256-form-low-res-printing",
                             noOpenPasswordNoAssembly = "aes256-form-no-open-password" }

    /// A copy of the checked-in form locked with 40-bit RC4 (`/R 2`), allowing no changes or comments.
    static func rc4_40FormNoChanges() throws -> URL {
        let source = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Fixtures/rc4-40-form-no-changes.pdf")
        return try TempFile.make(try Data(contentsOf: source), name: "rc4-40.pdf")
    }

    /// A copy of a checked-in AES-256 form (see Tests/Fixtures/README.md).
    static func aes256Form(printing: Bool = true) throws -> URL { try aes256Form(printing ? .none : .noPrinting) }

    static func aes256Form(_ limit: Limit) throws -> URL {
        let name = limit.rawValue + ".pdf"
        let source = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Fixtures/\(name)")
        return try TempFile.make(try Data(contentsOf: source), name: name)
    }

    /// `file` opened with `password`, or nil when it isn't locked as expected or the password doesn't open it.
    static func opened(_ file: URL, with password: String) -> PDFDocument? {
        guard let document = PDFDocument(url: file), document.isLocked, document.unlock(withPassword: password) else { return nil }
        return document
    }
}
