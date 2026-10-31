# Proposal

## Why

Two everyday things Preview does are missing: searching a PDF, and printing anything. Cmd+F reaches only text and Markdown views, and there's no Print at all, so either one sends the user back to Preview. Decided in an interview on 2026-10-31.

## What Changes

- **Find in PDFs.** In a document window, Cmd+F opens a find bar above the pages: a search field, the match count, previous and next buttons and Done. Matches are highlighted on the page; Return, Cmd+G and the next button go to the next match, Shift+Return, Shift+Cmd+G and the previous button to the one before, wrapping around at either end. Matching ignores case and accents and has no options. Escape or Done closes the bar. It works in the read view and in Edit mode, searches without stalling the window, and a PDF without text shows no matches.
- **Find Previous** (Shift+Cmd+G) joins Find and Find Next in the Edit menu, for every view that supports finding.
- **File > Print (Cmd+P)** in document windows, through the system print panel, for PDFs, images, text and Markdown. It prints what's on screen, unsaved edits included. A PDF prints each page fitted to the paper and turned to match it. An image prints centered, turned to match the paper, shrunk to fit and never enlarged. Text and Markdown print black on white even in dark mode, wrapped to the page width, with the system header (file name and date) and page numbers; Markdown prints rendered.
- Cmd+P and Shift+Cmd+G become menu shortcuts, so Settings refuses them for plugin commands like other menu keys.
- Not included: Page Setup, Export as PDF, a list of results in the sidebar, Find in images. Find and Print in the Space panel are noted as possible future work.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `plugin-host`: the host offers File > Print and Find Previous; a plugin supplies its document's print job.
- `pdf`: a find bar, and printing.
- `image`: printing.
- `text`: printing.
- `markdown`: printing.

## Impact

- `Sources/PeekerKit/Plugin.swift`: a new optional `PluginDocument` member that returns the print job.
- `Sources/Host/App/MainMenu.swift` (Print, Find Previous), `Sources/Host/Documents/DocumentWindowController.swift` (the print action and its menu check).
- `Plugins/pdf/`: a new find bar file; the document's view gains a container holding the bar above the pages.
- `Plugins/image/`, `Plugins/text/`, `Plugins/markdown/`: each builds its own print job.
- No new dependencies. Opening stays as fast: the find bar is made only when first shown, and print jobs only when Print is chosen.
- `openspec/gaps.md`: PDF search and printing leave the "Missing next to Preview" list; Find and Print in the Space panel go under future work.
