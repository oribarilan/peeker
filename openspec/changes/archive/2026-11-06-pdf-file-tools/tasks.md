# Tasks

## 1. Host

- [x] 1.1 `ToolSpec.menu` (.view, .tools, .file; default from `isEditTool`), File tools after Save As… in `MainMenu.rebuildTools`; tests.

## 2. Insert

- [x] 2.1 Failing tests: insert a PDF's pages after page 1 and at the end; an image as a page of its size; Undo and Redo; recovery round trip with bytes and with a path (gone: the restore fails with the name); write and Save As include inserted pages.
- [x] 2.2 `PDFEdit.insertPages`, applying, stashing, folding, recovery validation; Insert Pages from File… (open panel, PDFs and images).
- [x] 2.3 Finder drops on the pages, after the page shown; the dropped-file filter tested (drops onto the thumbnails wait).

## 3. Export and split

- [x] 3.1 Failing tests: Save Selected Pages As… writes the selected pages with pending edits and leaves the document as it was; Split every page and at selected pages, names skipping existing files.
- [x] 3.2 The writers and their sheets.

## 4. Checks and docs

- [x] 4.1 `scripts/build.sh test` passes with no warnings.
- [x] 4.2 pdf-pages screen step: insert a file and check the page count; Split every page; check the files. Save As of a PDF stays a unit test (`PDFSaveAsTests`); the viewer flow drives Save As on a text file.
- [x] 4.3 CHANGELOG; `openspec validate --all --strict`.

## Workflow follow-up

- Commit the change, then bump the minor version in its own commit; archive.
