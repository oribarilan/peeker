// Generates benchmark inputs in bench/fixtures. Run: swift bench/make-fixtures.swift
import AppKit
import Foundation

let dir = URL(filePath: "bench/fixtures")
try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

func write(_ name: String, _ text: String) throws {
    try text.write(to: dir.appending(path: name), atomically: true, encoding: .utf8)
}

func logLines(_ count: Int) -> String {
    (0..<count).map { "2026-10-29T12:00:\(String(format: "%02d", $0 % 60)).\($0 % 1000)Z INFO [worker-\($0 % 16)] request id=\($0) path=/api/v1/items/\($0 * 7) status=200 duration_ms=\($0 % 997)" }
        .joined(separator: "\n")
}

try write("small.txt", logLines(100))
try write("medium.log", logLines(100_000))      // ~13 MB
try write("large.log", logLines(800_000))       // ~100 MB

let section = """
## Section %d

Some **bold** and *italic* text with `inline code` and a [link](https://example.com).

- [ ] open task %d
- [x] done task
- plain item

```swift
let answer = %d
```

> A quote that spans a line.


"""
try write("small.md", "# Small\n\n" + (1...5).map { String(format: section, $0, $0, $0) }.joined())
try write("large.md", "# Large\n\n" + (1...4_000).map { String(format: section, $0, $0, $0) }.joined()) // ~1 MB

try write("small.csv", "name,city,score\n" + (0..<100).map { "person \($0),city \($0 % 13),\($0 * 37 % 101)" }.joined(separator: "\n"))
try write("large.csv", "id,name,city,score,notes\n" + (0..<50_000).map { "\($0),person \($0),city \($0 % 13),\($0 * 37 % 101),\"note, with comma \($0)\"" }.joined(separator: "\n"))

func pdf(_ name: String, pages: Int) {
    let url = dir.appending(path: name) as CFURL
    var box = CGRect(x: 0, y: 0, width: 612, height: 792)
    guard let context = CGContext(url, mediaBox: &box, nil) else { fatalError("pdf context") }
    let paragraph = String(repeating: "The quick brown fox jumps over the lazy dog. ", count: 40)
    for page in 1...pages {
        context.beginPDFPage(nil)
        let graphics = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.current = graphics
        ("Page \(page)\n\n" + paragraph + "\n\n" + paragraph).draw(in: box.insetBy(dx: 54, dy: 54), withAttributes: [.font: NSFont.systemFont(ofSize: 11)])
        context.endPDFPage()
    }
    context.closePDF()
}
pdf("small.pdf", pages: 3)
pdf("large.pdf", pages: 2_000)
print("fixtures written")
