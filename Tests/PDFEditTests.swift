import Foundation
@testable import PeekerPDF
import Testing

nonisolated private let box = CGRect(x: 72, y: 600, width: 120, height: 20)

private func textBox(_ id: String = "peeker-1", text: String = "Hi") -> PDFMark {
    PDFMark(id: id, page: 0, rect: box, kind: .textBox(text: text, fontSize: 12))
}

@Suite struct PDFEditFolding {
    @Test func aMoveOfAnUnsavedMarkRewritesItsAdd() {
        let moved = box.offsetBy(dx: 10, dy: 0)
        var expected = textBox()
        expected.rect = moved
        #expect(PDFEdit.folded([.add(textBox()), .setBounds(id: "peeker-1", type: .textBox, page: 0, rect: moved)]) == [.add(expected)])
    }

    @Test func aTextChangeOfAnUnsavedBoxRewritesItsAdd() {
        let wider = CGRect(x: 72, y: 600, width: 200, height: 20)
        let folded = PDFEdit.folded([.add(textBox()), .setText(id: "peeker-1", page: 0, text: "Hello", fontSize: 18, rect: wider)])
        #expect(folded == [.add(PDFMark(id: "peeker-1", page: 0, rect: wider, kind: .textBox(text: "Hello", fontSize: 18)))])
    }

    @Test func deletingAnUnsavedMarkDropsItAndItsChanges() {
        let folded = PDFEdit.folded([
            .add(textBox()), .add(textBox("peeker-2")),
            .setBounds(id: "peeker-1", type: .textBox, page: 0, rect: box.offsetBy(dx: 5, dy: 0)),
            .delete(id: "peeker-1", type: .textBox, page: 0),
        ])
        #expect(folded == [.add(textBox("peeker-2"))])
    }

    @Test func changesToASavedMarkKeepOnlyTheLatest() {
        let first = box.offsetBy(dx: 5, dy: 0), second = box.offsetBy(dx: 9, dy: 0)
        let folded = PDFEdit.folded([
            .setBounds(id: "peeker-s", type: .signature, page: 0, rect: first),
            .setBounds(id: "peeker-s", type: .signature, page: 0, rect: second),
        ])
        #expect(folded == [.setBounds(id: "peeker-s", type: .signature, page: 0, rect: second)])
    }

    @Test func deletingASavedMarkDropsItsPendingChanges() {
        let folded = PDFEdit.folded([
            .setBounds(id: "peeker-s", type: .signature, page: 0, rect: box),
            .delete(id: "peeker-s", type: .signature, page: 0),
        ])
        #expect(folded == [.delete(id: "peeker-s", type: .signature, page: 0)])
    }

    /// Undoing the removal of a saved mark adds it back under its name; removing it again must still remove the saved one.
    @Test func removingASavedMarkAgainAfterUndoKeepsTheRemoval() {
        let mark = textBox("peeker-s")
        let delete = PDFEdit.delete(id: "peeker-s", type: .textBox, page: 0)
        #expect(PDFEdit.folded([delete, .add(mark), delete]) == [delete])
    }

    @Test func aNewerFieldValueReplacesTheOlder() {
        let folded = PDFEdit.folded([.field(name: "Name", value: "O"), .field(name: "Agree", value: "Yes"), .field(name: "Name", value: "Ori")])
        #expect(folded == [.field(name: "Agree", value: "Yes"), .field(name: "Name", value: "Ori")])
    }
}

@Suite struct PDFEditEncoding {
    @Test func operationsRoundTrip() throws {
        let edits: [PDFEdit] = [
            .add(PDFMark(id: "peeker-h", page: 1, rect: box, kind: .highlight(RGBA(red: 1, green: 0.8, blue: 0, alpha: 1)))),
            .add(textBox()),
            .add(PDFMark(id: "peeker-s", page: 0, rect: box, kind: .signature(strokes: [[CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0.5)]]))),
            .setBounds(id: "peeker-s", type: .signature, page: 0, rect: box),
            .setText(id: "peeker-1", page: 0, text: "Hello", fontSize: 14, rect: box),
            .delete(id: "peeker-h", type: .highlight, page: 1),
            .field(name: "Name", value: "Ori"),
        ]
        #expect(try JSONDecoder().decode([PDFEdit].self, from: JSONEncoder().encode(edits)) == edits)
    }

    @Test func newIDsArePeekerNames() {
        let id = PDFEdit.newID()
        #expect(id.hasPrefix("peeker-") && id != PDFEdit.newID())
    }
}
