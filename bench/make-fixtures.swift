// Generates benchmark inputs in bench/fixtures. Run: swift bench/make-fixtures.swift
import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

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
func image(_ name: String, width: Int, height: Int, type: UTType, quality: Double = 0.85) {
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let colors = [CGColor(red: 0.1, green: 0.3, blue: 0.6, alpha: 1), CGColor(red: 0.9, green: 0.6, blue: 0.3, alpha: 1)] as CFArray
    context.drawLinearGradient(CGGradient(colorsSpace: nil, colors: colors, locations: nil)!, start: .zero,
                               end: CGPoint(x: width, y: height), options: [])
    var seed: UInt64 = 42
    func next() -> Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double(seed >> 11) / Double(1 << 53) }
    for _ in 0..<4000 {
        context.setFillColor(CGColor(red: next(), green: next(), blue: next(), alpha: 0.35))
        context.fillEllipse(in: CGRect(x: next() * Double(width), y: next() * Double(height), width: next() * 300, height: next() * 300))
    }
    let destination = CGImageDestinationCreateWithURL(dir.appending(path: name) as CFURL, type.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
    CGImageDestinationFinalize(destination)
}
image("small.png", width: 512, height: 512, type: .png)
image("photo.jpg", width: 4032, height: 3024, type: .jpeg)
image("photo.heic", width: 4032, height: 3024, type: .heic)
image("large.png", width: 8000, height: 6000, type: .png)
print("fixtures written")
