import AppKit

/// Prints a multi-page TIFF one page per sheet, each by the single-image rule: its own size in points, shrunk to fit
/// the sheet when larger, never enlarged, centered.
final class PagesPrintView: NSView {
    private let pages: [ImagePlugin.PrintPage]
    private let printInfo: NSPrintInfo

    init(pages: [ImagePlugin.PrintPage], printInfo: NSPrintInfo) {
        self.pages = pages
        self.printInfo = printInfo
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var isFlipped: Bool { true }

    /// The printable area of a sheet, as the print panel has it now.
    private var sheet: CGSize { (NSPrintOperation.current?.printInfo ?? printInfo).imageablePageBounds.size }

    override func knowsPageRange(_ range: NSRangePointer) -> Bool {
        setFrameSize(CGSize(width: sheet.width, height: sheet.height * CGFloat(pages.count)))
        range.pointee = NSRange(location: 1, length: pages.count)
        return true
    }

    override func rectForPage(_ page: Int) -> NSRect {
        NSRect(x: 0, y: CGFloat(page - 1) * sheet.height, width: sheet.width, height: sheet.height)
    }

    /// Where page `page`, counted from 1, is drawn on its sheet.
    func pictureRect(forPage page: Int) -> NSRect {
        let sheetRect = rectForPage(page), size = pages[page - 1].size
        guard size.width > 0, size.height > 0 else { return .zero }
        let scale = min(1, sheetRect.width / size.width, sheetRect.height / size.height)
        let drawn = CGSize(width: size.width * scale, height: size.height * scale)
        return NSRect(x: sheetRect.midX - drawn.width / 2, y: sheetRect.midY - drawn.height / 2, width: drawn.width, height: drawn.height)
    }

    override func draw(_ dirtyRect: NSRect) {
        for page in pages.indices.map({ $0 + 1 }) where rectForPage(page).intersects(dirtyRect) {
            NSImage(cgImage: pages[page - 1].image, size: .zero)
                .draw(in: pictureRect(forPage: page), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        }
    }
}
