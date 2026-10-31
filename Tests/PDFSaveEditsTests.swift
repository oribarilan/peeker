import AppKit
import PDFKit
import PeekerKit
@testable import PeekerPDF
import Testing

nonisolated private let yellow = RGBA(red: 1, green: 0.8, blue: 0, alpha: 1)
nonisolated private let place = CGRect(x: 100, y: 300, width: 180, height: 60)
nonisolated private let stroke = [CGPoint(x: 0, y: 0), CGPoint(x: 0.5, y: 1), CGPoint(x: 1, y: 0)]

private func annotations(_ file: URL, page: Int = 0) throws -> [PDFAnnotation] {
    let document = try #require(PDFDocument(url: file))
    return try #require(document.page(at: page)).annotations
}

private func named(_ id: String, in file: URL) throws -> PDFAnnotation {
    try #require(try annotations(file).first { PDFMarks.id(of: $0) == id })
}

private func write(_ edits: [PDFEdit], to file: URL) async throws {
    try await PDFPlugin.write(edits, to: file.path)
}

@Suite struct PDFSavingEdits {
    @Test func aHighlightIsSavedWithItsName() async throws {
        let file = try TempFile.makePDF(pages: 1)
        try await write([.add(PDFMark(id: "peeker-h", page: 0, rect: place, kind: .highlight(yellow)))], to: file)
        let saved = try named("peeker-h", in: file)
        #expect(saved.type == "Highlight")
        #expect(abs(saved.bounds.minX - 100) < 0.5 && abs(saved.bounds.width - 180) < 0.5)
    }

    @Test func aTextBoxIsAFreeTextAnnotationWithItsSize() async throws {
        let file = try TempFile.makePDF(pages: 1)
        try await write([.add(PDFMark(id: "peeker-t", page: 0, rect: place, kind: .textBox(text: "31 Oct", fontSize: 18)))], to: file)
        let saved = try named("peeker-t", in: file)
        #expect(saved.type == "FreeText")
        #expect(saved.contents == "31 Oct")
        #expect(PDFMarks.fontSize(of: saved) == 18)
    }

    @Test func aSignatureIsAnInkAnnotationOfItsStrokes() async throws {
        let file = try TempFile.makePDF(pages: 1)
        try await write([.add(PDFMark(id: "peeker-s", page: 0, rect: place, kind: .signature(strokes: [stroke])))], to: file)
        let saved = try named("peeker-s", in: file)
        #expect(saved.type == "Ink")
        let paths = try #require(saved.paths)
        #expect(paths.count == 1)
        // Paths are relative to the annotation's origin and span its size.
        #expect(abs(paths[0].bounds.width - 180) < 1 && abs(paths[0].bounds.height - 60) < 1)
    }

    @Test func movingASavedSignatureKeepsItsNameAndStrokes() async throws {
        let file = try TempFile.makePDF(pages: 1)
        try await write([.add(PDFMark(id: "peeker-s", page: 0, rect: place, kind: .signature(strokes: [stroke])))], to: file)
        let moved = place.offsetBy(dx: 50, dy: -100)
        try await write([.setBounds(id: "peeker-s", type: .signature, page: 0, rect: moved)], to: file)
        #expect(try annotations(file).count == 1)
        let saved = try named("peeker-s", in: file)
        #expect(abs(saved.bounds.minX - 150) < 0.5 && abs(saved.bounds.minY - 200) < 0.5)
        #expect(abs((saved.paths?.first?.bounds.width ?? 0) - 180) < 1)
    }

    @Test func resizingASavedSignatureScalesItsStrokes() async throws {
        let file = try TempFile.makePDF(pages: 1)
        try await write([.add(PDFMark(id: "peeker-s", page: 0, rect: place, kind: .signature(strokes: [stroke])))], to: file)
        try await write([.setBounds(id: "peeker-s", type: .signature, page: 0, rect: CGRect(x: 100, y: 300, width: 90, height: 30))], to: file)
        let path = try #require(try named("peeker-s", in: file).paths?.first)
        #expect(abs(path.bounds.width - 90) < 1 && abs(path.bounds.height - 30) < 1)
    }

    @Test func changingASavedTextBoxsText() async throws {
        let file = try TempFile.makePDF(pages: 1)
        try await write([.add(PDFMark(id: "peeker-t", page: 0, rect: place, kind: .textBox(text: "a", fontSize: 12)))], to: file)
        try await write([.setText(id: "peeker-t", page: 0, text: "bigger", fontSize: 24, rect: place)], to: file)
        let saved = try named("peeker-t", in: file)
        #expect(saved.contents == "bigger" && PDFMarks.fontSize(of: saved) == 24)
    }

