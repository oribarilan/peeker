import AppKit

/// The insertion bar shown between page thumbnails while one is dragged. PDFKit's thumbnail view draws none and has no
/// hook for it, so this stands in for the delegate of the collection view inside it: every message goes on to PDFKit's
/// own delegate, and the answer PDFKit gives to "can this drop land here?" places the bar. If PDFKit's insides change
/// and there's no collection view, nothing is installed and dragging works as before, without the bar.
@MainActor final class ThumbnailDropBar: NSObject, NSCollectionViewDelegate {
    private(set) weak var collectionView: NSCollectionView?
    /// PDFKit's delegate. Read from the two nonisolated forwarding methods, which AppKit calls on the main thread.
    nonisolated(unsafe) private let original: any NSCollectionViewDelegate
    let bar = NSView()
    /// Called as each thumbnail comes into view, after PDFKit has set it up.
    var onWillDisplay: ((NSCollectionViewItem, Int) -> Void)?
    /// Hides the bar once the pointer leaves the thumbnails, which the collection view doesn't report.
    private var exitCheck: Timer?

    var isShowing: Bool { !bar.isHidden && bar.superview != nil }

    init(collectionView: NSCollectionView, original: any NSCollectionViewDelegate) {
        self.collectionView = collectionView
        self.original = original
        super.init()
        bar.wantsLayer = true
        bar.layer?.cornerRadius = 1.5
        bar.isHidden = true
    }

    /// Becomes the delegate of the first collection view inside `view`, or returns the one already there.
    static func install(in view: NSView) -> ThumbnailDropBar? {
        guard let collection = firstCollectionView(in: view), let original = collection.delegate else { return nil }
        if let installed = original as? ThumbnailDropBar { return installed }
        let dropBar = ThumbnailDropBar(collectionView: collection, original: original)
        collection.delegate = dropBar
        return dropBar
    }

    static func firstCollectionView(in view: NSView) -> NSCollectionView? {
        (view as? NSCollectionView) ?? view.subviews.lazy.compactMap(firstCollectionView).first
    }

    // MARK: Passing PDFKit's messages on

    nonisolated override func responds(to selector: Selector!) -> Bool { super.responds(to: selector) || original.responds(to: selector) }

    nonisolated override func forwardingTarget(for selector: Selector!) -> Any? { original.responds(to: selector) ? original : nil }

    func collectionView(_ collectionView: NSCollectionView, willDisplay item: NSCollectionViewItem, forRepresentedObjectAt indexPath: IndexPath) {
        original.collectionView?(collectionView, willDisplay: item, forRepresentedObjectAt: indexPath)
        onWillDisplay?(item, indexPath.item)
    }

    func collectionView(
        _ collectionView: NSCollectionView, validateDrop draggingInfo: any NSDraggingInfo,
        proposedIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>,
        dropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>
    ) -> NSDragOperation {
        let answer =
            original.collectionView?(
                collectionView, validateDrop: draggingInfo, proposedIndexPath: proposedIndexPath,
                dropOperation: dropOperation) ?? []
        // A drop onto a page lands before it, so both kinds of proposal put the bar before the proposed item.
        if answer.isEmpty { hide() } else { show(gapBefore: proposedIndexPath.pointee.item) }
        return answer
    }

    func collectionView(
        _ collectionView: NSCollectionView, acceptDrop draggingInfo: any NSDraggingInfo, indexPath: IndexPath,
        dropOperation: NSCollectionView.DropOperation
    ) -> Bool {
        hide()
        return original.collectionView?(collectionView, acceptDrop: draggingInfo, indexPath: indexPath, dropOperation: dropOperation) ?? false
    }

    func collectionView(
        _ collectionView: NSCollectionView, draggingSession session: NSDraggingSession, endedAt screenPoint: NSPoint,
        dragOperation operation: NSDragOperation
    ) {
        hide()
        original.collectionView?(collectionView, draggingSession: session, endedAt: screenPoint, dragOperation: operation)
    }

    // MARK: The bar

    /// Shows the bar on the boundary before the item at `index`: above the first, below the last when past the end.
    func show(gapBefore index: Int) {
        guard let collection = collectionView else { return }
        let count = collection.numberOfSections > 0 ? collection.numberOfItems(inSection: 0) : 0
        var frame = NSRect.zero
        if count > 0 {
            let index = min(max(index, 0), count)
            let above = index > 0 ? collection.frameForItem(at: index - 1) : nil
            let below = index < count ? collection.frameForItem(at: index) : nil
            let y =
                switch (above, below) {
                case let (above?, below?): (above.maxY + below.minY) / 2
                case let (above?, nil): above.maxY
                case let (nil, below?): below.minY
                case (nil, nil): CGFloat(0)
                }
            let reference = below ?? above ?? .zero
            frame = NSRect(x: reference.minX, y: max(0, y - 1.5), width: reference.width, height: 3)
        }
        bar.frame = frame
        collection.effectiveAppearance.performAsCurrentDrawingAppearance {
            bar.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        }
        collection.addSubview(bar, positioned: .above, relativeTo: nil)  // over the thumbnails, scrolling with them
        bar.isHidden = false
        guard exitCheck == nil else { return }
        exitCheck = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.hideIfPointerLeft() }
        }
    }

    func hide() {
        bar.isHidden = true
        exitCheck?.invalidate()
        exitCheck = nil
    }

    private func hideIfPointerLeft() {
        guard let collection = collectionView, let window = collection.window, NSEvent.pressedMouseButtons != 0 else { return hide() }
        let pointer = collection.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        if !collection.visibleRect.contains(pointer) { hide() }
    }
}
