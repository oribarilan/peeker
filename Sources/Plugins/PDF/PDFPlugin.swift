import AppKit
import PDFKit
import PreviewPPKit
import UniformTypeIdentifiers

public final class PDFPlugin: Plugin {
    public static let manifest = PluginManifest(id: "pdf", name: "PDF", fileTypes: [.pdf])

    public init() {}

    public func open(_ url: URL, host: any PluginHost) throws -> Viewer {
        guard let document = PDFDocument(url: url) else { throw PluginError.unreadable(url) }
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous

        let thumbnails = PDFThumbnailView()
        thumbnails.pdfView = pdfView
        thumbnails.thumbnailSize = NSSize(width: 90, height: 120)
        thumbnails.backgroundColor = .clear

        return Viewer(
            content: WrappingViewController(pdfView),
            sidebar: WrappingViewController(thumbnails),
            commands: [
                Command(id: "zoom-in", title: "Zoom In", symbolName: "plus.magnifyingglass", shortcut: Shortcut("=")) { pdfView.zoomIn(nil) },
                Command(id: "zoom-out", title: "Zoom Out", symbolName: "minus.magnifyingglass", shortcut: Shortcut("-")) { pdfView.zoomOut(nil) },
                Command(id: "highlight", title: "Highlight Selection", symbolName: "highlighter", shortcut: Shortcut("h", [.command, .control])) {
                    Self.highlight(pdfView.currentSelection)
                    pdfView.clearSelection()
                },
                Command(id: "save", title: "Save", symbolName: "square.and.arrow.down", shortcut: Shortcut("s")) {
                    if !document.write(to: url) { NSSound.beep() }
                },
            ]
        )
    }

    private static func highlight(_ selection: PDFSelection?) {
        for line in selection?.selectionsByLine() ?? [] {
            for page in line.pages {
                let annotation = PDFAnnotation(bounds: line.bounds(for: page), forType: .highlight, withProperties: nil)
                annotation.color = .systemYellow.withAlphaComponent(0.5)
                page.addAnnotation(annotation)
            }
        }
    }
}

final class WrappingViewController: NSViewController {
    private let wrapped: NSView

    init(_ view: NSView) {
        wrapped = view
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func loadView() { view = wrapped }
}
