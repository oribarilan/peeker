import PDFKit
import PeekerKit
@testable import PeekerPDF
import Testing

private let box = PDFMark(id: "peeker-box", page: 0, rect: CGRect(x: 100, y: 400, width: 120, height: 24), kind: .textBox(text: "Seen", fontSize: 14))

/// The crash-recovery copy of a password-protected PDF is encrypted with a key from its password, and comes back
/// once the PDF is unlocked again.
@Suite(.serialized) struct PDFLockedRecovery {
    private func record(of file: URL) async throws -> Data {
        let document = try await unlocked(file, with: LockedPDF.open)
        #expect(document.change(.field(name: "Name", value: "Jane Doe")) && document.change(.add(box)))
        return try #require(document.unsavedEdits()).encoded()
    }

    @Test func theRecoveryCopyCantBeReadWithoutThePassword() async throws {
        let record = try await record(of: try LockedPDF.rc4Form())
        let text = String(decoding: record, as: UTF8.self)
        #expect(!text.contains("Jane Doe") && !text.contains("Seen") && !text.contains("peeker-box"))
        #expect(try JSONDecoder().decode(SealedEdits.self, from: record).salt.count == 16)
    }

    @Test func afterACrashTheEditsComeBackOnceUnlocked() async throws {
        let file = try LockedPDF.rc4Form()
        let record = try await record(of: file)
        let locked = try await openDocument(file, with: PDFPlugin.self, as: LockedPDFDocument.self)
        #expect(locked.restore(encoded: record))
        let held = try JSONDecoder().decode(SealedEdits.self, from: try #require(locked.unsavedEdits()).encoded())
        #expect(try held == JSONDecoder().decode(SealedEdits.self, from: record), "kept as it was until unlocked")
        await #expect(throws: PluginError(LockedPDFDocument.unlockToSave)) { try await locked.save(try #require(locked.unsavedEdits()), accepting: nil) }
        var replaced: (any PluginDocument)?
        locked.onReplace = { replaced = $0 }
        #expect(locked.unlock(with: LockedPDF.open))
        let document = try #require(replaced as? PDFPluginDocument)
        #expect(document.pendingEdits.contains(.add(box)) && document.pendingEdits.contains(.field(name: "Name", value: "Jane Doe")))
    }

    @Test func theOtherPasswordSaysTheChangesNeedTheFirst() async throws {
        let file = try LockedPDF.rc4Form()
        let record = try await record(of: file)
        let locked = try await openDocument(file, with: PDFPlugin.self, as: LockedPDFDocument.self)
        #expect(locked.restore(encoded: record))
        var replaced: (any PluginDocument)?
        locked.onReplace = { replaced = $0 }
        #expect(!locked.unlock(with: LockedPDF.perms))
        #expect(locked.message == LockedPDFDocument.otherPasswordMessage && replaced == nil)
        #expect(locked.unlock(with: LockedPDF.open))
    }

    @Test func dontSaveDropsTheHeldChanges() async throws {
        let file = try LockedPDF.rc4Form()
        let locked = try await openDocument(file, with: PDFPlugin.self, as: LockedPDFDocument.self)
        #expect(locked.restore(encoded: try await record(of: file)))
        locked.revertEdits()
        #expect(locked.unsavedEdits() == nil)
    }

    @Test func aPlainRecordIsNotTakenByTheLockScreen() async throws {
        let locked = try await openDocument(try LockedPDF.rc4Form(), with: PDFPlugin.self, as: LockedPDFDocument.self)
        #expect(!locked.restore(encoded: try JSONEncoder().encode([PDFEdit.add(box)])))
    }
}
