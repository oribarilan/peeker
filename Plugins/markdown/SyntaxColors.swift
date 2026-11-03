import AppKit
import PeekerKit
import PeekerSyntax

extension TextTheme.SyntaxColors {
    /// The theme's color for a kind of code text.
    func color(for role: SyntaxRole) -> NSColor {
        switch role {
        case .keyword: keyword
        case .string: string
        case .comment: comment
        case .number: number
        case .type: type
        case .function: function
        }
    }
}
