# Proposal

## Why

PDFs can take text boxes, signatures and highlights, but not a quick drawing, an arrow, a box around something, or a tick or cross on a form. Images already have a markup strip, and the maintainer wants PDFs to get one that looks and works the same (decided 2026-11-08), with the strip shared in the previous change. PDF marks also can't be copied today.

## What Changes

- **Markup (M)** replaces Text Box in the PDF toolbar and shows a markup strip under it, the shared one images use. Sign, Highlight and the page tools stay as they are.
- The strip's tools: Text Box (T), Pen (P), Line (L), Arrow (A), Box (B, an ellipse with Option), and the stamps X (X), Check (V), Circle (O) and Dot (D). A tool's key arms it and shows the strip. The six colors stay black first.
- Text Box shows its Aa menu and point size in the strip, as its own strip does today; the other tools show S, M and L. That strip folds into the markup strip.
- Pen, Line, Arrow and Box draw by dragging. A stamp drops on a click at the strip's size, or fits a dragged rectangle.
- Drawings and stamps save as standard ink annotations, so other PDF apps show them; Dot is a thick ink circle, which reads as filled. Each is one undo step and can be selected, moved, resized, deleted and recolored, before and after saving. The style is remembered, and selecting a mark shows the strip with its style.
- Cmd+C copies the selected text box, drawing or stamp, and Cmd+V pastes it a little below and right of where it was, also into another PDF. Signatures and highlights aren't copied: a signature on the pasteboard could end up in a clipboard history, which the signature rules forbid, and a highlight belongs to its text.
- Text Box keeps its id and its T, so a shortcut set for it in the config still works; it moves from the toolbar into the strip and the Tools menu.

## Capabilities

### Modified Capabilities

- `pdf`: the edit tools become Markup, Sign and Highlight; the text box style strip becomes the markup strip; new requirements for drawings, stamps, adjusting them and copying marks; saving, undo, ownership and no-author rules cover the new marks.

## Impact

`Plugins/pdf/`: the plugin's tool list and `perform`, the markup strip on `MarkupBar` (replacing `TextBoxStrip`), new mark kinds in `PDFMark`, their ink annotations in `PDFMarks`, drawing and stamping in the edit controller, copy and paste. Tests for each tool, saving, reopening, undo and the pasteboard. The pdf-edit screen flow's Text Box steps move to Markup, and it gains drawing and stamp steps. CHANGELOG; minor version bump.
