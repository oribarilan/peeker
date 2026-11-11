import Foundation

/// A language described as data for the scanner. One table per language family; dropping or fixing a language touches
/// only its entry here.
struct SyntaxRules: Sendable {
    struct StringRule: Sendable {
        let delimiter: [UInt8]
        var escapes = true
        var multiline = false
        /// Code inside the string that ends at the matching bracket: `\(` in Swift, `$(` in shell, `${` in JavaScript.
        var interpolation: [UInt8]? = nil
    }

    enum CommentStart: Sendable {
        case anywhere
        /// Only after space or punctuation, as shell's `#` (so `a#b` and `$#` aren't comments).
        case wordStart
        /// Only first on its line, as INI's `;` and `#`.
        case lineStart
    }

    /// A word of up to 16 bytes packed into two integers, so looking one up allocates nothing.
    struct Key: Hashable, Sendable {
        let low: UInt64, high: UInt64

        init?(_ word: some Collection<UInt8>, folding: Bool = false) {
            guard word.count <= 16 else { return nil }
            var low: UInt64 = 0, high: UInt64 = 0
            for (index, raw) in word.enumerated() {
                let byte = folding && raw &- 0x41 < 26 ? raw | 0x20 : raw
                if index < 8 { low |= UInt64(byte) << (index * 8) } else { high |= UInt64(byte) << ((index - 8) * 8) }
            }
            self.low = low
            self.high = high
        }
    }

    var lineComments: [[UInt8]] = []
    var commentStart = CommentStart.anywhere
    var blockComment: (open: [UInt8], close: [UInt8])?
    var nestedComments = false
    var strings: [StringRule] = []
    /// Python's `f"…"`, `rb'…'`: up to two prefix letters belong to the string.
    var stringPrefixes = false
    var keywords: Set<Key> = []
    var constants: Set<Key> = []
    var types: Set<Key> = []
    /// SQL: keywords in any case.
    var caseInsensitive = false
    var guessesTypes = false
    var guessesFunctions = false
    /// CSS: `10px`, `50%` are numbers; `#fff` is a number.
    var numberUnits = false
    var hexColors = false
    /// Bytes that may appear in a word besides letters, digits and `_`, and bytes that may only start one (`@`, `#`).
    var wordBytes: [UInt8] = []
    var wordStartBytes: [UInt8] = []

    static func of(_ language: SyntaxLanguage) -> SyntaxRules {
        switch language {
        case .swift: swift
        case .python: python
        case .shell: shell
        case .json: json
        case .javascript: javascript
        case .c: c
        case .go: go
        case .rust: rust
        case .java: java
        case .kotlin: kotlin
        case .ruby: ruby
        case .perl: perl
        case .sql: sql
        case .css: css
        case .yaml: yaml
        case .toml: toml
        case .ini: ini
        }
    }

    // MARK: Helpers

    static func keys(_ words: String, folding: Bool = false) -> Set<Key> {
        Set(words.split(whereSeparator: \.isWhitespace).compactMap { Key($0.utf8, folding: folding) })
    }

    static func string(_ delimiter: String, escapes: Bool = true, multiline: Bool = false, interpolation: String? = nil) -> StringRule {
        StringRule(delimiter: Array(delimiter.utf8), escapes: escapes, multiline: multiline, interpolation: interpolation.map { Array($0.utf8) })
    }

    static func bytes(_ text: String) -> [UInt8] { Array(text.utf8) }

    static let cComments = (open: bytes("/*"), close: bytes("*/"))

    // MARK: Languages

    static let swift = SyntaxRules(
        lineComments: [bytes("//")], blockComment: cComments, nestedComments: true,
        strings: [string("\"\"\"", multiline: true, interpolation: "\\("), string("\"", interpolation: "\\(")],
        keywords: keys(
            """
            associatedtype actor async await break case catch class continue default defer deinit do else enum extension
            fallthrough fileprivate final for func guard if import in init inout internal is let lazy mutating
            nonisolated open operator override private protocol public repeat rethrows return self Self some static
            struct subscript super switch throw throws try typealias var weak where while any convenience dynamic
            indirect optional required unowned get set willSet didSet consuming borrowing sending isolated macro
            """),
        constants: keys("true false nil"),
        guessesTypes: true, guessesFunctions: true, wordStartBytes: bytes("@#"))

