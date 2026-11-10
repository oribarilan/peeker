import PDFKit
import PeekerKit
@testable import PeekerPDF
import Testing

private let box = PDFMark(id: "peeker-box", page: 0, rect: CGRect(x: 100, y: 400, width: 120, height: 24), kind: .textBox(text: "Seen", fontSize: 14))

private func lock(_ password: String, open: String? = nil) -> PDFLock {
    var lock = PDFLock(password: password, isPermissionsPassword: password == LockedPDF.perms)
    if let open { lock.openPassword = open }
    return lock
}

private func permissionsLock(_ password: String) -> PDFLock {
    var lock = PDFLock(password: "", isPermissionsPassword: false)
    lock.permissionsPassword = password
    return lock
}

private func hasBox(_ document: PDFDocument?) -> Bool {
    document?.page(at: 0)?.annotations.contains { PDFMarks.id(of: $0) == box.id } == true
}

/// Saving a password-protected PDF keeps its lock: the file's own when PDFKit keeps it, else 128-bit RC4.
@Suite struct PDFLockedSaving {
    @Test func anAES128PDFKeepsItsEncryptionPasswordsAndPermissions() async throws {
        let file = try LockedPDF.page(.aes128, printing: false)
        let note = try await PDFPlugin.write([.add(box)], to: file.path, lock: lock(LockedPDF.open))
        #expect(note == nil)
        let asOpen = try #require(LockedPDF.opened(file, with: LockedPDF.open))
        #expect(hasBox(asOpen) && asOpen.permissionsStatus == .user && !asOpen.allowsPrinting)
        #expect(LockedPDF.opened(file, with: LockedPDF.perms)?.permissionsStatus == .owner)
        #expect(try String(decoding: Data(contentsOf: file), as: UTF8.self).contains("/AESV2"), "still AES-128")
    }

    @Test func anRC4FormUnlockedWithThePermissionsPasswordKeepsBoth() async throws {
        let file = try LockedPDF.rc4Form()
        _ = try await PDFPlugin.write([.field(name: "Name", value: "Jane Doe")], to: file.path, lock: lock(LockedPDF.perms))
        let asOpen = try #require(LockedPDF.opened(file, with: LockedPDF.open))
        #expect(asOpen.permissionsStatus == .user)
        let field = asOpen.page(at: 0)?.annotations.first { $0.fieldName == "Name" }
        #expect(field?.widgetStringValue == "Jane Doe")
        #expect(LockedPDF.opened(file, with: LockedPDF.perms)?.permissionsStatus == .owner)
    }

    @Test func anRC4FormKeepsItsLimits() async throws {
        let file = try LockedPDF.rc4Form(printing: false)
        _ = try await PDFPlugin.write([.add(box)], to: file.path, lock: lock(LockedPDF.open))
        let asOpen = try #require(LockedPDF.opened(file, with: LockedPDF.open))
        #expect(!asOpen.allowsPrinting && asOpen.allowsFormFieldEntry && hasBox(asOpen))
    }

    @Test func anRC40PDFThatLimitsNothingGetsTheOpenPasswordForBoth() async throws {
        let file = try LockedPDF.page(.rc4_40)
        let note = try await PDFPlugin.write([.add(box)], to: file.path, lock: lock(LockedPDF.open))
        #expect(note == PDFPlugin.openPasswordGuardsNote)
        let asOpen = try #require(LockedPDF.opened(file, with: LockedPDF.open))
        #expect(hasBox(asOpen) && asOpen.permissionsStatus == .owner)
    }

