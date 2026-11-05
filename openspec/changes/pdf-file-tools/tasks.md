# Tasks

## 1. Host

- [ ] 1.1 `ToolSpec.menu` (.view, .tools, .file; default from `isEditTool`), File tools after Save As… in `MainMenu.rebuildTools`; tests.

## 2. Insert

- [ ] 2.1 Failing tests: insert a PDF's pages after page 1 and at the end; an image as a page of its size; Undo and Redo; recovery round trip with bytes and with a path (gone: the restore fails with the name); write and Save As include inserted pages.
- [ ] 2.2 `PDFEdit.insertPages`, applying, stashing, folding, recovery validation; Insert Pages from File… (open panel, PDFs and images).
- [ ] 2.3 Finder drops on the thumbnails at the drop point; tests with a synthetic drop where possible.

## 3. Export and split

- [ ] 3.1 Failing tests: Save Selected Pages As… writes the selected pages with pending edits and leaves the document as it was; Split every page and at selected pages, names skipping existing files.
- [ ] 3.2 The writers and their sheets.

## 4. Checks and docs

- [ ] 4.1 `scripts/build.sh test` passes with no warnings.
- [ ] 4.2 pdf-pages screen step: insert a file, Save As, check the page count; Split every page; check the files.
- [ ] 4.3 CHANGELOG; `openspec validate --all --strict`.

## Workflow follow-up

- Commit the change, then bump the minor version in its own commit; archive.
