# Tasks

## 1. Sharp marks

- [x] 1.1 Failing test: the shown image holds pixelate marks only, and a marks view over the canvas draws the rest; saving still paints all.
- [x] 1.2 Split `MarkRenderer` into the pixel part and the drawn part; add the marks view; `redraw` feeds both.

## 2. Strip

- [x] 2.1 Keys beside the tools' icons, in a small font so the strip fits beside the sidebar in a new window (tested at 760 points).
- [x] 2.2 Failing tests: pixelate strength sets block size, is remembered and changes a selected mark; spotlight shape likewise, ovals dim outside an ellipse.
- [x] 2.3 `ImageMark` cases carry strength and shape; the strip's Strength slider and Rectangle/Oval picker in place of the sizes; the remembered style.

## 3. Checks

- [x] 3.1 `image-edit` flow: X shows the Strength slider and S the shape picker. Sharpness is checked by a unit test (marks drawn by the marks view, not in the shown image) and an off-screen picture at about 7× zoom.
- [x] 3.2 `scripts/build.sh test` passes with no warnings; oracle review; CHANGELOG; `openspec validate --all --strict`.
