# Proposal

## Why

Code opens in Peeker as monochrome text. The text themes were built with highlighting as the next step (decided 2026-11-03), and the maintainer wants it for code files such as `.py` as well as for code in Markdown. An experiment the same day compared tree-sitter with a scanner of our own on the same four languages: the scanner added 44 KB to the app against 6.6 MB, colored 1 MB of code in 2–4 ms against 140–250 ms, and agreed with tree-sitter on 88% of characters, with most differences being choices rather than errors. The maintainer chose the scanner, kept in a module of its own so it can be fixed, optimized or removed in one place.

## What Changes

- A new module, `PeekerSyntax`, holds the whole feature's logic: language detection and a table-driven scanner that returns colored spans (keyword, string, comment, number, type, function). It depends only on Foundation; the text and Markdown plugins may import it.
- Plain Text colors code files up to 1 MB, chosen by extension or, for a file without one, by a `#!` first line. Languages: Python, JavaScript and TypeScript (including JSX/TSX, without their markup), Swift, C, C++ and Objective-C, Go, Rust, Java, Kotlin, Ruby, Perl, shell (sh, bash, zsh, fish), SQL, CSS and SCSS, JSON and JSONC, YAML, TOML, and INI-style config (ini, conf, cfg, env, properties). Text, logs, CSV/TSV, XML and diffs stay plain.
- Markdown colors fenced code blocks tagged with a known language, in the Editor's styled source and in the Peek panel.
- Syntax the table can't express cleanly is left uncolored rather than handled specially: heredocs, raw and nested string templates, regex literals, JSX tags, and the like.
- Each of the eight text themes gains six syntax colors per look (System follows Xcode's defaults; Catppuccin and Tokyo Night use their official syntax colors), as previewed and approved. Changing the theme recolors code at once.
- Coloring never holds up opening a file or typing: it runs off the main thread, colors the first screen first, and updates shortly after typing pauses.
- Printing keeps code colored, in the System theme's light colors, on white.
- No setting turns it off.

## Capabilities

### New Capabilities

- `syntax-highlighting`: which files and blocks get colored, how the language is chosen, what's colored, the size limit, staying off the open path, printing.

### Modified Capabilities

- `text-themes`: a theme also colors code; printing keeps code colors in System's light look.
- `text`: printing keeps code colors.
- `markdown`: printing keeps code colors in fenced blocks.

## Impact

- New `Sources/PeekerSyntax/` module and its target in `project.yml`; `scripts/check-plugin-imports.sh` lets the text and Markdown plugins import it; AGENTS.md names it.
- `Sources/PeekerKit/TextTheme.swift`: six syntax colors per theme.
- `Plugins/text/TextDocument.swift` and `TextPlugin.swift`; `Plugins/markdown/MarkdownStyler.swift`, `MarkdownEditor.swift`, `MarkdownRenderer.swift`.
- Tests, a screen flow step, a code file in the benchmark fixtures, README, CHANGELOG, and the version goes to `0.6.0-dev`.
