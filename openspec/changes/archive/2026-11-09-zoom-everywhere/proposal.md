# Proposal

## Why

Zoom works only from the View menu and its keys, in four of the six formats, and only images pinch. People expect Cmd+scroll and pinch to zoom, and a control that shows and sets the zoom without hunting through View. The maintainer asked for zoom in every format (2026-11-09) and picked the corner pill from a demo of four placements.

## What Changes

- Every format zooms: PDF, image, text and Markdown as today, plus tables and JSON, YAML, TOML, XML and property-list trees, which zoom by text size as plain text does.
- Cmd+scroll and pinch zoom in every format, in Editor windows and in the Peek panel.
- Editor windows get a small glass pill at the bottom right of the document, "− 125% +", shown while the pointer is over the document. − and + step the zoom; clicking the percentage opens a menu with Actual Size, Zoom to Fit where the format has it, and a few fixed steps. The Peek panel gets no pill.
- The toolbar stays without zoom buttons, as decided on 2026-11-02, and the View menu's zoom items and keys stay as they are.
- What's remembered stays as today: text, Markdown, tables and trees keep one text size for all files; PDFs and images open fitted each time.

## Capabilities

### Modified Capabilities

- `plugin-host`: zoom by Cmd+scroll and pinch everywhere, and the zoom pill in Editor windows.
- `table`: tables zoom by text size.
- `data`: trees and their text zoom by text size.

## Impact

- `Sources/PeekerKit/Plugin.swift`: an optional zoom contract for documents (the current zoom as a percentage of actual size, setting it, its range, and a change callback).
- `Sources/Host`: the pill over the document content in Editor windows, and Cmd+scroll and pinch handling for windows and the Peek panel, all going through the contract.
- Each plugin adopts the contract: PDF (`PDFView.scaleFactor`), image (magnification; its own pinch moves to the host's), text and Markdown (font size), table and data (new zoom tools and a remembered text size).
- Specs, tests, a screen step (Cmd+scroll on a PDF and the pill's + on a text file), CHANGELOG, minor version bump. The pdf-pages flow's "no zoom buttons in the toolbar" check stays.