    @Test func aPDFThatLimitsSomethingIsNotSavedWithoutItsPermissionsPassword() async throws {
        let file = try LockedPDF.page(.rc4_40, printing: false)
        let before = try Data(contentsOf: file)
        await #expect(throws: PluginError(PDFPlugin.needsPermissionsPassword, offer: PDFPlugin.permissionsPasswordOffer)) {
            try await PDFPlugin.write([.add(box)], to: file.path, lock: lock(LockedPDF.open))
        }
        #expect(try Data(contentsOf: file) == before)
        var both = lock(LockedPDF.open)
        both.permissionsPassword = LockedPDF.perms
        _ = try await PDFPlugin.write([.add(box)], to: file.path, lock: both)
        #expect(LockedPDF.opened(file, with: LockedPDF.open)?.allowsPrinting == false, "saved once the permissions password is given")
    }

    @Test func anAES256FormIsSavedWithRC4AndSaysSo() async throws {
        let file = try LockedPDF.aes256Form()
        let note = try await PDFPlugin.write([.field(name: "Name", value: "Jane Doe")], to: file.path, lock: lock(LockedPDF.open))
        #expect(note == PDFPlugin.olderEncryptionNote + " " + PDFPlugin.openPasswordGuardsNote)
        let asOpen = try #require(LockedPDF.opened(file, with: LockedPDF.open))
        #expect(asOpen.page(at: 0)?.annotations.first { $0.fieldName == "Name" }?.widgetStringValue == "Jane Doe")
    }

    @Test func anAES256FormThatLimitsPrintingNeedsItsPermissionsPassword() async throws {
        let file = try LockedPDF.aes256Form(printing: false)
        await #expect(throws: PluginError(PDFPlugin.needsPermissionsPassword, offer: PDFPlugin.permissionsPasswordOffer)) {
            try await PDFPlugin.write([.add(box)], to: file.path, lock: lock(LockedPDF.open))
        }
    }

    /// Found in review: PDFKit reads low-resolution-only printing as no limit, so the open password stood in for the
    /// permissions password and high-quality printing was allowed.
    @Test func limitsPDFKitMisreadsAreStillLimits() async throws {
        let file = try LockedPDF.aes256Form(.lowResPrinting)
        await #expect(throws: PluginError(PDFPlugin.needsPermissionsPassword, offer: PDFPlugin.permissionsPasswordOffer)) {
            try await PDFPlugin.write([.add(box)], to: file.path, lock: lock(LockedPDF.open))
        }
        _ = try await PDFPlugin.write([.add(box)], to: file.path, lock: lock(LockedPDF.perms, open: LockedPDF.open))
        #expect(PDFEncryption(try Data(contentsOf: file))?.permissions == -2052, "the same /P bits as before")
    }

    /// Found in review: a PDF that opens without a password but limits something couldn't be saved at all.
    @Test func aLimitedPDFWithoutAnOpenPasswordSavesWithItsPermissionsPassword() async throws {
        let file = try LockedPDF.aes256Form(.noOpenPasswordNoAssembly)
        await #expect(throws: PluginError(PDFPlugin.needsPermissionsPassword, offer: PDFPlugin.permissionsPasswordOffer)) {
            try await PDFPlugin.write([.add(box)], to: file.path)
        }
        _ = try await PDFPlugin.write([.add(box)], to: file.path, lock: permissionsLock(LockedPDF.perms))
        let saved = try #require(PDFDocument(url: file))
        #expect(!saved.isLocked && saved.isEncrypted && hasBox(saved))
        #expect(PDFEncryption(try Data(contentsOf: file))?.permissions == -1028, "the same /P bits as before: no assembly")
    }

    /// Found in review: revision 2 files set their reserved bits, which a newer file reads as assembly and form filling.
    @Test func anRC40FilesReservedBitsFollowWhatTheyMeantThere() async throws {
        let file = try LockedPDF.rc4_40FormNoChanges()
        let read = try #require(PDFEncryption(try Data(contentsOf: file)))
        #expect(read.permissions & (1 << 10) == 0 && read.permissions & (1 << 8) == 0, "no assembly and no form filling, as no changes and no comments meant")
        _ = try await PDFPlugin.write([.field(name: "Name", value: "Jane")], to: file.path, lock: lock(LockedPDF.perms, open: LockedPDF.open))
        let written = try #require(PDFEncryption(try Data(contentsOf: file)))
        #expect(written.hasSamePermissions(as: read) && written.permissions & (1 << 10) == 0)
    }

    @Test func anIndirectPIsNotReadAsTheBits() {
        let bytes = Data("1 0 obj\n<< /Filter /Standard /V 2 /R 3 /P 12 0 R /P -3904 >>\nendobj\n".utf8)
        #expect(PDFEncryption(bytes)?.permissions == -3904)
    }

    @Test func splittingAPDFThatOpensWithoutAPasswordStillWorks() async throws {
        let file = try LockedPDF.aes256Form(.noOpenPasswordNoAssembly)
        let part = file.deletingLastPathComponent().appending(path: "part.pdf")
        try await PDFPlugin.writePages([([0], part.path)], edits: [.add(box)], from: file.path)
        #expect(PDFDocument(url: part)?.pageCount == 1)
    }

    @Test func thePDFsOwnPermissionBitsAreReadFromTheFile() throws {
        let read = try #require(PDFEncryption(try Data(contentsOf: try LockedPDF.aes256Form(.lowResPrinting))))
        #expect(read.isAES256 && !read.limitsNothing && read.pdfKitPermissions & 0b10 == 0, "no high-quality printing")
        #expect(PDFEncryption(try Data(contentsOf: try LockedPDF.aes256Form()))?.limitsNothing == true)
        #expect(PDFEncryption(try Data(contentsOf: try TempFile.makePDF(pages: 1))) == nil)
    }

    @Test func anAES256FormUnlockedWithThePermissionsPasswordAsksForTheOpenOne() async throws {
        let file = try LockedPDF.aes256Form(printing: false)
        do {
            try await PDFPlugin.write([.add(box)], to: file.path, lock: lock(LockedPDF.perms))
            Issue.record("saved without the open password")
        } catch {
            #expect(error.offer?.id == PDFPlugin.openPasswordOffer.id)
        }
        let note = try await PDFPlugin.write([.add(box)], to: file.path, lock: lock(LockedPDF.perms, open: LockedPDF.open))
        #expect(note == PDFPlugin.olderEncryptionNote)
        let asOpen = try #require(LockedPDF.opened(file, with: LockedPDF.open))
        #expect(asOpen.permissionsStatus == .user && !asOpen.allowsPrinting && hasBox(asOpen))
        #expect(LockedPDF.opened(file, with: LockedPDF.perms)?.permissionsStatus == .owner)
    }

    @Test func movedPagesInALockedPDFKeepTheirMarksAndTheLock() async throws {
        let file = try LockedPDF.page(.aes128)
        _ = try await PDFPlugin.write([.add(box)], to: file.path, lock: lock(LockedPDF.open))
        _ = try await PDFPlugin.write([.rotatePages(pages: [0], by: 90), .restorePages(pages: [1], token: "t", data: try Data(contentsOf: try TempFile.makePDF(pages: 1))), .reorderPages(order: [1, 0])],
                                      to: file.path, lock: lock(LockedPDF.open))
        let asOpen = try #require(LockedPDF.opened(file, with: LockedPDF.open))
        #expect(asOpen.pageCount == 2 && asOpen.page(at: 1)?.annotations.contains { PDFMarks.id(of: $0) == box.id } == true)
    }
}
