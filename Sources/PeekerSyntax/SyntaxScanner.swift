import Foundation

/// Colors code with one pass over its UTF-8 bytes, driven by a language's `SyntaxRules`: comments, strings, numbers,
/// keywords, constants and known type names, plus two guesses (a word before `(` is a function, a capitalized word is a
/// type). There's no grammar, so unusual syntax can fool it; a string or comment that isn't multi-line stops at the end
/// of its line, which keeps a mistake from spreading.
public enum SyntaxScanner {
    /// Text larger than this (UTF-8) is left plain by the callers.
    public static let maxBytes = 1_048_576

    /// Spans in text order, never overlapping; text no span covers keeps the body color.
    public static func spans(in text: String, language: SyntaxLanguage) -> [SyntaxSpan] {
        var scanner = Scanner(bytes: Array(text.utf8), rules: SyntaxRules.of(language))
        scanner.run()
        return scanner.spans
    }
}

private struct Scanner {
    let bytes: [UInt8]
    let rules: SyntaxRules
    var spans: [SyntaxSpan] = []
    private var i = 0
    /// UTF-8 to UTF-16 conversion only moves forward, so the spans cost one pass in all.
    private var convertedByte = 0
    private var convertedUnits = 0

    init(bytes: [UInt8], rules: SyntaxRules) {
        self.bytes = bytes
        self.rules = rules
    }

    mutating func run() {
        while i < bytes.count {
            let start = i
            let byte = bytes[i]
            if let comment = rules.blockComment, matches(comment.open, at: i) {
                skipBlockComment(comment)
                emit(start, .comment)
            } else if rules.lineComments.contains(where: { matches($0, at: i) }), commentCanStart(at: i) {
                skipToLineEnd()
                emit(start, .comment)
            } else if let string = rules.strings.first(where: { matches($0.delimiter, at: i) }) {
                skipString(string)
                emit(start, .string)
            } else if isDigit(byte) {
                number(from: start)
            } else if rules.hexColors, byte == UInt8(ascii: "#"), i + 1 < bytes.count, isHex(bytes[i + 1]) {
                i += 1
                while i < bytes.count, isWord(bytes[i]) || isDigit(bytes[i]) { i += 1 }
                emit(start, .number)
            } else if isWordStart(byte) {
                word(from: start)
            } else {
                i += 1
            }
        }
    }

    // MARK: Words

    private mutating func word(from start: Int) {
        skipWord()
        let end = i
        let word = bytes[start..<end]
        if rules.stringPrefixes, end - start <= 2, word.allSatisfy({ "rRbBfFuU".utf8.contains($0) }),
           let string = rules.strings.first(where: { matches($0.delimiter, at: end) }) {
            skipString(string)
            return emit(start, .string)
        }
        let key = SyntaxRules.Key(word, folding: rules.caseInsensitive)
        if let key, rules.keywords.contains(key) { return emit(start, .keyword) }
        if let key, rules.constants.contains(key) { return emit(start, .number) }
        if let key, rules.types.contains(key) { return emit(start, .type) }
        if rules.guessesFunctions, end < bytes.count, bytes[end] == UInt8(ascii: "(") { return emit(start, .function) }
        guard rules.guessesTypes, isUpper(bytes[start]) else { return }
        // ALL_CAPS (two letters or more) is a constant; Capitalized is a type.
        let shouting = end - start > 1 && word.allSatisfy { isUpper($0) || isDigit($0) || $0 == UInt8(ascii: "_") }
        emit(start, shouting ? .number : .type)
    }

    private mutating func skipWord() {
        i += 1
        while i < bytes.count, isWord(bytes[i]) || isDigit(bytes[i]) { i += 1 }
    }

    // MARK: Numbers

    /// Decimal with `_` separators, a fraction and an exponent, or 0x/0o/0b. A number running into letters (`10px`, `1j`)
    /// stays plain unless the language takes units.
    private mutating func number(from start: Int) {
        if bytes[i] == UInt8(ascii: "0"), i + 1 < bytes.count, "xXoObB".utf8.contains(bytes[i + 1]) {
            i += 2
            while i < bytes.count, isHex(bytes[i]) || bytes[i] == UInt8(ascii: "_") { i += 1 }
        } else {
            skipDigits()
            if i + 1 < bytes.count, bytes[i] == UInt8(ascii: "."), isDigit(bytes[i + 1]) {
                i += 1
                skipDigits()
            }
            if i < bytes.count, bytes[i] | 0x20 == UInt8(ascii: "e") {
                var next = i + 1
                if next < bytes.count, bytes[next] == UInt8(ascii: "+") || bytes[next] == UInt8(ascii: "-") { next += 1 }
                if next < bytes.count, isDigit(bytes[next]) {
                    i = next
                    skipDigits()
                }
            }
        }
        if rules.numberUnits {
            while i < bytes.count, isWord(bytes[i]) || bytes[i] == UInt8(ascii: "%") { i += 1 }
        } else if i < bytes.count, isWord(bytes[i]) {
            skipWord()
            return
        }
        emit(start, .number)
    }

