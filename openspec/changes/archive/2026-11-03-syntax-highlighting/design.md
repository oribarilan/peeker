# Design

## Context

See proposal.md for why. Plain Text shows code in an `NSTextView` on TextKit 1 (`TextDocument`), loading the file off the main thread in `TextPlugin`. The Markdown Editor styles source by applying `StyleRun`s from `MarkdownStyler` to its text storage, with code blocks in the monospaced font on the theme's code background; the Peek panel's `MarkdownRenderer` renders `.code(text:language:)` blocks. Colors come from `TextTheme` (PeekerKit), which views observe. Plugins may import only PeekerKit, Apple frameworks and declared modules (`scripts/check-plugin-imports.sh`). The 2026-11-03 experiment left a working scanner prototype (about 290 lines for four languages) in a worktree.

## Goals / Non-Goals

**Goals:**
- One module that holds all of the feature's logic, so it can be fixed, optimized or removed without touching the rest.
- No slower opening or typing for any text or Markdown file.
- The approved six colors in all eight themes.

**Non-Goals:**
- Full-accuracy parsing, or languages beyond the list; markup (XML, HTML, JSX tags) and diffs.
- Highlighting files over 1 MB, or only the visible part of larger ones.
- A setting to turn it off.

## Decisions

### `PeekerSyntax`: a separate module with no dependencies

`Sources/PeekerSyntax/` is a static framework that imports only Foundation. Its public surface is small:

- `SyntaxLanguage`: the known languages, found from a file extension, a `#!` first line, or a Markdown fence tag.
- `SyntaxRole`: keyword, string, comment, number, type, function.
- `SyntaxSpan`: a UTF-16 range and a role.
- `SyntaxScanner.spans(in:language:)`: spans in text order, never overlapping.
- `SyntaxScanner.maxBytes`: 1 MB, the size above which callers leave text plain.

Inside, `SyntaxRules` describes a language as data: line and block comment markers (nesting optional), string delimiters (escapes, multi-line, prefixes such as Python's `f`), a keyword set, which words count as constants, and two switches, "capitalized words are types" and "a word before `(` is a function". The scanner makes one pass over the UTF-8 bytes and converts offsets to UTF-16 as it goes, starting from the prototype. Languages share rules where they can: one C-family table covers C, C++ and Objective-C, one covers JavaScript and TypeScript, and one covers the shells. Each language is a table entry, so dropping or fixing one touches one place.

The plugins depend on it as a target, and the import check allows `PeekerSyntax` for `text` and `markdown`. The host doesn't use it. Removing the feature means deleting the module, its target, and the call sites in the two plugins.

Alternative: put it in PeekerKit. Rejected: the maintainer asked for it to stand alone, and PeekerKit is the plugin contract, not a home for features.

### Theme colors stay in PeekerKit

`TextTheme` gains `syntax: SyntaxColors`, six dynamic colors per theme built from the approved light and dark palettes. PeekerKit doesn't import `PeekerSyntax`. Each plugin maps a role to a color with a six-case switch in a small file of its own, so two copies exist, one per plugin. That keeps the theme free of the feature, and removing the feature leaves an unused color set.

### Plain Text: temporary attributes, first screen first

`TextPlugin.load`, already off the main thread, picks the language and scans when the file is at most 1 MB; the spans travel with the loaded file. `TextDocument` applies them as `NSLayoutManager` temporary foreground colors, which never touch the text storage, undo or the edited state. It colors the first 20,000 UTF-16 units before the window shows and the rest 50 ms later, past the window's first draw, adding only the spans not yet colored: applying a 1 MB file's spans takes about 35 ms, and a first try that colored the rest on the next turn of the run loop doubled the time to show a 100 KB Swift file. After an edit, a rescan runs off the main thread 200 ms after typing pauses and is dropped if the text changed again. A theme change re-applies the colors from the spans it holds. Find's match highlights use the background color, so the two don't clash.

### Markdown: spans inside fences

`MarkdownStyler` gives a fenced code block with a known tag the scanner's spans, shifted to the block's content, as `StyleRun` kind `.syntax(SyntaxRole)`. The Editor applies them after the code font and background, so they only change the foreground. They follow the existing quick-parse and first-screen passes unchanged. `MarkdownRenderer` colors a `.code` block's text in the Peek panel the same way.

### Printing in System's light colors

Text printing builds its attributed string with the spans in `TextTheme.system`'s syntax colors, resolved light, over black text. Markdown already prints through the renderer with `.system`, so its code blocks follow.

### Checks

Unit tests per language cover comments, strings and escapes, numbers, keywords, constants, types and functions, plus non-ASCII offsets and the dropped syntax staying plain. The screen flow checks a Python keyword's pixel color in a window. The benchmark gets a code fixture, so the A/B gate sees the coloring cost on open.

## Risks / Trade-offs

- [A quote inside an interpolation or `$(…)` can flip the rest of a line] → Strings stop at the end of a line except where a language has multi-line strings, which limits how far a mistake spreads; fix cases as they show up.
- [Applying spans to a large file costs main-thread time after the window shows] → About 35 ms for 1 MB, split from the first screen; files over 1 MB stay plain.
- [Guessing types from capitalization colors ALL_CAPS constants as types] → An all-caps word counts as a constant.
