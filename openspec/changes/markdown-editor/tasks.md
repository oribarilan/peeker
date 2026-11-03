# Tasks

## 1. Shared text file code

- [x] 1.1 Move `TextCodec`, `TextFormat`, `LineEnding`, `TextLimits`, `TextEdits`, the Save as UTF-8 offer and `TextPlugin`'s load and write steps into PeekerKit as a public `TextFile` API, with Plain Text calling it and keeping its info rows; move the codec tests with it; verify `scripts/build.sh` has no warnings and `scripts/build.sh test` passes, including the plugin import check, with no change to Plain Text's behavior or messages

## 2. Styling

- [x] 2.1 Write failing tests for `MarkdownStyler`: runs for heading levels, strong, emphasis, strikethrough, inline code, a fenced block, a link, a quote, list markers and task boxes; marker ranges for `#`, `**`, list markers, fences and link brackets; correct UTF-16 ranges with non-ASCII text and CRLF line endings; the outline, word and task counts, task-box and link ranges. Then implement it; verify the tests pass

## 3. The Markdown Editor

- [x] 3.1 Write failing tests: opening with editing allowed gives an editable document showing the exact source, and the Peek panel's open gives the rendered view; typing marks it edited; saving writes the expected bytes; a save with unchanged text writes nothing; a Windows-1252 file round-trips with its line endings; an emoji in a Mac Roman file offers Save as UTF-8; restore applies recovered text and `recoveryText` reads it; reload is ignored while there are unsaved edits. Then implement `MarkdownEditor` on `TextFile`; verify the tests pass
- [x] 3.2 Write failing tests: after an edit and the restyle pause, a new `## ` line has the heading font; a restyle started before newer typing is dropped; zoom scales body and headings together; a 3 MB file opens unstyled and editable; a 12 MB file is `.readOnly` with the 10 MB reason and refuses typing. Then implement styling, zoom and the limits; verify the tests pass
- [x] 3.3 Write failing tests: a click on `[ ]` makes it `[x]`, marks the document edited and undoes in one step; the same click in a read-only file changes nothing; a Cmd-click on a link asks the open rule and a plain click doesn't open; a plain click on a link places the cursor. Then implement `MarkdownTextView` and the shared link-opening helper; verify the tests pass
- [x] 3.4 Write failing tests: the outline and Words and Tasks info update after typing a heading and a task; an outline click puts the cursor at the start of the heading's line; the print job renders the current text, unsaved edits included, without `#`. Then implement them; verify the tests pass

## 4. The Peek panel view

- [x] 4.1 Write failing tests: the rendered view decodes a Windows-1252 file through `TextFile`; it has no clickable task boxes and no longer writes the file. Then change the rendered view and `MarkdownRenderer`, and remove `toggleTask`; verify the tests and the existing Markdown suites pass

## 5. Docs

- [x] 5.1 Update README's plugin list (Markdown edits as styled source; the panel renders) and add Unreleased lines to `CHANGELOG.md`, including that ticking a task is now an edit saved with Cmd+S; verify `openspec validate --all --strict`

## 6. Screen tests

- [x] 6.1 Add `textframe` and `selection` to `drive.swift`; add `markdown-edit-flow.sh` with the type-and-save, Peek-panel-rendered, task-click and outline-jump checks; list it in `scripts/screen-test.sh` and describe it in the run-peeker skill; verify `bash -n` on the scripts and that the driver builds

## 7. Wrap-up

- [x] 7.1 Run `scripts/build.sh` and `scripts/build.sh test` twice; verify all tests pass with no new warnings
- [ ] 7.2 With the maintainer's go, run `scripts/screen-test.sh`; verify every flow passes and look at the Markdown Editor and Peek panel captures
- [ ] 7.3 With the maintainer's go, run `scripts/bench-ab.sh <base> --launches 15` against the commit before this change; verify Markdown window opens and the Peek panel's Markdown times don't regress

## Workflow follow-up

- Archive with `/opsx:archive`, then update the `markdown` spec's Purpose (it still describes a rendered view with tasks ticked straight into the file) and run `openspec validate --all --strict`.