    private mutating func skipDigits() {
        while i < bytes.count, isDigit(bytes[i]) || bytes[i] == UInt8(ascii: "_") { i += 1 }
    }

    // MARK: Comments and strings

    private mutating func skipBlockComment(_ comment: (open: [UInt8], close: [UInt8])) {
        var depth = 0
        while i < bytes.count {
            if matches(comment.open, at: i), depth == 0 || rules.nestedComments {
                depth += 1
                i += comment.open.count
            } else if matches(comment.close, at: i) {
                i += comment.close.count
                depth -= 1
                if depth == 0 { return }
            } else {
                i += 1
            }
        }
    }

    private mutating func skipToLineEnd() {
        while i < bytes.count, bytes[i] != 0x0A, bytes[i] != 0x0D { i += 1 }
    }

    /// Past the string that starts at `i`, including any interpolated code in it, whose own strings and parentheses
    /// are followed so a quote inside doesn't end the outer string.
    private mutating func skipString(_ string: SyntaxRules.StringRule, depth: Int = 0) {
        i += string.delimiter.count
        while i < bytes.count {
            let byte = bytes[i]
            if let open = string.interpolation, matches(open, at: i), depth < 4 {
                i += open.count
                skipInterpolation(closing: open.last!, depth: depth)
            } else if string.escapes, byte == UInt8(ascii: "\\") {
                i += 2
            } else if matches(string.delimiter, at: i) {
                i += string.delimiter.count
                return
            } else if !string.multiline, byte == 0x0A || byte == 0x0D {
                return
            } else {
                i += 1
            }
        }
        i = min(i, bytes.count)
    }

    /// Past interpolated code up to the bracket that closes `opening` (`(` or `{`).
    private mutating func skipInterpolation(closing opening: UInt8, depth: Int) {
        let close = opening == UInt8(ascii: "(") ? UInt8(ascii: ")") : UInt8(ascii: "}")
        var level = 1
        while i < bytes.count {
            let byte = bytes[i]
            if byte == 0x0A || byte == 0x0D { return }  // unfinished: leave it to the line's end
            if let inner = rules.strings.first(where: { !$0.multiline && matches($0.delimiter, at: i) }) {
                skipString(inner, depth: depth + 1)
                continue
            }
            if byte == opening { level += 1 } else if byte == close {
                level -= 1
                if level == 0 {
                    i += 1
                    return
                }
            }
            i += 1
        }
    }

    private func commentCanStart(at index: Int) -> Bool {
        switch rules.commentStart {
        case .anywhere: return true
        case .wordStart: return index == 0 || " \t\n\r;|&(".utf8.contains(bytes[index - 1])
        case .lineStart:
            var k = index
            while k > 0, bytes[k - 1] == UInt8(ascii: " ") || bytes[k - 1] == UInt8(ascii: "\t") { k -= 1 }
            return k == 0 || bytes[k - 1] == 0x0A || bytes[k - 1] == 0x0D
        }
    }

    // MARK: Bytes

    private func matches(_ pattern: [UInt8], at index: Int) -> Bool {
        guard index + pattern.count <= bytes.count, bytes[index] == pattern[0] else { return false }
        for k in 1..<pattern.count where bytes[index + k] != pattern[k] { return false }
        return true
    }

    private func isDigit(_ byte: UInt8) -> Bool { byte &- 0x30 < 10 }
    private func isUpper(_ byte: UInt8) -> Bool { byte &- 0x41 < 26 }
    private func isHex(_ byte: UInt8) -> Bool { isDigit(byte) || (byte | 0x20) &- 0x61 < 6 }
    private func isWord(_ byte: UInt8) -> Bool {
        (byte | 0x20) &- 0x61 < 26 || byte == UInt8(ascii: "_") || byte >= 0x80 || rules.wordBytes.contains(byte)
    }
    private func isWordStart(_ byte: UInt8) -> Bool { isWord(byte) || rules.wordStartBytes.contains(byte) }

    // MARK: Spans

    private mutating func emit(_ start: Int, _ role: SyntaxRole) {
        let location = utf16(at: start)
        let length = utf16(at: i) - location
        if length > 0 { spans.append(SyntaxSpan(range: NSRange(location: location, length: length), role: role)) }
    }

    private mutating func utf16(at byte: Int) -> Int {
        while convertedByte < byte {
            let lead = bytes[convertedByte]
            convertedUnits += lead & 0xC0 == 0x80 ? 0 : lead >= 0xF0 ? 2 : 1
            convertedByte += 1
        }
        return convertedUnits
    }
}
