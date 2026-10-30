import CoreGraphics
import Foundation

/// `page` is 0-based; `rect` is in page space.
nonisolated struct Highlight: Codable, Sendable, Equatable {
    let page: Int
    let rect: CGRect
    let color: RGBA

    /// What saving can write: a finite rect of non-negative size that touches the page, in a color within 0...1.
    func isSavable(onPageWithMediaBox mediaBox: CGRect) -> Bool {
        [rect.origin.x, rect.origin.y, rect.size.width, rect.size.height].allSatisfy(\.isFinite)
            && rect.size.width >= 0 && rect.size.height >= 0 && rect.intersects(mediaBox)
            && [color.red, color.green, color.blue, color.alpha].allSatisfy { (0...1).contains($0) }
    }
}

nonisolated struct RGBA: Codable, Sendable, Equatable {
    let red, green, blue, alpha: Double
}

/// A document's unsaved changes. Encoded as `{"pdfHighlights":{"_0":[…]}}`, the shape recovery records had before
/// plugins moved into the app, so those records still restore.
nonisolated enum PDFEdits: Codable, Equatable {
    case pdfHighlights([Highlight])

    var highlights: [Highlight] {
        switch self {
        case .pdfHighlights(let highlights): highlights
        }
    }
}
