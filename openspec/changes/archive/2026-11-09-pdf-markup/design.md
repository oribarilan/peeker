# Design

## Model

A new mark kind, `PDFMark.Kind.drawing(PDFDrawing)`, with `MarkType.drawing`. `PDFDrawing` holds the shape (pen, line, arrow, box, ellipse, x, check, circle, dot), the strokes as points in 0...1 of the mark's rect (as signatures store them), the color and the line width in points. Signatures stay their own kind: always black, never copied.

Recovery records gain cases but no old case changes, so older records still decode.

## Geometry

Shapes are built in page points, then stored relative to the rect:

- Line and Arrow: the drag's two ends; Arrow adds two head strokes, their length from the width (at least 6 pt).
- Box: a closed rectangle inset by half the width; Ellipse and Circle: a 64-point polyline.
- X: two diagonals; Check: three points; Dot: a circle half the side across, stroked half the side wide, which fills it. A dot's width can therefore go well past the 40 pt other drawings are held to.
- Pen: the drag's points, thinned to at most `maxPoints`.

A resize scales Pen and Line strokes into the new rect; an arrow's head is rebuilt from its scaled shaft, a dot's width follows its new side, and the framed shapes are built again inside the new rect, as they are after a new width. `PDFMarks.setBounds` does this, so the live view and the save run the same code.

## Annotations

Each drawing is an ink annotation with its color, a border of its width, `/NM` and `/PeekerID` as the other marks, no author, and `/PeekerShape` naming the shape. An ink annotation with `/PeekerShape` reads back as a drawing; one without stays a signature, so files saved earlier keep working.

A color or size change is a new edit, `setLook(id:page:color:width:)`, folded like `setText`: into an unsaved add, or only the latest per mark.

## Tools and the strip

Markup (`markup`, M) goes in the toolbar; Text Box (`text-box`, T, unchanged id) and `markup-pen`, `markup-line`, `markup-arrow`, `markup-box`, `markup-x`, `markup-check`, `markup-circle`, `markup-dot` are menu-only edit tools with their keys, as image markup's are.

`EditController.Tool` gains `.draw(PDFDrawing.Shape)`. With a drawing tool armed, a mouse-down on a Peeker mark selects and drags it as today; elsewhere it starts a draft, drawn by `EditOverlay`, which becomes one `.add` on mouse-up. A click (under 3 pt of movement) drops a stamp at the strip's size and makes no mark for Pen, Line, Arrow and Box. The tool stays armed. Text Box keeps today's one-box behavior.

Lines and outlines (Pen, Line, Arrow, Box, Ellipse, Circle) are hit along their strokes, within 3 screen points, so a box drawn around a form field leaves the field clickable; X, Check and Dot by their rect. S, M or L on a selected dot resizes it to that stamp size around its center.

`PDFMarkupStrip` replaces `TextBoxStrip`: a `MarkupBar` with S/M/L, the Aa `StyleMenu` and the point size as details, keeping the strip's floating, scrolling and double-click handling. It shows while Markup is on, a box is typed in, or a text box or drawing is selected. Sizes: stroke 1, 2 and 3.5 pt; a clicked stamp 14, 22 and 34 pt across. The drawing color and size are remembered in `plugins.pdf.markupColor` and `plugins.pdf.markupSize`, apart from the text box style.

## Copy and paste

`PeekerPDFView` answers `copy:` and `paste:` when the document has a mark to copy or paste, and leaves text copying to PDFKit otherwise. The mark goes on the pasteboard as JSON under `dev.peeker.pdf-mark`. A paste takes a new id, the page in view, the rect moved 12 pt right and down, no bigger than the page and kept on it, and checks the mark's validity as recovery records are checked. Signatures and highlights are never written to the pasteboard.
