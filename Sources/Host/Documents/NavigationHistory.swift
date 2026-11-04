import Foundation

/// The places links took one Editor tab, for Back, Forward and the trail. Lasts as long as the tab; never saved.
struct NavigationHistory {
    struct Entry {
        var url: URL
        /// The plugin the file was shown with, so Back returns to it even after Open With.
        var pluginID: String
        /// The place in the file a link named, such as a heading's name.
        var place: String?
        /// The place's title, such as the heading's text, once the document found it.
        var title: String?
        /// Where the document was when the tab left this entry, opaque to the host; only its plugin can read it.
        var position: (any Sendable)?

        /// The trail's name for it: the place's title, or else the file's name.
        var label: String { title ?? url.lastPathComponent }
    }

    private(set) var entries: [Entry]
    private(set) var index = 0

    init(_ first: Entry) {
        entries = [first]
    }

    var current: Entry { entries[index] }
    var canGoBack: Bool { index > 0 }
    var canGoForward: Bool { index < entries.count - 1 }

    /// Adds a place after the current one, dropping any ahead of it.
    mutating func push(_ entry: Entry) {
        entries.removeSubrange((index + 1)...)
        entries.append(entry)
        index += 1
    }

    mutating func back() -> Bool { move(by: -1) }
    mutating func forward() -> Bool { move(by: 1) }

    /// Makes the entry at `target` current; an index outside the history changes nothing.
    mutating func move(to target: Int) {
        if entries.indices.contains(target) { index = target }
    }

    private mutating func move(by step: Int) -> Bool {
        guard entries.indices.contains(index + step) else { return false }
        index += step
        return true
    }

    /// Keeps where the document is now on the current entry, for when the tab comes back to it.
    mutating func record(_ position: any Sendable) {
        entries[index].position = position
    }

    mutating func setTitle(_ title: String, at target: Int) {
        if entries.indices.contains(target) { entries[target].title = title }
    }

    /// Open With showed the current file with another plugin; the old plugin's position means nothing to it.
    mutating func reopened(with pluginID: String) {
        entries[index].pluginID = pluginID
        entries[index].position = nil
    }
}
