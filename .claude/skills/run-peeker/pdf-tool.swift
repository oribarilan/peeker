// Makes and inspects PDFs for the PDF editing flow.
//
// usage: pdf-tool form <out.pdf>     write a one-page form: text field "Name", checkbox "Agree", radio "Pick" (A, B),
//                                    combo box "Color" (Red, Green); written by hand because PDFKit can't write radio groups
//        pdf-tool inspect <in.pdf>   print each form field's value and each annotation, one per line:
//                                    "field Name = Jane Doe", "annotation FreeText peeker = 31 Oct", "annotation Ink peeker"
import Foundation
import PDFKit

func form() -> String {
    let on = "<< /Type /XObject /Subtype /Form /BBox [0 0 16 16] /Length 18 >>\nstream\n0 g 2 2 12 12 re f\nendstream"
    let off = "<< /Type /XObject /Subtype /Form /BBox [0 0 16 16] /Length 0 >>\nstream\n\nendstream"
    let label = "BT /Helv 14 Tf 72 740 Td (Name) Tj 0 -50 Td (I agree) Tj 0 -50 Td (Pick one) Tj 0 -50 Td (Color) Tj 0 -50 Td (Date:) Tj 0 -50 Td (Signature:) Tj ET"
    let objects = [
        "<< /Type /Catalog /Pages 2 0 R /AcroForm 4 0 R >>",
        "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Annots [5 0 R 6 0 R 8 0 R 9 0 R 10 0 R] /Contents 14 0 R /Resources << /Font << /Helv 11 0 R >> >> >>",
        "<< /Fields [5 0 R 6 0 R 7 0 R 10 0 R] /DA (/Helv 0 Tf 0 g) /DR << /Font << /Helv 11 0 R >> >> >>",
        "<< /Type /Annot /Subtype /Widget /FT /Tx /T (Name) /Rect [180 735 420 757] /P 3 0 R /F 4 /DA (/Helv 12 Tf 0 g) /MK << /BC [0 0 0] >> >>",
        "<< /Type /Annot /Subtype /Widget /FT /Btn /T (Agree) /V /Off /AS /Off /Rect [180 686 196 702] /P 3 0 R /F 4 /MK << /BC [0 0 0] >> /AP << /N << /Yes 12 0 R /Off 13 0 R >> >> >>",
        "<< /FT /Btn /Ff 49152 /T (Pick) /V /Off /Kids [8 0 R 9 0 R] >>",
        "<< /Type /Annot /Subtype /Widget /Parent 7 0 R /AS /Off /Rect [180 636 196 652] /P 3 0 R /F 4 /MK << /BC [0 0 0] >> /AP << /N << /A 12 0 R /Off 13 0 R >> >> >>",
        "<< /Type /Annot /Subtype /Widget /Parent 7 0 R /AS /Off /Rect [220 636 236 652] /P 3 0 R /F 4 /MK << /BC [0 0 0] >> /AP << /N << /B 12 0 R /Off 13 0 R >> >> >>",
        "<< /Type /Annot /Subtype /Widget /FT /Ch /Ff 131072 /T (Color) /Opt [(Red) (Green)] /V (Red) /Rect [180 586 300 608] /P 3 0 R /F 4 /DA (/Helv 12 Tf 0 g) /MK << /BC [0 0 0] >> >>",
        "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
        on, off,
        "<< /Length \(label.utf8.count) >>\nstream\n\(label)\nendstream",
    ]
    var out = "%PDF-1.7\n"
    var offsets: [Int] = []
    for (index, object) in objects.enumerated() {
        offsets.append(out.utf8.count)
        out += "\(index + 1) 0 obj\n\(object)\nendobj\n"
    }
    let xref = out.utf8.count
    out += "xref\n0 \(objects.count + 1)\n0000000000 65535 f \n" + offsets.map { String(format: "%010d 00000 n \n", $0) }.joined()
    out += "trailer\n<< /Size \(objects.count + 1) /Root 1 0 R >>\nstartxref\n\(xref)\n%%EOF\n"
    return out
}

let args = CommandLine.arguments
guard args.count == 3 else { print("usage: pdf-tool form|inspect <file>"); exit(2) }
switch args[1] {
case "form":
    try Data(form().utf8).write(to: URL(filePath: args[2]))
case "inspect":
    guard let document = PDFDocument(url: URL(filePath: args[2])) else { print("unreadable"); exit(1) }
    var fields: [String: String] = [:]
    for index in 0..<document.pageCount {
        for annotation in document.page(at: index)?.annotations ?? [] {
            if annotation.type == "Widget", let name = annotation.fieldName {
                fields[name] = annotation.widgetStringValue ?? ""
            } else {
                let ours = (annotation.value(forAnnotationKey: .name) as? String)?.hasPrefix("peeker-") == true
                print("annotation \(annotation.type ?? "?")\(ours ? " peeker" : "")\(annotation.contents.map { " = \($0)" } ?? "")")
            }
        }
    }
    for (name, value) in fields.sorted(by: { $0.key < $1.key }) { print("field \(name) = \(value)") }
default:
    print("usage: pdf-tool form|inspect <file>")
    exit(2)
}
