# Tasks

## 1. Contract and plugins

- [x] 1.1 Add `saveAs(_:to:)` to `PluginDocument` with a default that refuses.
- [x] 1.2 Text: failing tests (with edits the destination gets them and the original doesn't; without edits a byte copy, also for a partly shown file; later saves go to the destination; Undo still works), then `TextDocument.saveAs`.
- [x] 1.3 Markdown: the same for `MarkdownEditor`.
- [x] 1.4 PDF: failing tests (marks and page edits in the copy, original untouched, a signed PDF copied byte for byte, later saves to the copy), then `PDFPlugin.write(_:from:to:)` and `PDFPluginDocument.saveAs`.
- [x] 1.5 Image: failing tests (a crop in the copy with the original's metadata, original untouched, later saves and page changes read the copy), then `ImageSaving` with source and destination and `ImageDocument.saveAs`.

## 2. Host

- [x] 2.1 Failing tests: `DocumentViewController.saveAs(to:)` writes, then follows the new file (URL, recovery record, a change on disk to the new file reloads, the old file's changes don't); a failure leaves it on the original with its edits; a destination open in another window is refused.
- [x] 2.2 Implement it, and `DocumentWindowController`'s Save As… sheet (name, folder, type), title, proxy icon, history entry, Open Recent and Open With; File > Save As… (Shift+Cmd+S), greyed without an Editor document.

## 3. Checks and docs

- [x] 3.1 Run `scripts/build.sh test`; no new warnings.
- [ ] 3.2 Screen step: Save As… on a text file through the sheet, then type and Cmd+S; check both files on disk and the window title.
- [x] 3.3 CHANGELOG line; `openspec validate --all --strict`.

## Workflow follow-up

- Commit the change, then bump the minor version in its own commit; archive.
