import Foundation
import PDFKit
import PeekerKit

/// What Peeker knows of a password-protected PDF's passwords while its window is open, kept only in memory: the one
/// that unlocked it, and each of the two once known.
nonisolated struct PDFLock: Sendable {
    /// The password that unlocked it; empty for a PDF that opens without one.
    let password: String
    /// The permissions (owner) password, rather than the open (user) one. The same password for both counts as this.
    let isPermissionsPassword: Bool
    var openPassword: String?
    var permissionsPassword: String?

    init(password: String, isPermissionsPassword: Bool) {
        self.password = password
        self.isPermissionsPassword = isPermissionsPassword
        openPassword = isPermissionsPassword ? nil : password
        permissionsPassword = isPermissionsPassword ? password : nil
    }
}

/// What a PDF's standard security handler says about it, read from the file's bytes, where its encryption dictionary
/// is never compressed or encrypted. PDFKit reports permissions only as seen through the password used, and reads
/// some limits wrong (low-resolution-only printing, say), so the permission bits come from here.
nonisolated struct PDFEncryption: Equatable {
    /// The `/P` bits that mean something (PDF 32000-1, table 22): print, modify, copy, annotate, fill forms, extract
    /// for accessibility, assemble and print at high quality.
    static let meaningful: Int32 = (1 << 2) | (1 << 3) | (1 << 4) | (1 << 5) | (1 << 8) | (1 << 9) | (1 << 10) | (1 << 11)

    let permissions: Int32
    let isAES256: Bool
    let isAES128: Bool

    /// Nil for a PDF without the standard handler, or whose `/P` can't be found. Only the newest encryption dictionary
    /// is read, found from the end of the file, and only the bytes around it are decoded.
    init?(_ bytes: Data) {
        guard let standard = bytes.range(of: Data("/Standard".utf8), options: .backwards),
            let start = bytes.range(of: Data("obj".utf8), options: .backwards, in: bytes.startIndex..<standard.lowerBound)?.upperBound
        else { return nil }
        let end =
            bytes.range(of: Data("endobj".utf8), in: standard.upperBound..<min(bytes.endIndex, standard.upperBound + 8192))?.lowerBound
            ?? min(bytes.endIndex, standard.upperBound + 8192)
        guard standard.lowerBound - start < 8192 else { return nil }
        // Strings (the password records) are left out, so their bytes can't look like `/P`.
        let dictionary = String(decoding: bytes[start..<end], as: UTF8.self)
            .replacing(#/\((?:\\.|[^\\)])*\)|<[0-9A-Fa-f\s]*>/#, with: "")
        guard dictionary.contains("/Filter"),
            let match = dictionary.firstMatch(of: #/\/P\s*(-?\d+)\b(?!\s+\d+\s+R)/#), let value = Int64(match.1)
        else { return nil }
        var bits = Int32(truncatingIfNeeded: value)
        if let revision = dictionary.firstMatch(of: #/\/R\s*(\d+)\b/#), revision.1 == "2" {
            // Revision 2 reserves bits 9 to 12; what they mean later follows bits 6, 5, 4 and 3 there.
            bits &= ~((1 << 8) | (1 << 9) | (1 << 10) | (1 << 11))
            for (later, earlier) in [(8, 5), (9, 4), (10, 3), (11, 2)] where bits & (1 << earlier) != 0 { bits |= 1 << later }
        }
        permissions = bits
        isAES256 = dictionary.contains("/AESV3")
        isAES128 = dictionary.contains("/AESV2")
    }

    var limitsNothing: Bool { permissions & Self.meaningful == Self.meaningful }

    /// The same permissions in PDFKit's `accessPermissionsOption` bits: low-quality printing, high-quality printing,
    /// changes, assembly, copying, accessibility, commenting and form filling, in that order.
    var pdfKitPermissions: UInt {
        let pdfBits: [Int32] = [1 << 2, 1 << 11, 1 << 3, 1 << 10, 1 << 4, 1 << 9, 1 << 5, 1 << 8]
        return pdfBits.enumerated().reduce(0) { bits, entry in permissions & entry.element != 0 ? bits | (1 << entry.offset) : bits }
    }

    func hasSamePermissions(as other: PDFEncryption) -> Bool {
        permissions & Self.meaningful == other.permissions & Self.meaningful
    }
}

/// An encrypted PDF's lock as seen through the password that unlocked it: whether it needs a password to open and
/// which password that was. A plain save must leave this, and the file's own permission bits, as they were.
nonisolated struct LockState: Equatable {
    let needsPassword: Bool
    let isOwner: Bool

    /// Nil for a PDF that isn't encrypted. `needsPassword` is whether it was locked before being unlocked.
    init?(_ document: PDFDocument, needsPassword: Bool) {
        guard document.isEncrypted else { return nil }
        self.needsPassword = needsPassword
        isOwner = document.permissionsStatus == .owner
    }

    /// Whether `data` is locked as this was, with the same cipher and permission bits as `encryption`, and opens with
    /// `password` in the same role.
    func isKept(by data: Data, password: String, encryption: PDFEncryption?) -> Bool {
        guard let encryption, let written = PDFEncryption(data), written.hasSamePermissions(as: encryption),
            written.isAES128 == encryption.isAES128, written.isAES256 == encryption.isAES256,
            let copy = PDFDocument(data: data), copy.isLocked == needsPassword
        else { return false }
        if copy.isLocked, !copy.unlock(withPassword: password) { return false }
        return LockState(copy, needsPassword: needsPassword) == self
    }
}
