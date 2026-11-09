import AppKit
import PDFKit
import PeekerKit
@testable import PeekerPDF
import Testing

/// A mouse event of `type` over the middle of thumbnail `item`, or outside the thumbnails for -1.
@MainActor private func mouse(_ type: NSEvent.EventType, over item: Int, in view: PageThumbnails, collection: NSCollectionView) -> NSEvent {
    let frame = collection.frameForItem(at: max(item, 0))
    let point = item < 0 ? NSPoint(x: -50, y: -50) : collection.convert(NSPoint(x: frame.midX, y: frame.midY), to: nil)
    return NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: 0, windowNumber: view.window?.windowNumber ?? 0,
                              context: nil, eventNumber: 0, clickCount: 0, pressure: 0)!
}

@Suite(.serialized) struct PDFThumbnailHover {
    @Test func theTintFollowsThePointerAndSkipsTheSelectedPage() async throws {
        let thumbnails = try await Thumbnails(pages: 3)
        defer { thumbnails.close() }
        let view = thumbnails.view
        let collection = try #require(view.hoverCollection)
        collection.selectionIndexPaths = [IndexPath(item: 0, section: 0)]

        view.mouseMoved(with: mouse(.mouseMoved, over: 1, in: view, collection: collection))
        let fill = try #require(view.hoverFill)
        let background = try #require(collection.backgroundView)
        #expect(fill.isDescendant(of: background), "behind the page images, which draw into the collection view's layer")
        #expect(fill.isHovered)
        #expect(fill.convert(fill.bounds, to: collection) == collection.frameForItem(at: 1), "over page 2")

        view.mouseMoved(with: mouse(.mouseMoved, over: 0, in: view, collection: collection))
        #expect(!fill.isHovered, "the selected page keeps its own look")

        view.mouseMoved(with: mouse(.mouseMoved, over: 2, in: view, collection: collection))
        #expect(fill.isHovered && fill.convert(fill.bounds, to: collection) == collection.frameForItem(at: 2))
        view.mouseExited(with: mouse(.mouseMoved, over: -1, in: view, collection: collection))
        #expect(!fill.isHovered)
    }

    @Test func selectingTheHoveredPageTakesTheTintAway() async throws {
        let thumbnails = try await Thumbnails(pages: 3)
        defer { thumbnails.close() }
        let view = thumbnails.view
        let collection = try #require(view.hoverCollection)
        view.mouseMoved(with: mouse(.mouseMoved, over: 1, in: view, collection: collection))
        #expect(view.hoverFill?.isHovered == true)
        collection.selectionIndexPaths = [IndexPath(item: 1, section: 0)]
        #expect(view.hoverFill?.isHovered == false)
    }

    /// The pointer stays over the last thumbnail while its page is deleted: the selection then changes, and the tint
    /// must not ask the collection view for an item it no longer has, which raises an exception.
    @Test func deletingTheHoveredLastPageTakesTheTintAway() async throws {
        let thumbnails = try await Thumbnails(pages: 4)
        defer { thumbnails.close() }
        let view = thumbnails.view
        let collection = try #require(view.hoverCollection)
        view.mouseMoved(with: mouse(.mouseMoved, over: 3, in: view, collection: collection))
        #expect(view.hoverFill?.isHovered == true)
        #expect(thumbnails.document.change(.deletePages(pages: [3], token: "t")))
        collection.selectionIndexPaths = [IndexPath(item: 0, section: 0)]
        #expect(view.hoverFill?.isHovered == false)
    }
}