    @Test func removingASavedMark() async throws {
        let file = try TempFile.makePDF(pages: 1)
        try await write([.add(PDFMark(id: "peeker-h", page: 0, rect: place, kind: .highlight(yellow)))], to: file)
        try await write([.delete(id: "peeker-h", type: .highlight, page: 0)], to: file)
        #expect(try annotations(file).isEmpty)
    }

    @Test func fieldValuesAreSavedAndStayFields() async throws {
        let file = try FormPDF.make()
        try await write([
            .field(name: "Name", value: "Ori"), .field(name: "Agree", value: "Yes"),
            .field(name: "Pick", value: "B"), .field(name: "Color", value: "Green"),
        ], to: file)
        let widgets = try annotations(file).filter { $0.type == "Widget" }
        #expect(widgets.count == 5, "no field was flattened")
        func value(_ name: String) -> String? { widgets.first { $0.fieldName == name }?.widgetStringValue }
        #expect(value("Name") == "Ori" && value("Agree") == "Yes" && value("Pick") == "B" && value("Color") == "Green")
    }

    @Test func aMoveOfAMarkNoLongerInTheFileWritesNothing() async throws {
        let file = try TempFile.makePDF(pages: 1)
        let bytes = try Data(contentsOf: file)
        await #expect(throws: PluginError("Can't save: the signature to move on page 1 is no longer in “f.pdf”.")) {
            try await write([
                .add(PDFMark(id: "peeker-h", page: 0, rect: place, kind: .highlight(yellow))),
                .setBounds(id: "peeker-gone", type: .signature, page: 0, rect: place),
            ], to: file)
        }
        #expect(try Data(contentsOf: file) == bytes)
    }

    @Test(arguments: [
        PDFEdit.add(PDFMark(id: "peeker-x", page: 1, rect: place, kind: .highlight(yellow))),
        .add(PDFMark(id: "peeker-x", page: -1, rect: place, kind: .highlight(yellow))),
        .add(PDFMark(id: "peeker-x", page: 0, rect: CGRect(x: CGFloat.infinity, y: 0, width: 1, height: 1), kind: .highlight(yellow))),
        .add(PDFMark(id: "peeker-x", page: 0, rect: CGRect(x: 272, y: 614, width: -200, height: -14), kind: .highlight(yellow))),
        .add(PDFMark(id: "peeker-x", page: 0, rect: CGRect(x: 1000, y: 600, width: 200, height: 14), kind: .highlight(yellow))),
        .add(PDFMark(id: "peeker-x", page: 0, rect: place, kind: .highlight(RGBA(red: 2, green: 0, blue: 0, alpha: 1)))),
        .add(PDFMark(id: "peeker-x", page: 0, rect: place, kind: .textBox(text: "a", fontSize: 200))),
        .add(PDFMark(id: "peeker-x", page: 0, rect: place, kind: .signature(strokes: [[CGPoint(x: 5, y: 0)]]))),
        .add(PDFMark(id: "not-ours", page: 0, rect: place, kind: .highlight(yellow))),
        .field(name: "Missing", value: "x"),
    ])
    func refusesEditsThatDontFitTheFile(_ edit: PDFEdit) async throws {
        let file = try TempFile.makePDF(pages: 1)
        let bytes = try Data(contentsOf: file)
        do throws(PluginError) {
            try await PDFPlugin.write([edit], to: file.path)
            Issue.record("saved \(edit)")
        } catch {
            #expect(error.message.hasPrefix("Can't save"), "\(error.message)")
        }
        #expect(try Data(contentsOf: file) == bytes)
    }

    @Test func refusesReadOnlyPDF() async throws {
        let file = try TempFile.makePDF(pages: 1)
        let bytes = try Data(contentsOf: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: file.path)
        await #expect(throws: PluginError("You don't have permission to save “f.pdf”.", code: .notWritable)) {
            try await write([.add(PDFMark(id: "peeker-h", page: 0, rect: place, kind: .highlight(yellow)))], to: file)
        }
        #expect(try Data(contentsOf: file) == bytes)
    }

    @Test func keepsTheFilePermissions() async throws {
        let file = try TempFile.makePDF(pages: 1)
        try FileManager.default.setAttributes([.posixPermissions: 0o640], ofItemAtPath: file.path)
        try await write([.add(PDFMark(id: "peeker-h", page: 0, rect: place, kind: .highlight(yellow)))], to: file)
        #expect(try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? Int == 0o640)
    }
}
