import Foundation

/// The kinds of code text that get a color of their own; everything else keeps the body color.
public enum SyntaxRole: String, Sendable, CaseIterable {
    case keyword, string, comment, number, type, function
}

/// A run of code text and what it is. The range is in UTF-16 units, as NSString and the text views count.
public struct SyntaxSpan: Sendable, Equatable {
    public let range: NSRange
    public let role: SyntaxRole

    public init(range: NSRange, role: SyntaxRole) {
        self.range = range
        self.role = role
    }
}
