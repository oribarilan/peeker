# Design

## Context

Every ImageIO call in `ImagePlugin` reads index 0 (`source`, `displayDecode`, `decodeFull`, `info`). `decode` already counts frames, and a TIFF with more than one is read-only ("This image has several frames") and never animates (`animatedTypes` leaves TIFF out). `ImageDocument` holds one decode (`base`, `baseSize`, `full`, `info`) and shows it on `ImageCanvas` in a magnifying scroll view; its sidebar is the info panel alone. The host rebuilds the sidebar from `makeSidebar()` when a document calls `onSidebarChange`. PDF thumbnails come from PDFKit's `PDFThumbnailView`, which only takes a `PDFView`, and plugins can't share code with each other. Shortcuts (`Sources/Host/App/Shortcut.swift`) know characters, Space, Escape, Tab and Enter, and view tools must carry Command, Option or Control.

## Goals / Non-Goals

**Goals:**
- Pages for TIFF with no change to how any other image opens, and nothing added to the open path.
- Keep `ImageDocument` one page at a time, so zoom, sharpening and printing a single image stay as they are.

**Non-Goals:**
- Editing multi-page TIFFs, pages in the Peek panel, pages for other formats (ICO and ICNS hold sizes, HEIC sequences animate).
- Remembering the page across reloads: a file changed on disk reopens on page 1, since the image document has no in-place reload.

## Decisions

**A page index through the decode functions.** `decode`, `decodeFull` and `info(of:)` take a page, default 0, and use it in place of index 0. `Decoded` gains `pageCount`: the frame count for TIFF, 1 for everything else, so only TIFF gets pages. Opening still decodes page 0 alone. The info rows of a multi-page TIFF start with "Page: 3 of 5".

**`ImageDocument` swaps its picture on a page change.** Showing a page cancels any page decode or sharpening in flight, decodes the new page off the main thread at the same screen size, then replaces `base`, `baseSize`, `pointsPerPixel` (now a `var`), `info` and the canvas image, drops `full`, and calls `onSidebarChange`. The `generation` counter that guards sharpening after a save also guards it across page changes. If the magnification is 1 (fit) it stays; otherwise it's kept and the view scrolls to the top left. A decode that fails leaves the current page and beeps.

**Next Page and Previous Page are view tools of the plugin (`next-page`, `previous-page`) with defaults `pagedown` and `pageup`, not in the toolbar.** `ImageDocument.tools` leaves them out unless the file has pages, so single images, the Peek panel and their menus are unchanged. `unavailableReason` greys them out on the last and first page.

**A thumbnail list of the plugin's own: an `NSTableView` in a scroll view, one row per page.** Rows show a small decode (about 256 pixels on the longer side, from `CGImageSourceCreateThumbnailAtIndex`) made off the main thread when a row first shows, kept in a cache for the document's life. Selecting a row shows that page; showing a page selects its row and scrolls it into view. `makeSidebar()` returns the same list view each time, with `.fill`, above the info panel, so rebuilding the sidebar keeps its scroll position. Considered a collection view: more code for a single column. Considered moving the PDF thumbnails into PeekerKit: they're PDFKit's and can't show images.

**Printing a multi-page TIFF uses a view that paginates itself.** It returns one rect per page (`knowsPageRange`, `rectForPage`) and draws each page decoded at screen size when the print job is made, by the single-image sizing rule: own size from pixels and resolution, shrunk to fit, never enlarged, centered. The orientation follows the first page. A single image keeps today's `NSImageView` job.

**Shortcuts gain `.pageUp` and `.pageDown`.** Config names `pageup` and `pagedown`; key codes 116 and 121; menu key equivalents `NSPageUpFunctionKey` and `NSPageDownFunctionKey`, which menus draw as ⇞ and ⇟; Settings text "Page Up" and "Page Down". `Shortcut.Rules.viewTool` accepts them without a modifier. The key recorder reads them from the key event like the other named keys. The schema's shortcut description mentions them.

## Risks / Trade-offs

- [Page Up and Page Down no longer scroll a zoomed page, since the menu takes them] → chosen in the interview; scrolling still works with the trackpad, arrows and scroll bars, and the tools can be rebound.
- [A page change replaces `base` while a save could run] → can't happen: a multi-page TIFF is read-only, so it never saves.
- [Many large pages make many thumbnail decodes] → only rows that show decode, off the main thread, at 256 pixels.
- [The sidebar rebuild moves the same list view into a new stack] → the host already rebuilds sidebars after saves and reloads; a test checks the list keeps its selection across a page change.
