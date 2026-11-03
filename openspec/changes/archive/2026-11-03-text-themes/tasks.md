# Tasks

## 1. Themes

- [x] 1.1 Write failing tests for `TextTheme`: eight themes in pop-up order with their groups and ids; `named` finds each id and nothing else; a theme's colors resolve to different light and dark values (System's to the system colors); setting `current` posts `didChange`. Then add `TextTheme` to PeekerKit with the palettes from the mock; verify the tests pass

## 2. Config and Settings

- [x] 2.1 Write failing tests: `textTheme` reads, renders and round-trips; a missing key is System; an unknown name or a non-string is a problem naming the eight and leaves System; the schema has an enum of the ids. Then add it to `Config`, its reader, rendering and schema; verify the tests pass
- [x] 2.2 Write failing tests: the app sets `TextTheme.current` from the config at launch and when the config changes; the General pane's model saves a picked theme. Then wire `AppDelegate` and add the pop-up to `GeneralPane`; verify the tests pass

## 3. Views

- [x] 3.1 Write failing tests: a text document's background, text color, cursor and selection follow the current theme, and change when the theme changes without losing text, edits or selection. Then update `TextDocument`; verify the tests pass
- [x] 3.2 Write failing tests: the Markdown Editor's background, body, heading, marker, link and code colors follow the theme and change with it, keeping unsaved typing; the Peek panel's rendered view takes the theme's background, heading and link colors and changes with it; the Markdown print text uses the system theme. Then update `MarkdownEditor`, `MarkdownDocument` and `MarkdownRenderer`; verify the tests pass
- [ ] 3.3 Write failing tests: find in a text and a Markdown document still finds and moves between matches, and match ranges get the theme's find color as temporary attributes. Then add the text finder; verify the tests and the existing find tests pass (or, if it can't work reliably, keep the system find bar and note it for the maintainer)

## 4. Docs

- [x] 4.1 Add `THIRD_PARTY_NOTICES.md` (Catppuccin and Tokyo Night MIT notices), README's config and Settings lines for `textTheme`, and Unreleased lines in `CHANGELOG.md`; verify `openspec validate --all --strict`

## 5. Screen tests

- [x] 5.1 Add steps to the flows: picking Paper in Settings writes `"textTheme": "paper"`; open Markdown and text windows recolor (screenshot comparison); the Peek panel shows the theme; an unknown name is reported and windows stay System; verify `bash -n`

## 6. Wrap-up

- [x] 6.1 Run `scripts/build.sh` and `scripts/build.sh test` twice; verify all tests pass with no new warnings
- [x] 6.2 Run `scripts/screen-test.sh`; verify every flow passes and look at the theme captures
- [ ] 6.3 Run `scripts/bench-ab.sh <base> --launches 15` against the commit before markdown-editor; verify Markdown and text opens don't regress

## Workflow follow-up

- Archive with `/opsx:archive` after `markdown-editor`.
