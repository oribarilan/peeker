# Proposal

## Why

Combining scans into one PDF, pulling a few pages out, or splitting a long file all mean another app today. The maintainer chose (interview, 2026-11-05) to build them on the page tools Peeker already has and on Save As: insert pages from other files, save the selected pages as a new PDF, and split a PDF into files.

## What Changes

- File > Insert Pages from File… (and dropping PDFs or images from Finder onto the pages) inserts another PDF's pages, or an image as a page, after the selected page or the one shown. Inserted pages are pending edits like the other page tools: undoable, saved with Cmd+S, kept in the recovery copy.
- Combining is insert, then Save As….
- File > Save Selected Pages As… writes the pages selected in the thumbnails, with their pending edits, to a new PDF; the window stays on its file.
- File > Split… writes one file per page, or one file per run of pages starting at each selected page, next to the original, as "name 1.pdf", "name 2.pdf"; names that exist are never overwritten.
- All three are PDF edit tools, greyed out with the reason where page changes are (signed or locked PDFs, permissions), and absent from the Peek panel.
- Plugins can list a tool in the File menu.
- Dragging thumbnails out to Finder, and dropping files onto the thumbnails, wait.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `pdf`: inserting pages from files, saving selected pages, splitting.
- `plugin-host`: a tool can be listed in the File menu.

## Impact

- `PeekerKit.ToolSpec` gains a menu placement; `MainMenu.rebuildTools` puts File tools after Save As….
- `Plugins/pdf/`: a new `insertPages` edit (stored with the inserted pages' source so recovery can rebuild them), `PDFEditing`, the thumbnails' drop handling, the export and split writers, tool specs.
- Tests for each; a pdf-pages screen step; CHANGELOG; minor version bump.
