# Design

## Context

Page tools (rotate, delete, reorder) are `PDFEdit` cases applied live to the shown `PDFDocument`, kept pending with inverses for Undo, folded into the recovery copy, and written by `PDFPlugin.write` from the file plus the edits. Deleted pages sit in a `PageStash` so Undo can put them back. The thumbnails (`PageThumbnails`, PDFKit's `PDFThumbnailView`) handle internal drags; on macOS 26 a drag can't reorder (needs 27). Save As exists (`saveAs(_:to:)`).

## Decisions

**Insert is a page edit that carries its source.** `PDFEdit.insertPages(at: Int, source: InsertedSource, token:)`, where the source is the inserted file's bytes when they're small (under 20 MB) or its path otherwise, with the page range. Applying it opens the source (a PDF, or an image drawn on a page the image's size at 72 dpi, at most 14400 points a side) and inserts copies of its pages. Undo removes them into the stash, like delete. Recovery holds the bytes or the path; a path that's gone fails the restore with the file's name. `PDFPlugin.write` replays it like the other edits, so Save As and Cmd+S both work.

**Where pages go.** After the last selected thumbnail, or at the end with none selected; a drop goes where the drop bar shows. Finder drops of several files insert them in the order dragged.

**Save Selected Pages As… writes a new file without moving the window.** It builds a `PDFDocument` from copies of the selected pages as shown (pending edits included), and writes it through `FileReplacement` to the path from a save sheet named "<name> pages.pdf".

**Split writes next to the original.** A sheet offers "Every page" or "At the selected pages" (greyed with fewer than one selected after page 1). Files are written in the original's folder as "<name> 1.pdf", "<name> 2.pdf", …, skipping numbers whose names exist. Unsaved edits are included. The window stays on its file.

**File menu tools.** `ToolSpec.menu` is `.view`, `.tools` (the defaults by `isEditTool`) or `.file`; the host lists File tools after Save As…, with their edit-tool greying.

## Risks / Trade-offs

- [Large inserted files in the recovery copy] → paths above 20 MB; the restore says when the file is gone.
- [Drops on macOS 26, where internal drags can't reorder] → external file drops go through the collection view's own drop delegate, which works there; checked on screen.
