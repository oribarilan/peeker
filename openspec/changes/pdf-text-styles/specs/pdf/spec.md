## MODIFIED Requirements

### Requirement: Text boxes add text anywhere on a page

With Text Box chosen, a click on a page SHALL start a text box there for typing, and double-clicking a text box SHALL edit its text again. The box SHALL grow to fit its text. An empty text box SHALL be removed when editing ends. On Cmd+S each text box SHALL be written as a standard free-text annotation with its font, size and colors, so other PDF apps show it the same.

#### Scenario: Filling a flat form

- **WHEN** the user chooses Text Box, clicks next to "Date:" on a scanned form and types a date
- **THEN** the date appears where they clicked, and after saving Preview shows it as a text annotation

## ADDED Requirements

### Requirement: Text box style strip

A strip under the PDF toolbar SHALL show while Text Box waits for its click, while a text box is typed in, and while one is selected. It SHALL hold an Aa menu with the font (Sans, Serif or Mono, written as Helvetica, Times and Courier), Bold, Italic, and Plain or Box; six color swatches, black the default; and the size, from 8 to 36 points.

#### Scenario: The strip comes and goes

- **WHEN** the user chooses Text Box, types a box, then clicks away so nothing is selected
- **THEN** the strip shows from choosing Text Box until the click away

### Requirement: Styling a text box

A style change SHALL apply at once to the box being typed, and to a selected box as one undoable edit. Box SHALL fill the box with the color and write the text in white or black, whichever reads better. The style SHALL be remembered for new boxes across windows and launches, and a saved box opened again SHALL edit with its own style.

#### Scenario: A red serif note

- **WHEN** the user picks Serif and the red swatch, types a note and saves
- **THEN** the saved annotation is red Times, and the next box starts red Times too

#### Scenario: Restyling a saved box

- **WHEN** the user selects a saved text box and chooses Box
- **THEN** the box fills with its color, and Undo brings back the plain text