    static let python = SyntaxRules(
        lineComments: [bytes("#")],
        strings: [string("\"\"\"", multiline: true), string("'''", multiline: true), string("\""), string("'")],
        stringPrefixes: true,
        keywords: keys(
            """
            and as assert async await break class continue def del elif else except finally for from global if import in
            is lambda nonlocal not or pass raise return try while with yield match case self
            """),
        constants: keys("True False None"),
        guessesTypes: true, guessesFunctions: true)

    static let shell = SyntaxRules(
        lineComments: [bytes("#")], commentStart: .wordStart,
        // Single-quoted strings often hold whole awk or python programs, so they may run over lines.
        strings: [string("'", escapes: false, multiline: true), string("\"", multiline: true, interpolation: "$(")],
        keywords: keys(
            """
            if then else elif fi for while until do done case esac function in return local export select readonly
            declare unset shift exit begin end switch not and or set source
            """),
        constants: keys("true false"),
        wordBytes: bytes("-./$"))

    static let json = SyntaxRules(
        lineComments: [bytes("//")], blockComment: cComments,
        strings: [string("\"")],
        constants: keys("true false null"))

    /// JavaScript and TypeScript, with JSX and TSX: their markup stays plain, and so do regex literals.
    static let javascript = SyntaxRules(
        lineComments: [bytes("//")], blockComment: cComments,
        strings: [string("`", multiline: true, interpolation: "${"), string("\""), string("'")],
        keywords: keys(
            """
            break case catch class const continue debugger default delete do else export extends finally for function if
            import in instanceof let new return super switch this throw try typeof var void while with yield async await
            of static get set from as interface type enum implements private protected public readonly declare namespace
            abstract keyof satisfies
            """),
        constants: keys("true false null undefined NaN Infinity"),
        types: keys("string number boolean any unknown never object symbol bigint"),
        guessesTypes: true, guessesFunctions: true, wordBytes: bytes("$"))

    /// C, C++ and Objective-C, with preprocessor lines and `@` keywords.
    static let c = SyntaxRules(
        lineComments: [bytes("//")], blockComment: cComments,
        strings: [string("\""), string("'")],
        keywords: keys(
            """
            auto break case char const continue default do double else enum extern float for goto if inline int long
            register restrict return short signed sizeof static struct switch typedef union unsigned void volatile while
            bool class namespace template typename public private protected virtual override final new delete this throw
            try catch using constexpr noexcept explicit friend operator mutable decltype static_cast dynamic_cast
            reinterpret_cast const_cast self super id instancetype
            #include #define #if #ifdef #ifndef #else #elif #endif #pragma #import #undef #error
            @interface @implementation @end @property @protocol @class @selector @autoreleasepool @synthesize @optional
            @required @try @catch @finally @throw @import
            """),
        constants: keys("true false NULL nullptr nil Nil YES NO"),
        guessesTypes: true, guessesFunctions: true, wordStartBytes: bytes("#@"))

    static let go = SyntaxRules(
        lineComments: [bytes("//")], blockComment: cComments,
        strings: [string("\""), string("`", escapes: false, multiline: true), string("'")],
        keywords: keys(
            """
            break case chan const continue default defer else fallthrough for func go goto if import interface map
            package range return select struct switch type var
            """),
        constants: keys("true false nil iota"),
        types: keys(
            """
            bool byte complex64 complex128 error float32 float64 int int8 int16 int32 int64 rune string uint uint8
            uint16 uint32 uint64 uintptr any
            """),
        guessesTypes: true, guessesFunctions: true)

    /// Rust, without character literals: a `'` there is as often a lifetime.
    static let rust = SyntaxRules(
        lineComments: [bytes("//")], blockComment: cComments, nestedComments: true,
        strings: [string("\"", multiline: true)],
        keywords: keys(
            """
            as async await break const continue crate dyn else enum extern fn for if impl in let loop match mod move mut
            pub ref return self Self static struct super trait type unsafe use where while
            """),
        constants: keys("true false"),
        types: keys("i8 i16 i32 i64 i128 isize u8 u16 u32 u64 u128 usize f32 f64 bool char str"),
        guessesTypes: true, guessesFunctions: true)

