# Tasks

## 1. Host

- [x] 1.1 Add `PluginDocument.unavailableReason(for:)` (nil by default); in `DocumentWindowController`, grey out `runCommand(_:)` menu items and toolbar items for commands with a reason and set the toolbar item's tooltip to it; verify with tests using a stub document: the menu item and toolbar item are disabled with the tooltip while a reason is set, and enabled again when it clears

## 2. Page edits

- [x] 2.1 Add `.rotatePages`, `.reorderPages`, `.deletePages` and `.restorePages` to `PDFEdit` (Codable, folding leaves them in place) and apply them in `PDFMarks.apply` with a page stash and the validation in the design; verify with tests on generated PDFs: rotation normalizes, a reorder moves pages and refuses a non-permutation, a delete refuses removing every page and bad indices, a restore puts back the stashed objects, falls back to `data` without a stash, and refuses `data` with the wrong page count
- [x] 2.2 In `PDFPluginDocument`, compute inverses (rotate back, inverse permutation, restore with the deleted pages' data), give the live document a stash, end the tools' selection before and relayout after page edits, rerun an open search; verify with tests: each command applies, is pending and undoes and redoes; a mark added on a page then moved with it saves on the right page; delete, save, undo, save puts the page back in the file; recovery reapplies rotate, reorder and delete

## 3. Commands and thumbnails

- [x] 3.1 Add Rotate Left (cmd+l), Rotate Right (cmd+r) and Delete Page as edit tools; they act on the selected thumbnails or the current page; `unavailableReason` gives the permission reason when the PDF forbids page changes and the at-least-one-page reason for Delete Page when every page is selected; verify with tests: rotating the selection versus the current page, the reasons for an assembly-restricted PDF (made with PDFKit's access permissions) and for a full selection, and that such a PDF still turns Edit mode on
- [x] 3.2 Add the thumbnail view subclass: multiple selection; in Edit mode dragging (only when page changes are allowed), Delete key to Delete Page (beep when refused) and the right-click menu; verify with tests: dragging follows Edit mode and permission, `deleteBackward` deletes the selection in Edit mode and does nothing in the read view
- [x] 3.3 Add the document subclass that reports page changes Peeker didn't make, settle them after the run loop turn into one `.reorderPages` on the original page objects, and refuse what it can't pair; verify with tests: a drop driven through the thumbnail view's collection view delegate becomes one pending reorder with the original objects and one undo step, and a foreign insert is put back

## 4. Wrap-up

- [x] 4.1 Update the README's PDF line, `openspec/config.yaml`'s roadmap (page operations under way) and `openspec/gaps.md` if it lists page operations; verify `openspec validate --all --strict` passes
- [x] 4.2 Run `scripts/build.sh test` and `scripts/check-plugin-imports.sh`; verify all tests pass with no warnings
- [x] 4.3 In the built app (needs the maintainer's hands-off go): rotate, delete and drag pages, save, and check the file in Preview; verify by screenshots

## Workflow follow-up

- Archive after settings-window, pdf-fill-and-sign and find-and-print, which change the same specs.
- `scripts/bench-ab.sh main` with the maintainer's go, to confirm opening a PDF is unchanged.
