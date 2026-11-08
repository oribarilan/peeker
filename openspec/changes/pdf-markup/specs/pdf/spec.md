## RENAMED Requirements

- FROM: `### Requirement: PDF edit tools: Text Box, Sign and Highlight`
- TO: `### Requirement: PDF edit tools: Markup, Sign and Highlight`
- FROM: `### Requirement: Text box style strip`
- TO: `### Requirement: PDF markup strip`

## MODIFIED Requirements

### Requirement: PDF edit tools: Markup, Sign and Highlight

A PDF opened in the Editor SHALL offer the toolbar edit tools Markup (M), Sign (S) and Highlight Selection (H), each on a single key by default; Rotate Left, Rotate Right and Delete Page SHALL have no default key. Each tool's shortcut can be set or rebound like other plugin tools, and a key set in the config SHALL replace the default. The Peek panel SHALL never offer edit tools.

#### Scenario: The tools

- **WHEN** the user opens a PDF in the Editor
- **THEN** the toolbar offers Markup, Sign and Highlight Selection

#### Scenario: Highlighting with H

- **WHEN** text is selected in a PDF in the Editor and the user presses H
- **THEN** the selection is highlighted

#### Scenario: Typing an h in a form field

- **WHEN** a PDF form field has the keyboard and the user types "h"
- **THEN** the letter goes into the field and nothing is highlighted

#### Scenario: Ctrl+Cmd+S in a PDF

- **WHEN** a PDF is in front
- **THEN** Ctrl+Cmd+S shows or hides the sidebar, and S alone starts Sign

#### Scenario: A key from the config

- **WHEN** the config sets Highlight's shortcut to `ctrl+cmd+h`
- **THEN** ⌃⌘H highlights, and H alone does nothing in the PDF

### Requirement: A waiting tool shows itself

While a markup tool, Sign or Highlight waits for its click or drag, its Tools menu item SHALL be checked, Sign or Highlight SHALL show as selected in the toolbar, as Markup does while its strip shows, and the pointer over a page SHALL show the tool: a crosshair for markup tools, a highlighter, or the signature following it. Once the tool is used or dismissed, they SHALL go back.

#### Scenario: Arming the highlighter

- **WHEN** the user clicks Highlight
- **THEN** the Highlight button shows as selected and the pointer over the page becomes a highlighter, until the drag that highlights or Escape

#### Scenario: Placing a text box

- **WHEN** the user presses T and then clicks on the page
- **THEN** Text Box is checked in the Tools menu with a crosshair pointer until that click, then not

### Requirement: PDF markup strip

Markup SHALL show a strip under the PDF toolbar, the one image markup uses, with Text Box (T), Pen (P), Line (L), Arrow (A), Box (B), X (X), Check (V), Circle (O) and Dot (D), each key arming its tool and showing the strip; six colors, black the default; then S, M and L, or for Text Box the Aa menu (Sans, Serif or Mono, Bold, Italic, Plain or Box) and the size from 8 to 36 points. It SHALL also show while a text box is typed in or a text box, drawing or stamp is selected.

#### Scenario: The strip comes and goes

- **WHEN** the user presses M, then M again
- **THEN** the strip shows, then hides

#### Scenario: Selecting a mark

- **WHEN** Markup is off and the user clicks a drawing Peeker made
- **THEN** the strip shows with the drawing's color and size until the click away

### Requirement: Peeker's own annotations can be adjusted

In the Editor, clicking a text box, drawing, stamp, signature or highlight that Peeker made SHALL select it; lines and outlines are hit along their lines, so what's inside a box stays clickable. A selected one SHALL move by dragging, resize by dragging a corner handle, and be removed with Delete; each SHALL be an edit. This SHALL work for unsaved ones and for ones Peeker saved earlier. Annotations made by other apps SHALL be shown but not selected or changed.

#### Scenario: Moving a saved signature

- **WHEN** the user reopens a PDF they signed and saved in Peeker and drags the signature
- **THEN** the signature moves and the document is marked edited

#### Scenario: Another app's note

- **WHEN** the PDF has a note added in Acrobat and the user clicks it
- **THEN** the note isn't selected and nothing changes

## ADDED Requirements

### Requirement: Drawing on a PDF

With Pen, Line, Arrow or Box armed, a drag on a page SHALL draw that mark in the strip's color and size: a free stroke, a straight line, a line with a head at the drag's end, or a rectangle, an ellipse with Option held. A tool SHALL stay armed for the next mark until Escape or another tool. A drag starting on a Peeker mark SHALL move that mark instead.

#### Scenario: Circling a figure

- **WHEN** the user presses B, holds Option and drags around a chart
- **THEN** an ellipse in the current color surrounds the chart, and B stays armed

### Requirement: Stamps on a PDF

With X, Check, Circle or Dot armed, a click on a page SHALL drop that stamp centered on the click, sized by S, M or L, and a drag SHALL fit it to the dragged rectangle. Dot SHALL be filled; the others SHALL be drawn in lines.

#### Scenario: Ticking a paper form

- **WHEN** the user presses V and clicks in a box on a scanned form
- **THEN** a check mark in the current color sits in the box

### Requirement: Drawings and stamps are saved as ink

On Cmd+S each drawing and stamp SHALL be written as a standard ink annotation in its color and line width, so other PDF apps show it. Like Peeker's other annotations, each SHALL be one undo step, be saved with every other pending edit or not at all, carry no author, and be found again as Peeker's own, with its shape, when the file is reopened.

#### Scenario: Seen in Preview

- **WHEN** the user draws an arrow, saves and opens the PDF in Preview
- **THEN** Preview shows the arrow

#### Scenario: Reopened

- **WHEN** the user reopens a PDF with an arrow they saved and selects it
- **THEN** the strip shows Arrow's color and size, and resizing keeps its head the same size

### Requirement: Restyling a mark

Picking a color or size SHALL apply to the selected drawing or stamp as one undoable edit, and SHALL be remembered for new marks across windows and launches. Selecting a mark SHALL show its own color and size in the strip.

#### Scenario: A red arrow becomes blue

- **WHEN** the user selects a red arrow and picks blue
- **THEN** the arrow turns blue, and Undo makes it red again

### Requirement: Copying and pasting PDF marks

Cmd+C with a text box, drawing or stamp selected SHALL copy that mark, and Cmd+V SHALL paste it onto the page in view, a little below and right of where it was, kept on the page, as one undoable edit, also in another PDF. Signatures and highlights SHALL NOT be copied. Cmd+C with no mark selected SHALL copy selected text as before.

#### Scenario: The same tick on two forms

- **WHEN** the user selects a check mark, presses Cmd+C, opens another PDF in the Editor and presses Cmd+V
- **THEN** the check mark appears on that PDF's page in view, selected
