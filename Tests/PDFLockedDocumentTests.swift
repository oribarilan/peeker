import PDFKit
import PeekerKit
@testable import PeekerPDF
import Testing

/// `file` unlocked with `password` from its lock screen, as the Editor shows it.
@MainActor func unlocked(_ file: URL, with password: String) async throws -> PDFPluginDocument {
    let locked = try await openDocument(file, with: PDFPlugin.self, as: LockedPDFDocument.self)
    var replaced: (any PluginDocument)?
    locked.onReplace = { replaced = $0 }
    #expect(locked.unlock(with: password))
    let document = try #require(replaced as? PDFPluginDocument)
    document.undoManager.groupsByEvent = false
    return document
}

private let box = PDFMark(id: "peeker-box", page: 0, rect: CGRect(x: 100, y: 400, width: 120, height: 24), kind: .textBox(text: "Seen", fontSize: 14))

@Suite(.serialized) struct PDFLockedDocument {
    @Test func savingAnUnlockedPDFKeepsItLocked() async throws {
        let file = try LockedPDF.rc4Form()
        let document = try await unlocked(file, with: LockedPDF.open)
        #expect(document.change(.field(name: "Name", value: "Jane Doe")))
        try await document.save(try #require(document.unsavedEdits()), accepting: nil)
        let reopened = try #require(LockedPDF.opened(file, with: LockedPDF.open))
        #expect(reopened.page(at: 0)?.annotations.first { $0.fieldName == "Name" }?.widgetStringValue == "Jane Doe")
        #expect(document.unsavedEdits() == nil)
    }

    @Test func saveAsKeepsTheLock() async throws {
        let file = try LockedPDF.page(.aes128)
        let document = try await unlocked(file, with: LockedPDF.open)
        #expect(document.change(.add(box)))
        let copy = file.deletingLastPathComponent().appending(path: "copy.pdf")
        try await document.saveAs(document.unsavedEdits(), to: copy, accepting: nil)
        #expect(LockedPDF.opened(copy, with: LockedPDF.open)?.page(at: 0)?.annotations.count == 1)
    }

    @Test func theOpenPasswordIsAskedForOnceAndKept() async throws {
        let file = try LockedPDF.aes256Form()
        let document = try await unlocked(file, with: LockedPDF.perms)
        var asked: [PDFPasswordKind] = []
        document.askForPassword = { kind in
            asked.append(kind); return LockedPDF.open
        }
        #expect(document.change(.add(box)))
        try await document.save(try #require(document.unsavedEdits()), accepting: nil)
        #expect(asked == [.open], "asked by the document itself, with no prompt from the host first")
        #expect(document.lock?.openPassword == LockedPDF.open, "kept for later saves")
        #expect(LockedPDF.opened(file, with: LockedPDF.open)?.permissionsStatus == .user)
        #expect(document.shownNotes == [PDFPlugin.olderEncryptionNote], "said once")
    }

    /// Found in review: the permissions password was taken as the open one, and the real open password stopped working.
    @Test func thePermissionsPasswordIsNotTakenAsTheOpenOne() async throws {
        let file = try LockedPDF.aes256Form(printing: false)
        let before = try Data(contentsOf: file)
        let document = try await unlocked(file, with: LockedPDF.perms)
        document.askForPassword = { _ in LockedPDF.perms }
        #expect(document.change(.add(box)))
        await #expect(throws: PluginError(PDFPluginDocument.notOpenPassword)) {
            try await document.save(try #require(document.unsavedEdits()), accepting: nil)
        }
        #expect(try Data(contentsOf: file) == before)
    }

    @Test func aWrongOrCancelledPasswordWritesNothing() async throws {
        let file = try LockedPDF.aes256Form()
        let before = try Data(contentsOf: file)
        let document = try await unlocked(file, with: LockedPDF.perms)
        #expect(document.change(.add(box)))
        let edits = try #require(document.unsavedEdits())
        document.askForPassword = { _ in "nope" }
        await #expect(throws: PluginError(PDFPluginDocument.notOpenPassword)) { try await document.save(edits, accepting: nil) }
        document.askForPassword = { _ in nil }
        await #expect(throws: PluginError.cancelled) { try await document.save(edits, accepting: nil) }
        #expect(try Data(contentsOf: file) == before)
        #expect(document.unsavedEdits() != nil)
    }

    @Test func aLimitedPDFUnlockedWithItsOpenPasswordAsksForThePermissionsPassword() async throws {
        let file = try LockedPDF.aes256Form(printing: false)
        let document = try await unlocked(file, with: LockedPDF.open)
        document.askForPassword = { kind in kind == .permissions ? LockedPDF.perms : nil }
        #expect(document.change(.add(box)))
        try await document.save(try #require(document.unsavedEdits()), accepting: nil)
        #expect(LockedPDF.opened(file, with: LockedPDF.open)?.allowsPrinting == false)
    }

    @Test func pagesOfALockedPDFCantBeSavedAsNewFilesYet() async throws {
        let document = try await unlocked(try LockedPDF.rc4Form(), with: LockedPDF.open)
        #expect(document.unavailableReason(for: "save-selected-pages") != nil && document.unavailableReason(for: "split") != nil)
    }
}
