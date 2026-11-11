import AppKit
import PDFKit
import PeekerKit
@testable import PeekerPDF
import Testing

/// A PDF of `pages` pages open in the Editor, with its thumbnails laid out in a window of their own.
@MainActor final class Thumbnails {
    let document: PDFPluginDocument
    let view: PageThumbnails
    private let windows: [NSWindow]

    init(pages: Int) async throws {
        document = try await openDocument(try TempFile.makePDF(pages: pages), with: PDFPlugin.self, as: PDFPluginDocument.self)
        view = try #require(document.makeSidebar().first?.view as? PageThumbnails)
        windows = [offscreenWindow(holding: document.pdfView), offscreenWindow(holding: view, width: 200, height: 900)]
        view.layoutSubtreeIfNeeded()
    }

    func close() { windows.forEach { $0.close() } }
}

/// A delegate that allows or refuses every drop, standing in for PDFKit's.
private final class Answering: NSObject, NSCollectionViewDelegate {
    var answer: NSDragOperation = .move
    var accepted = false

    func collectionView(
        _ collectionView: NSCollectionView, validateDrop draggingInfo: any NSDraggingInfo,
        proposedIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>,
        dropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>
    ) -> NSDragOperation { answer }

    func collectionView(
        _ collectionView: NSCollectionView, acceptDrop draggingInfo: any NSDraggingInfo, indexPath: IndexPath,
        dropOperation: NSCollectionView.DropOperation
    ) -> Bool {
        accepted = true
        return true
    }
}

/// Just enough of a drag for a delegate that never looks at it.
private final class Drag: NSObject, NSDraggingInfo {
    var draggingDestinationWindow: NSWindow? { nil }
    var draggingSourceOperationMask: NSDragOperation { .move }
    var draggingLocation: NSPoint { .zero }
    var draggedImageLocation: NSPoint { .zero }
    var draggedImage: NSImage? { nil }
    var draggingPasteboard: NSPasteboard { NSPasteboard(name: .drag) }
    var draggingSource: Any? { nil }
    var draggingSequenceNumber: Int { 1 }
    func slideDraggedImage(to screenPoint: NSPoint) {}
    var draggingFormation: NSDraggingFormation = .default
    var animatesToDestination = false
    var numberOfValidItemsForDrop = 1
    func enumerateDraggingItems(
        options: NSDraggingItemEnumerationOptions = [], for view: NSView?, classes: [AnyClass],
        searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
        using block: @escaping (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void
    ) {}
    var springLoadingHighlight: NSSpringLoadingHighlight { .none }
    func resetSpringLoading() {}
}

@MainActor private func validate(_ bar: ThumbnailDropBar, item: Int, _ operation: NSCollectionView.DropOperation = .before) -> NSDragOperation {
    var path = IndexPath(item: item, section: 0) as NSIndexPath
    var dropOperation = operation
    return bar.collectionView(NSCollectionView(), validateDrop: Drag(), proposedIndexPath: &path, dropOperation: &dropOperation)
}

@Suite(.serialized, .enabled(if: PageThumbnails.dragsReorderPages, "thumbnail drags reorder pages only on macOS 27 and later"))
struct ThumbnailDropBars {
    @Test func itStandsInForPDFKitsDelegateAndPassesItsMessagesOn() async throws {
        let thumbnails = try await Thumbnails(pages: 3)
        defer { thumbnails.close() }
        let bar = try #require(thumbnails.view.dropBar)
        let delegate = try #require(bar.collectionView?.delegate)
        #expect(delegate === bar)
        #expect(delegate.responds(to: #selector(NSCollectionViewDelegate.collectionView(_:acceptDrop:indexPath:dropOperation:))))
        #expect(delegate.responds(to: #selector(NSCollectionViewDelegate.collectionView(_:validateDrop:proposedIndexPath:dropOperation:))))
        #expect(!bar.isShowing)
    }

    @Test func theBarSitsInTheGapWhereThePageWillLand() async throws {
        let thumbnails = try await Thumbnails(pages: 3)
        defer { thumbnails.close() }
        let bar = try #require(thumbnails.view.dropBar)
        let collection = try #require(bar.collectionView)
        let frames = (0..<3).map { collection.frameForItem(at: $0) }
        bar.show(gapBefore: 0)
        #expect(bar.isShowing)
        #expect(bar.bar.frame.midY <= frames[0].minY + 2, "above page 1")
        bar.show(gapBefore: 2)
        #expect(abs(bar.bar.frame.midY - (frames[1].maxY + frames[2].minY) / 2) < 1, "between pages 2 and 3")
        bar.show(gapBefore: 3)
        #expect(bar.bar.frame.midY >= frames[2].maxY - 2, "below the last page")
        #expect(abs(bar.bar.frame.width - frames[0].width) < 1)
        bar.hide()
        #expect(!bar.isShowing)
    }

    @Test func theBarFollowsWhetherTheDropIsAllowed() {
        let original = Answering()
        let collection = NSCollectionView()
        let bar = ThumbnailDropBar(collectionView: collection, original: original)
        #expect(validate(bar, item: 0) == .move)
        #expect(bar.isShowing)
        original.answer = []
        #expect(validate(bar, item: 1) == [])
        #expect(!bar.isShowing, "a refused drop shows no bar")
        original.answer = .move
        _ = validate(bar, item: 1, .on)
        #expect(bar.isShowing, "a drop onto a page shows the bar before it")
        #expect(bar.collectionView(collection, acceptDrop: Drag(), indexPath: IndexPath(item: 1, section: 0), dropOperation: .before))
        #expect(original.accepted && !bar.isShowing, "the drop reaches the original, and the bar goes")
        // A drag session can't be made here; the bar answers its end, which hides it.
        #expect(bar.responds(to: #selector(NSCollectionViewDelegate.collectionView(_:draggingSession:endedAt:dragOperation:))))
    }

    @Test func withoutACollectionViewNothingIsInstalled() {
        #expect(ThumbnailDropBar.install(in: NSView()) == nil)
    }
}
