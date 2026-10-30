import CoreText
import Foundation

/// Executables built next to the test bundle, such as `test-plugin`.
enum TestProducts {
    static let helpers = Bundle(for: BundleMarker.self).bundleURL.deletingLastPathComponent()

    static func entry(id: String, executable: String, types: [String]) -> PluginEntry {
        PluginEntry(manifest: PluginManifest(id: id, name: id, types: types, executable: executable), helpers: helpers)
    }

    private final class BundleMarker {}
}

enum TempFile {
    /// Writes `bytes` to `name` in a fresh temporary directory.
    static func make(_ bytes: Data, name: String = "f.txt") throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "PeekerTests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: name)
        try bytes.write(to: url)
        return url
    }

    /// A US Letter PDF whose pages say "Page 1", "Page 2" and so on.
    static func makePDF(pages: Int) throws -> URL {
        let url = try make(Data(), name: "f.pdf")
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { throw CocoaError(.fileWriteUnknown) }
        let font = CTFontCreateWithName("Helvetica" as CFString, 24, nil)
        for page in 1...pages {
            context.beginPDFPage(nil)
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: "Page \(page)", attributes: [.font: font]))
            context.textPosition = CGPoint(x: 72, y: 700)
            CTLineDraw(line, context)
            context.endPDFPage()
        }
        context.closePDF()
        return url
    }
}

struct TimedOut: Error {}

/// Polls `condition` every 20 ms; throws `TimedOut` if it isn't true within `seconds`.
func waitUntil(seconds: Double, _ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now + .seconds(seconds)
    while !condition() {
        guard ContinuousClock.now < deadline else { throw TimedOut() }
        try await Task.sleep(for: .milliseconds(20))
    }
}
