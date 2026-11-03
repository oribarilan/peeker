# Tasks

## 1. The module

- [x] 1.1 Add the `PeekerSyntax` static framework target (Foundation only) to `project.yml`, depended on by `PeekerText`, `PeekerMarkdown` and the tests; let `scripts/check-plugin-imports.sh` allow it for `text` and `markdown`; name it in AGENTS.md's architecture rules and code layout; verify `scripts/build.sh test` passes with an empty module
- [x] 1.2 Write failing tests for `SyntaxLanguage`: every listed extension maps to its language and text, log, csv, tsv, xml and diff map to none; `#!` lines for python, bash, sh, zsh, fish, ruby, perl, node; fence tags (`python`, `py`, `js`, `ts`, `sh`, `bash`, `json`, `yaml`, `c++`, `objc` and so on). Then add it; verify the tests pass
- [x] 1.3 Write failing tests for the scanner on the prototype's languages (Swift, Python, shell, JSON): comments, strings with escapes, triple quotes, numbers, keywords, constants (`true`, `nil`, ALL_CAPS), types, functions, non-ASCII offsets, `#` inside a shell word, and spans in order without overlap. Then bring the prototype scanner into the module with ALL_CAPS as constants and Swift interpolation quotes kept inside the string; verify the tests pass
- [x] 1.4 Write failing tests for the remaining languages, one example each covering their comment style, strings and a keyword: JavaScript/TypeScript, C/C++/Objective-C, Go, Rust, Java, Kotlin, Ruby, Perl, SQL (case-insensitive keywords, `--` comments), CSS/SCSS, JSONC, YAML, TOML, INI; plus dropped syntax staying plain (a heredoc, a regex literal, a JSX tag). Then add their tables; verify the tests pass and time a 1 MB file per language family under 10 ms

## 2. Theme colors

- [x] 2.1 Write failing tests: every theme has six syntax colors that resolve to the approved light and dark values (System's keyword `9B2393` light and `FC5FA3` dark; Catppuccin's mauve and green; Tokyo Night's). Then add `SyntaxColors` to `TextTheme` with the palettes from the preview; verify the tests pass

## 3. Plain Text

- [x] 3.1 Write failing tests: a `.py` file opens with keyword and string temporary colors from the theme; a file without an extension and a bash `#!` is colored; a `.log` and a 1 MB-plus file aren't; a large file has its first screen colored at once and the rest on the next turn; typing a keyword colors it after the pause and a newer edit drops an older scan; a theme change recolors; the text, undo and edited state are untouched; find's marks still show. Then wire `TextPlugin` and `TextDocument`; verify the tests pass
- [x] 3.2 Write failing tests: printing a code file prints code in System's light syntax colors over black, whatever the theme. Then update its print job; verify the tests pass

## 4. Markdown

- [x] 4.1 Write failing tests: a ```` ```python ```` block gets `.syntax` runs inside it, an untagged or unknown block doesn't; the Editor shows them in the theme's colors over the code background and a theme change recolors; the Peek panel renders the block's code colored; printing uses System's light colors. Then update `MarkdownStyler`, `MarkdownEditor` and `MarkdownRenderer`; verify the tests pass

## 5. Docs, benchmark and version

- [x] 5.1 Add a code fixture (about 100 KB of Swift or Python) to the benchmark's fixtures so the A/B gate times opening code; README's text section notes the coloring; CHANGELOG Unreleased line; bump `MARKETING_VERSION` to `0.6.0-dev` in the commit after this change; verify `openspec validate --all --strict`

## 6. Screen tests

- [x] 6.1 Add a step to the theme flow: open a `.py` file and check the pixel color of `def` matches the current theme's keyword color, then that it changes with the theme; verify `bash -n`

## 7. Wrap-up

- [x] 7.1 Run `scripts/build.sh` and `scripts/build.sh test` twice; verify all tests pass with no warnings
- [x] 7.2 Run `scripts/screen-test.sh` (with the maintainer's go) and `scripts/bench-ab.sh HEAD~N` against the commit before this change; verify every flow passes and opening text and Markdown doesn't regress. Every flow passed except three Option-Space steps in `flows`, whose shortcut another app held system-wide. The A/B run caught a 100 KB Swift file opening 25–55 ms slower; coloring the rest after the first draw brought it back within the gate (window 35.7 ms against 33.2, panel 30.0 against 26.1)
