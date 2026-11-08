# Tasks

## 1. Model and annotation

- [x] 1.1 Failing tests: a styled box writes Helvetica/Times/Courier faces, its text color, and for Box a fill with a contrasting text color; reading the annotation back gives the same style; a record without a style reads as the standard one.
- [x] 1.2 `TextBoxStyle` on the text box mark and text edit (optional); `PDFMarks` writes and reads it; undo inverses carry it.

## 2. Strip and editor

- [x] 2.1 Failing tests: the strip shows while Text Box waits, while typing and while a box is selected, and hides otherwise; changing style while typing restyles the text view and lands with the box; on a selected box it's one undo step; the style is remembered.
- [x] 2.2 The strip (Aa menu, swatches, size) in a container under the toolbar; `TextBoxEditor` without its floating size bar, applying style live; the remembered style.

## 3. Checks

- [x] 3.1 pdf-edit flow: pick Serif and red before typing a box, and check the saved annotation (`pdf-tool inspect`); screen run.
- [x] 3.2 `scripts/build.sh test` with no warnings; oracle review; CHANGELOG; `openspec validate --all --strict`.
