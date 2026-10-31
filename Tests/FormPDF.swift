import Foundation

/// A hand-written one-page US Letter PDF with an AcroForm: a text field "Name" at (72, 700), a checkbox "Agree", a
/// radio group "Pick" (A, B), a combo box "Color" (Red, Green), a link at (300, 700) and a note another app made at
/// (300, 600). PDFKit can't write radio groups or form flags reliably, so the bytes are written by hand.
enum FormPDF {
    static let nameField = CGRect(x: 72, y: 700, width: 200, height: 20)
    static let link = CGRect(x: 300, y: 700, width: 100, height: 20)
    static let note = CGRect(x: 300, y: 600, width: 20, height: 20)

    /// `acroForm` goes into the AcroForm dictionary, such as `/SigFlags 3` or `/XFA 16 0 R`; `extra` objects are
    /// numbered from 16.
    static func make(acroForm: String = "", extra: [String] = []) throws -> URL {
        let on = "<< /Type /XObject /Subtype /Form /BBox [0 0 16 16] /Length 18 >>\nstream\n0 g 2 2 12 12 re f\nendstream"
        let off = "<< /Type /XObject /Subtype /Form /BBox [0 0 16 16] /Length 0 >>\nstream\n\nendstream"
        let objects = [
            "<< /Type /Catalog /Pages 2 0 R /AcroForm 4 0 R >>",
            "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Annots [5 0 R 6 0 R 8 0 R 9 0 R 10 0 R 14 0 R 15 0 R] /Resources << /Font << /Helv 11 0 R >> >> >>",
            "<< /Fields [5 0 R 6 0 R 7 0 R 10 0 R] /DA (/Helv 0 Tf 0 g) /DR << /Font << /Helv 11 0 R >> >> \(acroForm) >>",
            "<< /Type /Annot /Subtype /Widget /FT /Tx /T (Name) /Rect [72 700 272 720] /P 3 0 R /F 4 /DA (/Helv 12 Tf 0 g) >>",
            "<< /Type /Annot /Subtype /Widget /FT /Btn /T (Agree) /V /Off /AS /Off /Rect [72 650 88 666] /P 3 0 R /F 4 /AP << /N << /Yes 12 0 R /Off 13 0 R >> >> >>",
            "<< /FT /Btn /Ff 49152 /T (Pick) /V /Off /Kids [8 0 R 9 0 R] >>",
            "<< /Type /Annot /Subtype /Widget /Parent 7 0 R /AS /Off /Rect [72 600 88 616] /P 3 0 R /F 4 /AP << /N << /A 12 0 R /Off 13 0 R >> >> >>",
            "<< /Type /Annot /Subtype /Widget /Parent 7 0 R /AS /Off /Rect [102 600 118 616] /P 3 0 R /F 4 /AP << /N << /B 12 0 R /Off 13 0 R >> >> >>",
            "<< /Type /Annot /Subtype /Widget /FT /Ch /Ff 131072 /T (Color) /Opt [(Red) (Green)] /V (Red) /Rect [72 550 172 570] /P 3 0 R /F 4 /DA (/Helv 12 Tf 0 g) >>",
            "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
            on, off,
            "<< /Type /Annot /Subtype /Link /Rect [300 700 400 720] /Border [0 0 0] /A << /S /URI /URI (https://example.com) >> >>",
            "<< /Type /Annot /Subtype /Text /Rect [300 600 320 620] /Contents (A note) /NM (acrobat-1) >>",
        ] + extra
        var out = "%PDF-1.7\n"
        var offsets: [Int] = []
        for (index, object) in objects.enumerated() {
            offsets.append(out.utf8.count)
            out += "\(index + 1) 0 obj\n\(object)\nendobj\n"
        }
        let xref = out.utf8.count
        out += "xref\n0 \(objects.count + 1)\n0000000000 65535 f \n"
        for offset in offsets { out += String(format: "%010d 00000 n \n", offset) }
        out += "trailer\n<< /Size \(objects.count + 1) /Root 1 0 R >>\nstartxref\n\(xref)\n%%EOF\n"
        return try TempFile.make(Data(out.utf8), name: "form.pdf")
    }
}
