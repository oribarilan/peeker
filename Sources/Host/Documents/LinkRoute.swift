import Foundation

/// Where a link to a local file goes from an Editor tab or the Peek panel. The order follows the specs: a missing
/// file beeps; the tab's own file is a place in it; a file another window shows comes forward; a file the current
/// plugin opens shows in the same tab; one another enabled plugin opens gets a tab of its own; anything else, a
/// folder included, asks before opening in its default app.
enum LinkRoute: Equatable {
    case missing
    /// A place in the current document, such as a heading.
    case place(String)
    /// The current file with no place named: nothing to do.
    case stay
    case bringForward(URL)
    case sameTab(URL, place: String?)
    case ownTab(URL, place: String?)
    case ask(URL)

    /// `link` is an absolute file URL whose fragment names the place. `owner` gives the id of the enabled plugin that
    /// opens a file, nil for none; `isOpenElsewhere` gets the file with symlinks resolved.
    init(link: URL, from current: URL, plugin: String, owner: (URL) -> String?, isOpenElsewhere: (URL) -> Bool) {
        let file = URL(filePath: link.path)
        let place = link.fragment.flatMap { $0.isEmpty ? nil : $0 }
        if !FileManager.default.fileExists(atPath: file.path) {
            self = .missing
        } else if Self.sameFile(file, current) {
            self = place.map { .place($0) } ?? .stay
        } else if isOpenElsewhere(file.resolvingSymlinksInPath()) {
            self = .bringForward(file)
        } else if let owner = owner(file) {
            self = owner == plugin ? .sameTab(file, place: place) : .ownTab(file, place: place)
        } else {
            self = .ask(file)
        }
    }

    /// Whether two file URLs name the same file, seeing through symlinks.
    static func sameFile(_ a: URL, _ b: URL) -> Bool {
        a.resolvingSymlinksInPath().standardizedFileURL.path == b.resolvingSymlinksInPath().standardizedFileURL.path
    }
}
