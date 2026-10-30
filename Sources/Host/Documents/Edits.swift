/// A document's unsaved changes, as its component reports them. What a save sends and crash recovery keeps.
nonisolated enum Edits: Codable, Equatable, Sendable {
    case text(String)
    case pdfHighlights([Highlight])
}
