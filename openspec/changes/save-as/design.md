# Design

## Context

Each saving plugin keeps its file's URL in a `let` and writes by reading that path back: `TextFile.write` and Markdown write the text there, `PDFPlugin.write` loads a fresh `PDFDocument` from the path, applies the edits and replaces the file, and `ImageSaving.save` reads the source through `CGImageSource` for its type and metadata. In the host, `DocumentViewController.url` is a `let` that the file watcher, the recovery journal and the modification baseline copy; `DocumentWindowController.url` changes only when it reopens a document, which drops Undo. `FileReplacement` can create a new file (temporary file, then a move that fails if the target appeared) or replace an existing one keeping its permissions.

## Goals / Non-Goals

**Goals:** write the file with its unsaved edits to a new place and keep working on it in the same window, with its Undo and, later, image marks. **Non-goals:** changing format (Export, later), Duplicate, autosave-style versions.

## Decisions

**Move the open document to the new file instead of reopening it.** Reopening would lose Undo, and image marks that stay editable until the window closes would be flattened. The contract gains `saveAs(_ edits: UnsavedEdits?, to destination: URL) async throws(PluginError)`: with edits, the plugin writes the file as `save` would but reading from its current file and writing to `destination`; with none, it copies the file as it is. Then the document follows `destination`: later saves, reloads and lazy reads use it. The default throws, so a document that can't save refuses Save As.

**The host follows too.** `DocumentViewController` gets `url` as a `var` and a `moved(to:)` step: a new file watcher, the recovery journal pointed at the new URL (its record rewritten), the modification baseline read from the new file. `DocumentWindowController` updates its URL, title, proxy icon, the history's current entry and Open Recent, and recomputes Open With. Back and Forward entries keep their paths, which still name the original.

**The sheet.** An `NSSavePanel` as a sheet, named "<name> copy" in the file's folder, with `allowedContentTypes` set to the file's type and no other types allowed, so the extension stays. The panel's own overwrite question covers an existing file; a destination open in another Peeker window is refused before writing ("“x” is open in another window"). Peek panel windows have no Save As; the menu item is greyed without an Editor window.

**Read-only and partial files are copied.** They never have edits, so the plugin takes the no-edits path and copies bytes, which also keeps a text file shown only in part whole.

**Per plugin.** Text and Markdown: write the text through `TextFile.write` to the destination with the file's encoding and line endings (a byte copy without edits). PDF: `PDFPlugin.write(edits, from: source, to: destination)`. Image: `ImageSaving.save` takes the source and destination separately; the views that keep a URL of their own (animation, page list) and the info rows follow. Image Undo still ends at a save, as today.

## Risks / Trade-offs

- [A Markdown file saved into another folder shows its relative images as missing until reopened] → noted; links resolve against the new path at once.
- [A failure halfway] → the document only follows the destination after the write succeeded; on failure nothing moves and the edits stay.
