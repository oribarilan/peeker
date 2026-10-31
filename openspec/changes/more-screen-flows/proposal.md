# Proposal

## Why

The screen-test suite (`2026-10-31-screen-test-suite`) runs the routing check, the main flow and the PDF form flow. The parts of the app that changed most in the 2026-10-31 review have no flow: PDF page edits (including the thumbnail drag, review item T8), image editing, and crash recovery, which only unit tests and a hand checklist cover. This second change adds those flows and retires the checklist. Decided on 2026-10-31.

## What Changes

- **`pdf-pages` flow:** rotate and delete pages from the toolbar, drag a page in the thumbnails, save, undo a delete after the save and save again, then rotate and delete once more and close with Don't Save. The saved file's page order and rotation are checked after each save, and reopening after Don't Save shows the pages as last saved. If synthetic drags can't drive PDFKit's thumbnail view reliably, the flow ships without the drag, the existing unit test keeps covering it, and the gap goes in `openspec/gaps.md`.
- **`image-edit` flow:** crop, then press R in Rotate & Resize, resize and save. Checks: the size fields show the turned size after R, the saved file's pixel size, the info panel's Dimensions, and that closing after the save asks nothing.
- **`recovery` flow:** type into a text file and fill a PDF field, kill Peeker, and relaunch it with the same recovery folder. Both windows come back marked edited, the PDF in Edit mode, and Don't Save clears their records. The clipboard path for a vanished file stays a unit test, so a run never writes to the user's clipboard.
- **Runner:** `scripts/screen-test.sh` runs the three new flows after the existing ones, and each runs on its own or by name.
- **`pdf-tool`:** makes a numbered multi-page PDF and prints each page's text and rotation.
- **Bugs a flow finds** are fixed in this change, with a failing unit test first where one can reach the code.
- **Checklist retired:** `docs/screenontest.md` goes, and the review report points at the suite instead.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. This change adds test tooling; it declares `skip_specs`. A bug fix that turns out to change specified behavior would bring its own spec delta into this change.

## Impact

- `scripts/screen/`: `pdf-pages-flow.sh`, `image-edit-flow.sh`, `recovery-flow.sh` (new); `pdf-tool.swift` (multi-page PDFs, page listing).
- `scripts/screen-test.sh`: the three new flow names.
- `.claude/skills/run-peeker/SKILL.md`: the new flows.
- `docs/screenontest.md` (deleted), `docs/code-review-2026-10-31.md` (references), possibly `openspec/gaps.md` (the drag).
- The full suite grows from about three minutes to about four or five.
