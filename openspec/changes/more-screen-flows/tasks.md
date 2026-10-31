# Tasks

## 1. pdf-tool

- [x] 1.1 Add `pdf-tool pages <out.pdf> <n>` and per-page lines (`page 1: Page 3, rotation 90`) to `inspect`, with both in its usage header; verify by making a 4-page PDF, rotating page 2 with PDFKit in a scratch script or by hand in Peeker, and reading the expected lines back

## 2. PDF page flow

- [x] 2.1 Write `scripts/screen/pdf-pages-flow.sh`: open a 4-page PDF in Edit mode, select thumbnails through Accessibility, Rotate Right on page 2, Delete Page on page 4, save, and check the saved page list; verify it passes on its own
- [x] 2.2 Add the thumbnail drag (page 3 above page 1) and update the expected order; verify three runs in a row pass, or else remove the drag, record the gap in `openspec/gaps.md`, and verify the flow passes without it
- [x] 2.3 Add undo after save (the drag, then the saved delete) and save again, then rotate and delete once more and leave Edit mode with Don't Save; check the deleted page is back in the file, and that after Don't Save the thumbnail count matches the file and the file is unchanged; verify it passes on its own

## 3. Image editing flow

- [x] 3.1 Write `scripts/screen/image-edit-flow.sh`: a 400 × 200 PNG in Edit mode, crop, Rotate & Resize with R (check the fields swap), Width 100 with the lock on, Apply, save; check the saved pixel size and the info panel's Dimensions against the fields, and that Cmd+W closes without a sheet; verify it passes on its own

## 4. Crash recovery flow

- [x] 4.1 Write `scripts/screen/recovery-flow.sh`: edit a text file and a form PDF's Name field, wait for two records, kill the build under test with SIGKILL, relaunch with the same recovery folder; check both windows reopen, the PDF shows the Edit mode tools, closing each shows the Save sheet, and after Don't Save on both the recovery folder is empty; verify it passes on its own

## 5. Suite and docs

- [ ] 5.1 Add `pdf-pages`, `image-edit` and `recovery` to `scripts/screen-test.sh` (names, help text) and describe them in the run-peeker skill; verify `scripts/screen-test.sh` passes in full and `scripts/screen-test.sh image-edit` runs that flow alone
- [ ] 5.2 Delete `docs/screenontest.md` and repoint the review report's references at `scripts/screen-test.sh`; verify `grep -rn screenontest` finds only history
- [ ] 5.3 Run `scripts/build.sh test`, `scripts/check-plugin-imports.sh` and `openspec validate --all --strict`; verify all pass with no warnings, and list any app bugs the flows found with their commits

## Workflow follow-up

- Archive with `/opsx:archive` once its tasks are done.
- Bugs found get a failing unit test, a fix and a commit of their own as part of the task whose flow found them.
