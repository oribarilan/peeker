# Design

## Context

The Edit menu's Find and Find Next send `performFindPanelAction(_:)` down the responder chain, so they reach the text and Markdown views, which use the system find bar (`usesFindBar`). `PDFView` on macOS has no find bar and doesn't answer that action (checked with a probe on macOS 27), so PDF search needs its own bar. There's no Print anywhere. The host knows no formats, so how a file prints belongs to its plugin, while the menu item, the print panel sheet and "finish typing first" belong to the host.

Each plugin already shows what's on screen from live state: the PDF view's document holds unsaved annotations and field values, the text view holds unsaved typing, the image document holds a decoded image no larger than the biggest screen, and the Markdown view holds the rendered text.

## Goals / Non-Goals

**Goals:**
- Search a PDF with a bar that behaves like the text bar.
- Print every format through the system print panel, from what's on screen.
- Opening stays as fast: nothing for find or print is built until it's used, apart from one plain container view.

**Non-Goals:**
- Page Setup, Export as PDF, a results list, search options.
- Find and Print in the Space panel (future work in gaps.md).
- Find in images.

## Decisions

**Contract: an optional print-job maker.** `PluginDocument` gains `var printJob: ((NSPrintInfo) -> NSPrintOperation?)? { get }`, nil by default. The job itself may still come back nil if printing turns out to be impossible, and the host then beeps. A closure property rather than a method because the host must grey out Print for a document that can't print, and menu checks run on every key press: checking for nil is free, while building a print job to find out would lay out a whole text file. Considered: a `canPrint` flag plus a method (two members that can disagree).

**Host.** File > Print… (Cmd+P) sends `printDocument(_:)` to `DocumentWindowController`. It ends typing in progress (the existing `finishTyping()`), asks the document for its job with a copy of the shared print info, sets the job title to the file name and runs it as a sheet on the window. The menu check enables it only when the current document is opened and has a `printJob`. Find Previous joins the Edit menu with the `.previous` tag. `finishTyping()` refocuses `focusView ?? contentView`, because the PDF's content view becomes a container.

**PDF print.** `PDFDocument.printOperation(for:scalingMode: .pageScaleToFit, autoRotate: true)` on the view's document, which already holds the unsaved annotations and field values. A locked PDF or one whose permissions forbid printing has no print job, so Print is greyed out, as in Preview.

**Image print.** The print view draws the decoded image in a frame of the image's own size in points: pixels × 72 ÷ the file's resolution (72 when none), swapped for EXIF orientations 5 to 8. The decoder already reads these properties for the info panel, so it also hands over this size. The print info uses fit pagination both ways, which shrinks a view that's too big but never enlarges one, and centers it; its orientation starts as landscape for a wide image. The screen-size decoded image is sharp enough for paper (a 2560-pixel image across 8 inches is 320 dpi), so the file isn't decoded again.

**Text and Markdown print: one shared helper in PeekerKit.** Both build an offscreen text view as wide as the paper's printable width, in the light appearance with a white background, holding an attributed string; vertical pagination is automatic, horizontal is fit, and the print info turns the header and footer on (the header shows the job title and date, the footer the page number). Text passes its string in its current font, colored black. Markdown passes a copy of its rendered text; its colors are the system's dynamic colors, so the light appearance makes them print dark on white. Two plugins need the same 20 lines and plugins can't share code except through PeekerKit, so the helper goes there now rather than waiting for a third copy.

**PDF find bar.** The PDF document's content view becomes a plain container holding the PDF view, and the bar is made and placed above it on the first Cmd+F.
- Search runs on PDFKit's background search (`beginFindString(_:withOptions:)` with case- and accent-insensitive options). Results arrive as notifications and are added as they come, so the count grows on a long PDF and the window never waits. Each keystroke cancels the search in progress and starts a new one.
- Matches go in the view's `highlightedSelections`. The current match becomes the view's selection and is scrolled into view.
- The container answers `performFindPanelAction(_:)` (show, next, previous) and its menu check. It sits in the responder chain both for the PDF view and for the bar. The bar's search field uses its own field editor, which passes that action up to the container. Without it the field editor, a text view, would take the action and grey out Find Next while the field has focus.
- Return and Shift+Return in the field go to the next and previous match, and Escape closes the bar. Closing clears the highlights, keeps the selection and the matches (so Cmd+G still works), and refocuses the PDF view.
- In a view-only document (the Space panel) the container refuses the action, so the Find items are greyed out.
- Find never touches the pending edits or the undo history.

## Risks / Trade-offs

- **PDFKit's search notifications and threads.** If they arrive off the main thread, the bar hops to the main actor before touching the view. A test on a many-page PDF covers the count and order.
- **Fit pagination never enlarging** is AppKit's documented behavior for `.fit`. A test prints an icon to a PDF file and checks the size it was drawn at.
- **Print jobs in tests** run without the panel, saving to a PDF file, so the printed text, size and orientation can be checked headless. The real print panel sheet is checked by hand in the app.
- **Find in Edit mode.** Selecting a match while a text box is being typed in ends the box first, as any selection change does.
