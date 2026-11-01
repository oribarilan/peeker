# Proposal

## Why

Rotating a scanned page that came in sideways, dropping a blank page, or putting pages back in order are the PDF chores left that still need Preview. They're next on the roadmap after fill and sign. Decided in an interview on 2026-10-31.

## What Changes

- In Edit mode, PDF pages can be rotated left or right, deleted, and reordered by dragging thumbnails in the sidebar.
- Thumbnails take multiple selection (Shift- and Cmd-click). Commands act on the selected thumbnails, or on the current page when none is selected.
- New PDF commands:
  - Rotate Left (Cmd+L) and Rotate Right (Cmd+R).
  - Delete Page, also from the Delete key in the sidebar.
  - All three show as toolbar buttons in Edit mode.
  - All three are in the Commands menu and a right-click menu on the thumbnails. Run from the read view, they turn Edit mode on. The shortcuts can be rebound.
- Page changes behave like other edits: pending until Cmd+S, one undo step per command or drag, kept in the recovery copy, and asked about on close. Undo brings back a deleted page even after a save. Rotation is saved as the page's standard rotation. Annotations, form fields and links stay with their page.
- Deleting every page is refused.
- A PDF that allows comments and form filling but forbids page changes keeps Edit mode for those. The page commands are greyed out with the reason as a tooltip, and dragging does nothing.
- The host gains a way for a plugin to grey out one of its commands and say why.
- Not included: inserting pages from another file, extracting pages, blank pages, dragging thumbnails to or from Finder.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `pdf`: page rotation, deletion and reordering in Edit mode, and how they save.
- `plugin-host`: commands a document can't run right now are greyed out with a reason.

## Impact

- `Sources/PeekerKit/Plugin.swift`: a new optional `PluginDocument` member that gives the reason a command is unavailable.
- `Sources/Host/Documents/DocumentWindowController.swift`: menu and toolbar checks use it.
- `Plugins/pdf/`:
  - New page edits in `PDFEdit` and applying them in `PDFMarks`.
  - A document subclass that notices thumbnail drags.
  - A thumbnail view subclass for the Delete key and the right-click menu.
  - The new commands in `PDFPlugin`.
- The recovery copy's format gains the page edits; older records still decode.
- Opening is unchanged: the subclasses add no work at open.