    static let java = SyntaxRules(
        lineComments: [bytes("//")], blockComment: cComments,
        strings: [string("\"\"\"", multiline: true), string("\""), string("'")],
        keywords: keys(
            """
            abstract assert boolean break byte case catch char class const continue default do double else enum extends
            final finally float for goto if implements import instanceof int interface long native new package private
            protected public return short static strictfp super switch synchronized this throw throws transient try void
            volatile while var record yield sealed permits
            """),
        constants: keys("true false null"),
        guessesTypes: true, guessesFunctions: true)

    static let kotlin = SyntaxRules(
        lineComments: [bytes("//")], blockComment: cComments, nestedComments: true,
        strings: [string("\"\"\"", escapes: false, multiline: true, interpolation: "${"), string("\"", interpolation: "${"), string("'")],
        keywords: keys(
            """
            as break class continue do else for fun if in interface is object package return super this throw try
            typealias val var when while by catch constructor finally get import init set where abstract annotation
            companion const data enum external final infix inline inner internal lateinit open operator out override
            private protected public reified sealed suspend tailrec vararg
            """),
        constants: keys("true false null"),
        guessesTypes: true, guessesFunctions: true)

    /// Ruby, without heredocs, `%w` literals and regexes.
    static let ruby = SyntaxRules(
        lineComments: [bytes("#")],
        strings: [string("\"", interpolation: "#{"), string("'"), string("`")],
        keywords: keys(
            """
            alias and begin break case class def defined do else elsif end ensure for if in module next not or redo
            rescue retry return self super then undef unless until when while yield require require_relative
            """),
        constants: keys("true false nil"),
        guessesTypes: true, guessesFunctions: true)

    /// Perl, without regexes and heredocs. `$#array` isn't a comment.
    static let perl = SyntaxRules(
        lineComments: [bytes("#")], commentStart: .wordStart,
        strings: [string("\""), string("'")],
        keywords: keys(
            """
            my our local sub if elsif else unless while until for foreach do last next redo return use no package require
            eval die print and or not eq ne lt gt le ge cmp
            """),
        guessesFunctions: true)

    static let sql = SyntaxRules(
        lineComments: [bytes("--")], blockComment: cComments,
        strings: [string("'")],
        keywords: keys(
            """
            select from where insert into values update set delete create table drop alter add column index view join
            inner left right outer full cross on as and or not is in exists between like order by group having limit offset
            union all distinct case when then else end primary key foreign references default unique check constraint
            begin commit rollback transaction with returning if replace asc desc count sum avg min max
            """, folding: true),
        constants: keys("true false null", folding: true),
        types: keys(
            "int integer bigint smallint varchar char text boolean bool date time timestamp numeric decimal real float double serial blob",
            folding: true),
        caseInsensitive: true)

    /// CSS and SCSS: at-rules, `!important`, numbers with units and hex colors. Selectors and properties stay plain.
    static let css = SyntaxRules(
        lineComments: [bytes("//")], blockComment: cComments,
        strings: [string("\""), string("'")],
        keywords: keys(
            """
            @media @import @font-face @keyframes @supports @charset @namespace @page @layer @container @use @forward
            @mixin @include @extend @if @else @each @for @function @return @tailwind !important
            """),
        guessesFunctions: true, numberUnits: true, hexColors: true,
        wordBytes: bytes("-"), wordStartBytes: bytes("@!"))

    /// YAML, without block scalars (`|`, `>`). A `#` only starts a comment after a space.
    static let yaml = SyntaxRules(
        lineComments: [bytes("#")], commentStart: .wordStart,
        strings: [string("\""), string("'", escapes: false)],
        constants: keys("true false null yes no on off True False Null Yes No"))

    static let toml = SyntaxRules(
        lineComments: [bytes("#")],
        strings: [string("\"\"\"", multiline: true), string("'''", escapes: false, multiline: true), string("\""), string("'", escapes: false)],
        constants: keys("true false inf nan"))

    /// INI-style config (ini, conf, cfg, env, properties): comments only first on a line, since values may hold `;`.
    static let ini = SyntaxRules(
        lineComments: [bytes(";"), bytes("#")], commentStart: .lineStart,
        strings: [string("\""), string("'")],
        constants: keys("true false yes no on off"))
}
