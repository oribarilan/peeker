# Design

## Context

PDF edits are a list of `PDFEdit`s, applied to the view at once and again, in order, to a fresh copy of the file on save. Every mark edit names its page by index. Undo runs each edit's inverse, computed when the edit was made. `PDFEdit.folded` shortens the list for saving and recovery by rewriting or dropping mark and field edits. It never moves an edit past another one.

Facts checked with probes on macOS 27:
- `PDFThumbnailView` offers multiple selection (`selectedPages`) and drag reordering (`allowsDragging`), both off by default.
- A drop inserts a copy of each dragged page through the document's public `insert(_:at:)`, then removes the originals. A `PDFDocument` subclass sees those calls. The thumbnail view gives no other signal.
- In the thumbnail view, the Delete key arrives as `deleteBackward(_:)` and a right-click as `rightMouseDown(with:)`. A `PDFThumbnailView` subclass gets both.
- `PDFDocument.allowsDocumentAssembly` is the page-change permission, separate from commenting and form filling.
- When PDFKit writes a page whose index changed (moved, or a page removed or inserted before it), it writes that page's annotations from scratch. They lose `/NM`, `/DS` and Apple's private keys. Form fields keep their names and values, and a page that kept its index keeps every key.
- `exchangePage(at:withPageAt:)` crashes on a page that was removed and inserted again; removing and inserting doesn't.

## Goals / Non-Goals

**Goals:**
- Rotate, delete and reorder pages as ordinary edits, with undo across saves and recovery.
- Keep the native thumbnail view.
- Leave mark and field edits as they are.

**Non-Goals:**
- Inserting, extracting or blank pages. Dragging pages to or from other apps.
- A right-click menu in the read view: it shows only in Edit mode, where the commands can run without switching modes. The menu bar and shortcuts still switch modes.

## Decisions

**Page indices mean "at the time of the edit", and edits replay in order.** New cases:
- `.rotatePages(pages:by:)`, where `by` is ±90.
- `.reorderPages(order:)`: the new order, as indices of the pages before it.
- `.deletePages(pages:token:)` and `.restorePages(pages:token:data:)`.

Every edit's indices refer to the document as it was just before that edit. Replaying the list in order gives the same result live, on save and on recovery. Inverses stay valid because undo is last-in first-out: when an edit is undone, the document is back to the state right after it. Folding stays correct because it never reorders edits. Considered instead: naming pages by their index in the file on disk and keeping a separate page layout. That needs every mark edit and every inverse remapped after each save.

**Deleted pages come back from memory, or from a copy after a save.** `.deletePages` keeps the removed page objects in a stash under its token, and its inverse `.restorePages` puts them back. The live document has one stash, and each save run has its own, so a delete followed by its undo in one list restores the exact pages: links, fields and all. When the delete was already saved, the save's stash lacks the token, so the restore falls back to `data`: the deleted pages as a small PDF, made from copies of the pages when they're deleted. Recovery uses the same fallback. Coming from a file, `data` is checked when applied: it must open as a PDF with exactly as many pages as the edit restores. Copying a page drops its annotations' `/NM` and `/DS` too, so the copy goes through the same repair as a save that moves pages. The cost is one or two PDF encodes per delete, proportional to the pages deleted.

**Applying page edits.** `PDFMarks.apply` gains the page cases and takes the stash.
- Rotation is the page's `rotation`, normalized to 0, 90, 180 or 270.
- A reorder must be a permutation of the current page indices. It moves each page that's out of place by removing and inserting it, never by `exchangePage`.
- A delete must leave at least one page.
- Page indices must be unique and in range.

Anything else throws, as invalid mark edits already do.
- A stashed restore takes its pages out of the stash, so the same page objects can't go in twice.

**Recovery stops at a skipped page move.** A recovered list replays as before, skipping an edit that no longer fits the file. But once a reorder, delete or restore is skipped, every later page index would point at the wrong page, so the replay stops there.

**Saving moved pages writes twice.** When the saved edits move pages, the save notes each annotation's `/NM` and `/DS` (by page, type and bounds) before writing. It then reads the written data back, puts those keys back where they went missing, and writes again. Without this, Peeker's marks on moved pages would turn into other apps' annotations after a save, and text boxes would lose their size. Other apps' names come back the same way. Apple's private keys don't, which only matters to Preview's own markup editing.

**Catching a thumbnail drag.** The live document is a `PDFDocument` subclass that reports `insert`, `removePage` and `exchangePage` calls it didn't make itself. A flag marks Peeker's own changes. On the first such call it waits for the run loop turn to end, so the drop has finished, then compares the pages with those before:
- A page object seen before keeps its old index.
- A new object (PDFKit's copy) is paired with the before-page that disappeared and shares its underlying `pageRef`. A copy without a match is paired in order with the rest.
- If the counts don't match (a drop from outside, say), the old pages are put back and the drag is refused with a beep.
- Otherwise the copies are swapped for the original page objects in their new places, so annotations and later edits keep working on the same objects. The move is recorded as one `.reorderPages` with its inverse permutation.

Dragging is on only in Edit mode, and only when the file allows page changes.

**Thumbnails.** A `PDFThumbnailView` subclass turns on multiple selection. In Edit mode it turns on dragging, sends Delete to Delete Page, and shows the right-click menu. The document keeps the latest thumbnail view it made for the sidebar, to read the selection. No selection means the current page.

**Contract: `unavailableReason(for:)`.** `PluginDocument` gains `func unavailableReason(for command: String) -> String?`, nil by default. The host checks it in the menu check for `runCommand(_:)` and in a new toolbar-item check, which also sets the item's tooltip. Because the menu check runs on every key press, a shortcut for an unavailable command does nothing. The PDF document gives the permission reason for all three page commands. For Delete Page it also gives the at-least-one-page reason when the selection covers every page.

**Other parts touched.**
- Before a page edit, the edit tools end any selection or typing in progress, since a selected mark's page index may change.
- After a page edit, the view lays itself out again.
- A search in progress is cancelled first, since PDFKit's search reads pages on another thread. Afterwards the last search runs again without selecting a match or moving the view, so a page command never lands on a match's page.

## Risks / Trade-offs

- **The second write** doubles the save time of a save that moves pages. A save that only rotates pages, or touches no pages, writes once as before.

- **PDFKit's drop behavior is undocumented.** The probe shows copy-then-remove through public methods. If a future macOS moves pages another way, the comparison still sees the new order. If it can't make sense of it, the drag is refused. The tests repeat what the probe saw (copy in, original out) on the document directly. Driving PDFKit's own drop isn't possible headless, because the drop removes the originals only during a real drag session. So the real-app check drags single and multiple pages by hand.
- **Restoring from `data` after a save** may lose links from other pages to the restored page, and its form fields' connection to the form. This happens only when undoing a deletion that was already saved.
- **Recovery copies grow** by the deleted pages' size while an undone deletion is pending.
