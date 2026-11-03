import PeekerSyntax
import Testing

@Suite struct SyntaxLanguages {
    @Test func everyCodeExtensionPlainTextOpensHasALanguage() {
        let expected: [String: SyntaxLanguage] = [
            "py": .python, "js": .javascript, "mjs": .javascript, "cjs": .javascript, "ts": .javascript, "tsx": .javascript,
            "jsx": .javascript, "swift": .swift, "c": .c, "h": .c, "m": .c, "mm": .c, "cc": .c, "cpp": .c, "hpp": .c,
            "go": .go, "rs": .rust, "java": .java, "kt": .kotlin, "rb": .ruby, "pl": .perl,
            "sh": .shell, "bash": .shell, "zsh": .shell, "fish": .shell, "sql": .sql, "css": .css, "scss": .css,
            "json": .json, "jsonc": .json, "yaml": .yaml, "yml": .yaml, "toml": .toml,
            "ini": .ini, "conf": .ini, "cfg": .ini, "env": .ini, "properties": .ini,
        ]
        for (ext, language) in expected { #expect(SyntaxLanguage(fileExtension: ext) == language, "\(ext)") }
        #expect(SyntaxLanguage(fileExtension: "PY") == .python, "case doesn't matter")
        for plain in ["txt", "text", "log", "csv", "tsv", "xml", "diff", "patch", "md", ""] {
            #expect(SyntaxLanguage(fileExtension: plain) == nil, "\(plain)")
        }
    }

    @Test func aHashBangLineNamesTheInterpreter() {
        let expected: [String: SyntaxLanguage] = [
            "#!/usr/bin/env python3": .python, "#!/usr/bin/python": .python, "#!/bin/bash": .shell, "#!/bin/sh": .shell,
            "#!/usr/bin/env zsh": .shell, "#!/usr/bin/env fish": .shell, "#!/usr/bin/env ruby": .ruby, "#!/usr/bin/perl -w": .perl,
            "#!/usr/bin/env node": .javascript, "#!/usr/bin/env -S python3 -u": .python, "#!/usr/bin/swift": .swift,
        ]
        for (line, language) in expected { #expect(SyntaxLanguage(hashBang: line) == language, "\(line)") }
        for other in ["# a heading", "#!/usr/bin/env awk", "plain text", ""] { #expect(SyntaxLanguage(hashBang: other) == nil, "\(other)") }
    }

    @Test func aMarkdownFenceTagNamesALanguage() {
        let expected: [String: SyntaxLanguage] = [
            "python": .python, "py": .python, "js": .javascript, "javascript": .javascript, "ts": .javascript,
            "typescript": .javascript, "tsx": .javascript, "swift": .swift, "sh": .shell, "bash": .shell, "zsh": .shell,
            "shell": .shell, "json": .json, "jsonc": .json, "yaml": .yaml, "yml": .yaml, "toml": .toml, "c": .c,
            "c++": .c, "cpp": .c, "objc": .c, "objective-c": .c, "go": .go, "rust": .rust, "rs": .rust, "java": .java,
            "kotlin": .kotlin, "ruby": .ruby, "rb": .ruby, "perl": .perl, "sql": .sql, "css": .css, "scss": .css, "ini": .ini,
        ]
        for (tag, language) in expected { #expect(SyntaxLanguage(fenceTag: tag) == language, "\(tag)") }
        #expect(SyntaxLanguage(fenceTag: "Python") == .python)
        #expect(SyntaxLanguage(fenceTag: "python {linenos}") == .python, "only the first word counts")
        for other in ["", "text", "mermaid", "diff", "html"] { #expect(SyntaxLanguage(fenceTag: other) == nil, "\(other)") }
    }
}
