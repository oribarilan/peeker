import Foundation

/// Names headings the way GitHub does, so `#name` links written for GitHub land on the same heading here. Explicit
/// HTML anchors (`<a id="x">`) aren't headings and get no name.
nonisolated enum HeadingNames {
    /// The title lowercased, each space turned into a hyphen, and everything but letters, marks, digits, hyphens and
    /// underscores dropped.
    static func name(for title: String) -> String {
        var name = String.UnicodeScalarView()
        for scalar in title.lowercased().unicodeScalars {
            if scalar == " " {
                name.append("-")
            } else if scalar == "-" || kept.contains(scalar.properties.generalCategory) {
                name.append(scalar)
            }
        }
        return String(name)
    }

    /// Letters, marks, digits and connectors such as `_`.
    private static let kept: Set<Unicode.GeneralCategory> = [
        .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter,
        .nonspacingMark, .spacingMark, .enclosingMark, .decimalNumber, .letterNumber, .otherNumber, .connectorPunctuation,
    ]

    /// Each heading's name in order; a repeated name gets `-1`, `-2` and so on.
    static func names(for outline: [OutlineItem]) -> [String] {
        var seen: [String: Int] = [:]
        return outline.map { item in
            let base = name(for: item.title)
            defer { seen[base, default: 0] += 1 }
            return seen[base].map { "\(base)-\($0)" } ?? base
        }
    }

    /// The heading `name` names, ignoring case, after decoding percent escapes.
    static func index(of name: String, in outline: [OutlineItem]) -> Int? {
        let wanted = (name.removingPercentEncoding ?? name).lowercased()
        return names(for: outline).firstIndex(of: wanted)
    }
}
