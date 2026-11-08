# Proposal

## Why

PDF text boxes are always black Helvetica, with only their size adjustable from a small bar floating above the box being typed. The maintainer wants a simple style, as image markup text now has (2026-11-08), shown in a strip under the toolbar: the place where more PDF annotations, drawing and stamps, will go later.

## What Changes

- **A strip under the PDF toolbar** shows while Text Box waits for its click, while a box is typed in, and while a box is selected. It holds an Aa menu (Sans, Serif or Mono; Bold; Italic; Plain or Box), six color swatches (black first, the default) and the size (− 12 pt +). The floating size bar goes.
- **Fonts other apps have:** Sans is Helvetica, Serif is Times and Mono is Courier, with their bold and italic faces, so a saved box looks the same in any PDF app.
- **Box** fills the text box with the color and writes the text in white or black, whichever reads better on it.
- **Changes apply** to the box being typed at once, and to a selected box as one undoable edit. The style is remembered for new boxes, in windows and across launches.
- A saved box keeps its style when Peeker opens it again: double-clicking it edits it with its font, color and box.

## Capabilities

### Modified Capabilities

- `pdf`: text boxes have a font, bold, italic, color and box, set from a strip under the toolbar that also holds their size.

## Impact

- `Plugins/pdf/`: a style on the text box mark and its text edit (an optional field, so earlier recovery records still read); `PDFMarks` writes the font name, colors and fill and reads them back; `TextBoxEditor` loses its size bar and applies style live; a new strip view and its container under the toolbar; the remembered style.
- Tests for writing and reading the style, the strip's states, live and undoable changes, and the remembered style; the pdf-edit flow picks Serif and red for a box and checks the saved annotation with `pdf-tool inspect`. CHANGELOG; minor version bump.
