# Design

## Context

Flows source `scripts/screen/common.sh`, which provides the tools (`drive`, `pdf-tool`), the evidence folder, `check`, `launch` (with `PEEKER_CONFIG` and `PEEKER_RECOVERY=$OUT/recovery`), `quit_app`, optional recording and the cleanup trap. `drive` waits on windows, sheets, menus and labeled controls, and its keys, clicks and drags no longer leave modifiers held. `pdf-tool` makes one form PDF and prints field values and annotations. The PDF page commands are toolbar buttons and menu items labeled "Rotate Left", "Rotate Right" and "Delete Page"; they act on the selected thumbnails, or the current page when none are. Image Edit mode has Crop (C, then drag and Return) and Rotate & Resize (Cmd+R) with fields labeled Width and Height, a Keep proportions checkbox and Apply. Leaving Edit mode with unsaved edits asks Save / Don't Save / Cancel. Recovery copies are written about 2 s after the last edit, and a launch restores each record into a window.

## Goals / Non-Goals

**Goals:**
- Each flow checks what a user would see or what lands in the file, not the app's internals.
- Checks hold however a synthetic drag lands, so a few pixels of difference never fail a run.

**Non-Goals:**
- New `drive` commands beyond what a flow can't do without them.
- Recovered edits for a file that changed or vanished while Peeker was dead (unit tests cover them).

## Decisions

**`pdf-tool` grows two things.** `pdf-tool pages <out.pdf> <n>` writes an n-page Letter PDF whose pages say "Page 1", "Page 2"…, and `inspect` adds one line per page: `page 1: Page 3, rotation 90`. The page checks then compare the saved file's page list with a literal expected list.

**`pdf-pages` flow.** A 4-page PDF opens in Edit mode.
1. Click thumbnail 2, Rotate Right; click thumbnail 4, Delete Page. Drag thumbnail 3 above thumbnail 1. Save. Check: `Page 3 / Page 1 / Page 2 (90)` in that order.
2. Edit > Undo once (the drag), then again (the delete, which was saved), and save. Check: the deleted page is back.
3. Rotate and delete again, then leave Edit mode and answer Don't Save. Check: the thumbnails count matches the file again (counted through Accessibility), and the file is unchanged.

Thumbnails are found through Accessibility (the sidebar's collection items) and clicked at their frames. The drag goes through `drive drag` with intermediate points; PDFKit starts a drag session only after the pointer moves past a threshold while held, so the drag path holds briefly at the start and moves in small steps. If three runs in a row can't produce the reorder, the drag steps come out, step 1 expects the order without it, and `openspec/gaps.md` records that the drag is covered only by the unit test that imitates PDFKit's drop.

**`image-edit` flow.** A 400 × 200 PNG (made with `sips` from a system icon, as routing does) opens in Edit mode.
1. C, drag over roughly the left half of the image, Return.
2. Cmd+R; read the Width and Height fields (W × H, the cropped size); press R; check the fields read H × W.
3. Set Width to 100 with Keep proportions on, Apply, close the panel, Cmd+S.
4. Check: the saved file's pixel size (from `sips -g pixelWidth -g pixelHeight`) is 100 × round(100 · W / H); the info panel's Dimensions say the same; Cmd+W closes the window without a sheet.

Every expected number comes from the fields read in step 2, so the exact crop doesn't matter.

**`recovery` flow.** A text file and a form PDF open; the flow types into the text, and in the PDF turns on Edit mode and types into the Name field. It waits until the recovery folder holds two records (polling, up to 10 s), kills the build under test with SIGKILL (as a crash or force quit would), and launches it again with the same recovery folder. Checks: both windows reopen; the PDF window shows the Edit mode tools; closing each window shows the Save sheet (it's marked edited); after Don't Save on both, the recovery folder is empty. The clipboard path isn't exercised, so the run never touches the user's clipboard.

**Runner and docs.** `screen-test.sh` lists `pdf-pages`, `image-edit` and `recovery` after the existing flows. The run-peeker skill describes them. `docs/screenontest.md` is deleted; the review report's notes that point at it point at `scripts/screen-test.sh`.

**Bugs found.** A flow that fails for a reason in the app gets a failing unit test first where an in-process test can reach the code, then the fix, then the flow step passing on screen. Each is reported in the summary and committed on its own.

## Risks / Trade-offs

- [PDFKit's thumbnail drag may ignore synthetic events] → The three-run cutoff and the documented fallback above; the reorder itself stays tested in-process.
- [A crop drag lands a few pixels off] → Checks derive from the size fields, never from the drag.
- [Killing Peeker mid-write corrupts a record] → The flow kills only after both records exist and a second has passed since the last edit.
- [The suite gets longer] → About one to two more minutes; flows still run by name.
