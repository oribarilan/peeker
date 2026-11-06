# Design

## Context

Page tools (rotate, delete, reorder) are `PDFEdit` cases applied live to the shown `PDFDocument`, kept pending with inverses for Undo, folded into the recovery copy, and written by `PDFPlugin.write` from the file plus the edits. Deleted pages sit in a `PageStash` so Undo can put them back. The thumbnails (`PageThumbnails`, PDFKit's `PDFThumbnailView`) handle internal drags; on macOS 26 a drag can't reorder (needs 27). Save As exists (`saveAs(_:to:)`).

## Decisions

**Insert reuses the restore edit.** Undo of a delete already puts pages back from a PDF copy: `.restorePages(pages:token:data:)`. Inserting builds that copy from the chosen files (each PDF's pages, each image as a page of its size through `PDFPage(image:)`) and applies a restore at the insertion point, so Undo (a delete into the stash), Redo, saving, Save As and recovery all work as they do for deleted pages. The recovery copy holds the inserted pages' data, up to the restore's existing 256 MB limit. Considered keeping the source file's path instead: smaller, but a moved file would lose the pages.

**Where pages go.** After the last selected thumbnail, or after the page shown. Files dropped from Finder onto the pages go there too, in the order dragged. Drops onto the thumbnails wait: PDFKit's collection view owns their drop handling, which reordering already relies on.

**Also from the thumbnails.** Their right-click menu lists the page tools, so the three file tools show there too.

**Save Selected Pages As… writes a new file without moving the window.** It builds a `PDFDocument` from copies of the selected pages as shown (pending edits included), and writes it through `FileReplacement` to the path from a save sheet named "<name> pages.pdf".

**Split writes next to the original.** A sheet offers "Every page" or "At the selected pages" (greyed with fewer than one selected after page 1). Files are written in the original's folder as "<name> 1.pdf", "<name> 2.pdf", …, skipping numbers whose names exist. Unsaved edits are included. The window stays on its file.

**File menu tools.** `ToolSpec.menu` is `.view`, `.tools` (the defaults by `isEditTool`) or `.file`; the host lists File tools after Save As…, with their edit-tool greying.

## Risks / Trade-offs

- [Large inserted files in the recovery copy] → held as data, as deleted pages are, within the 256 MB limit.
- [The pages view may claim file drops itself] → checked on screen; if it does, drops wait with the thumbnails.
