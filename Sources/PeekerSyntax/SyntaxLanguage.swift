import Foundation

/// A language the scanner knows. Several close languages share one: C, C++ and Objective-C are `.c`; JavaScript,
/// TypeScript, JSX and TSX are `.javascript`; the shells are `.shell`; JSON with comments is `.json`.
public enum SyntaxLanguage: String, Sendable, CaseIterable {
    case python, javascript, swift, c, go, rust, java, kotlin, ruby, perl, shell, sql, css, json, yaml, toml, ini

    /// The language of a file with this extension (any case); nil for text, logs, data and markup.
    public init?(fileExtension: String) {
        guard let language = Self.extensions[fileExtension.lowercased()] else { return nil }
        self = language
    }

    /// The language a `#!` first line names, as `#!/bin/bash` or `#!/usr/bin/env -S python3 -u`; nil otherwise.
    public init?(hashBang line: String) {
        guard line.hasPrefix("#!") else { return nil }
        var words = line.dropFirst(2).split(separator: " ").map(String.init)
        guard let program = words.first?.split(separator: "/").last.map(String.init) else { return nil }
        var name = program
        if program == "env" {
            words.removeFirst()
            guard let named = words.first(where: { !$0.hasPrefix("-") }) else { return nil }
            name = named
        }
        guard let language = Self.interpreters[name.trimmingCharacters(in: CharacterSet.decimalDigits.union(["."]))] else {
            return nil
        }
        self = language
    }

    /// The language a Markdown fence names in its first word, as ```` ```python ```` or ```` ```c++ {.numbered} ````.
    public init?(fenceTag: String) {
        guard let word = fenceTag.split(separator: " ").first.map({ $0.lowercased() }),
              let language = Self.fenceTags[word] ?? Self.extensions[word] else { return nil }
        self = language
    }

    private static let extensions: [String: SyntaxLanguage] = [
        "py": .python, "js": .javascript, "mjs": .javascript, "cjs": .javascript, "ts": .javascript, "tsx": .javascript,
        "jsx": .javascript, "swift": .swift, "c": .c, "h": .c, "m": .c, "mm": .c, "cc": .c, "cpp": .c, "hpp": .c,
        "go": .go, "rs": .rust, "java": .java, "kt": .kotlin, "rb": .ruby, "pl": .perl,
        "sh": .shell, "bash": .shell, "zsh": .shell, "fish": .shell, "sql": .sql, "css": .css, "scss": .css,
        "json": .json, "jsonc": .json, "yaml": .yaml, "yml": .yaml, "toml": .toml,
        "ini": .ini, "conf": .ini, "cfg": .ini, "env": .ini, "properties": .ini,
    ]

    private static let interpreters: [String: SyntaxLanguage] = [
        "python": .python, "bash": .shell, "sh": .shell, "zsh": .shell, "fish": .shell, "ksh": .shell, "dash": .shell,
        "ruby": .ruby, "perl": .perl, "node": .javascript, "deno": .javascript, "bun": .javascript, "swift": .swift,
    ]

    private static let fenceTags: [String: SyntaxLanguage] = [
        "python": .python, "python3": .python, "javascript": .javascript, "typescript": .javascript, "node": .javascript,
        "shell": .shell, "objc": .c, "objective-c": .c, "c++": .c, "cxx": .c, "golang": .go, "rust": .rust,
        "kotlin": .kotlin, "ruby": .ruby, "perl": .perl, "dotenv": .ini,
    ]
}
