# Proposal

## Why

The PDF spec says a signature is written nowhere but the PDF it's placed in. A signature placed but not yet saved broke that: it went into the crash-recovery copy of the unsaved edits, a JSON file in the user's Library, and stayed there until the user saved or discarded the edits. The same held for the copy kept when a page with that signature was deleted and the deletion undone.

## What Changes

- The crash-recovery copy holds no signature strokes. A signature placed since the last save is left out; saving still writes it into the PDF.
- A deleted page put back keeps no copy in the record when its deletion is in the record too, since replaying the deletion keeps the pages. The copy kept for an undone saved deletion loses its signatures. Pages inserted from another PDF are kept as that file has them.
- After a crash, the other edits come back and a new signature has to be placed again. Moves and removals of saved signatures carry no strokes and are still recovered, including a saved signature removed, put back and moved.
- A record that held only a signature restores nothing and is removed, instead of being refused at every launch.

## Capabilities

### Modified Capabilities

- `pdf`: signatures are never written to disk, crash-recovery copies included.

## Impact

`PDFSnapshot` in `Plugins/pdf/PDFPluginDocument.swift`. Unit tests, a check in the pdf-edit flow, CHANGELOG; patch version bump.
