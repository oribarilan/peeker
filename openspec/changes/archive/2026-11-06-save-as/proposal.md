# Proposal

## Why

Peeker saves only in place, so marking up a screenshot or combining PDFs overwrites the original, and there's no way to keep a copy of a file with changes. Image markup and the PDF file tools, the next two changes, both rely on writing to a new file. The maintainer chose File > Save As…, with the window following the new file.

## What Changes

- File > Save As… (Shift+Cmd+S) in every Editor window: a save sheet asks for a name and folder, the file is written there with the unsaved edits, and the window then shows the new file. The original stays as it was on disk.
- The format stays the same: the sheet keeps the file's extension. Converting formats waits for an Export command.
- The window keeps its state (scroll position, zoom, and Undo where the format keeps it across a save); its title, proxy icon, Open Recent, file watching and crash recovery follow the new file.
- A file with no unsaved edits, or one that's read-only (a digitally signed PDF, a text file shown only in part), is copied as it is.
- Saving over a file open in another Peeker window is refused, with the reason.
- Plugins get a Save As step in their contract: write the file with these edits (or as it is) to a new place, then follow it.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `documents`: Save As writes a copy with the edits and the window follows it.
- `plugin-host`: the plugin contract gains Save As.

## Impact

- `Sources/PeekerKit/Plugin.swift` (`saveAs(_:to:)`, default refusing); each saving document: `TextDocument`, `MarkdownEditor`, `PDFPluginDocument` (and `PDFPlugin.write` with separate source and destination), `ImageDocument` (and `ImageSaving`, plus the views that keep their own copy of the URL).
- Host: `DocumentViewController` (the URL, file watcher, recovery journal and modification baseline follow the new file), `DocumentWindowController` (the save sheet, title, history entry, Open Recent), `MainMenu` (Save As…), `RecoveryJournal`.
- Tests per plugin and for the host; a screen step; CHANGELOG; minor version bump.
