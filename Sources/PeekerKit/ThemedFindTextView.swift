import AppKit

/// A text view whose find bar marks matches in the current theme's find color.
///
/// The built-in find bar marks matches in the system yellow and dims everything else, and takes no colors. So this
/// view runs its own `NSTextFinder` with dimming off, the documented way to draw incremental matches yourself, and
/// gives the matches near the visible text a background that isn't part of the text, so it never enters the undo
/// history or a save. The current match keeps the system's find indicator and becomes the selection when the bar closes.
///
/// Being the finder's client leans on NSTextView methods Apple doesn't document. If the finder ever refuses to show
/// its bar, the view falls back to the built-in find bar for good: matches go back to the system yellow, find still works.
open class ThemedFindTextView: NSTextView, @preconcurrency NSTextFinderClient {
    private var finder: NSTextFinder?
    /// Set when this view's own finder didn't work, so the built-in find bar runs instead.
    public private(set) var usesSystemFind = false
    private var matchesObservation: NSKeyValueObservation?
    /// Every match of the current search, in text order.
    private var matches: [NSRange] = []
    /// The characters the last pass marked, so the next one can clear them.
    private var marked: NSRange?

    open override func performTextFinderAction(_ sender: Any?) {
        if let finder = textFinder, let action = action(of: sender) { finder.performAction(action) } else { super.performTextFinderAction(sender) }
    }

    open override func performFindPanelAction(_ sender: Any?) {
        if let finder = textFinder, let action = action(of: sender) { finder.performAction(action) } else { super.performFindPanelAction(sender) }
    }

    open override func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        guard item.action == #selector(performTextFinderAction(_:)) || item.action == #selector(performFindPanelAction(_:)),
            let action = action(of: item), let finder = textFinder
        else { return super.validateUserInterfaceItem(item) }
        return finder.validateAction(action)
    }

    /// The menu's Find items send `NSFindPanelAction` tags, which have the same values as `NSTextFinder.Action`.
    private func action(of sender: Any?) -> NSTextFinder.Action? {
        (sender as? NSValidatedUserInterfaceItem).flatMap { NSTextFinder.Action(rawValue: $0.tag) }
    }

    /// Made on first use; nil once it has failed. NSTextView tells a finder to show nothing unless `usesFindBar` is on,
    /// and the finder then refuses every action, so it goes on here although this finder, not the built-in one, runs the bar.
    private var textFinder: NSTextFinder? {
        if let finder { return finder }
        guard !usesSystemFind else { return nil }
        usesFindBar = true
        isIncrementalSearchingEnabled = true  // for the built-in bar, should it take over
        let finder = NSTextFinder()
        finder.client = self
        finder.findBarContainer = enclosingScrollView
        guard finder.validateAction(.showFindInterface) else {
            finder.client = nil
            finder.findBarContainer = nil
            usesSystemFind = true
            return nil
        }
        finder.isIncrementalSearchingEnabled = true
        finder.incrementalSearchingShouldDimContentView = false
        // The finder updates its matches on the main queue.
        matchesObservation = finder.observe(\.incrementalMatchRanges) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.matchesChanged() }
        }
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(markMatches), name: TextTheme.didChange, object: nil)
        center.addObserver(self, selector: #selector(markMatches), name: NSView.boundsDidChangeNotification, object: enclosingScrollView?.contentView)
        center.addObserver(self, selector: #selector(noteTextChange), name: NSTextStorage.willProcessEditingNotification, object: textStorage)
        self.finder = finder
        return finder
    }

    /// Typing already ends the search; this also ends it for text replaced in code, such as a reload.
    @objc private func noteTextChange(_ notification: Notification) {
        if textStorage?.editedMask.contains(.editedCharacters) == true { finder?.noteClientStringWillChange() }
    }

    /// Mid-edit the layout manager hasn't caught up with the text, so the marks change once the edit is done.
    private func matchesChanged() {
        matches = finder?.incrementalMatchRanges.map(\.rangeValue) ?? []
        if textStorage?.editedMask.isEmpty == false {
            DispatchQueue.main.async { [weak self] in self?.markMatches() }
        } else {
            markMatches()
        }
    }

    /// Marks the matches within a screen of the visible text, so a search with millions of matches stays quick.
    @objc private func markMatches() {
        let length = textStorage?.length ?? 0
        if let marked { setMark(nil, on: NSIntersectionRange(marked, NSRange(location: 0, length: length))) }
        marked = nil
        guard !matches.isEmpty, let visible = visibleCharacters() else { return }
        let start = max(0, visible.location - visible.length)
        let near = NSRange(location: start, length: min(length, NSMaxRange(visible) + visible.length) - start)
        let color = TextTheme.current.findMatch
        for match in matches.lazy.drop(while: { NSMaxRange($0) <= near.location }).prefix(while: { $0.location < NSMaxRange(near) })
        where NSMaxRange(match) <= length {
            setMark(color, on: match)
        }
        marked = near
    }

    /// TextKit 2 views get rendering attributes, TextKit 1 views temporary ones; asking a TextKit 2 view for its layout
    /// manager would switch it to TextKit 1.
    private func setMark(_ color: NSColor?, on range: NSRange) {
        if let textLayoutManager {
            guard let textRange = textRange(range) else { return }
            if let color {
                textLayoutManager.addRenderingAttribute(.backgroundColor, value: color, for: textRange)
            } else {
                textLayoutManager.removeRenderingAttribute(.backgroundColor, for: textRange)
            }
        } else if let color {
            layoutManager?.addTemporaryAttribute(.backgroundColor, value: color, forCharacterRange: range)
        } else {
            layoutManager?.removeTemporaryAttribute(.backgroundColor, forCharacterRange: range)
        }
    }

    private func visibleCharacters() -> NSRange? {
        if let textLayoutManager {
            guard let viewport = textLayoutManager.textViewportLayoutController.viewportRange,
                let content = textLayoutManager.textContentManager
            else { return nil }
            let start = content.offset(from: content.documentRange.location, to: viewport.location)
            return NSRange(location: start, length: content.offset(from: viewport.location, to: viewport.endLocation))
        }
        guard let layoutManager, let textContainer else { return nil }
        let glyphs = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        return layoutManager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
    }

    private func textRange(_ range: NSRange) -> NSTextRange? {
        guard let content = textLayoutManager?.textContentManager,
            let start = content.location(content.documentRange.location, offsetBy: range.location),
            let end = content.location(start, offsetBy: range.length)
        else { return nil }
        return NSTextRange(location: start, end: end)
    }
}
