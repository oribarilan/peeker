## MODIFIED Requirements

### Requirement: Highlight is a highlighter for one drag

Highlight (Ctrl+Cmd+H) SHALL be an edit tool. Choosing it SHALL arm the highlighter: the next drag over text SHALL cover each line it selects with an opaque highlight in the current highlight color, clear the selection, mark the document edited and disarm it. Text already selected SHALL be highlighted at once, leaving the highlighter armed for one drag. Escape or another tool SHALL disarm it. Highlights SHALL stay pending until Cmd+S.

#### Scenario: Highlighting by dragging

- **WHEN** the user clicks Highlight and drags over a sentence spanning two lines
- **THEN** both lines are highlighted, the window shows the edited mark, and a second drag only selects text

#### Scenario: A selection made first

- **WHEN** the user selects a word and presses Ctrl+Cmd+H
- **THEN** the word is highlighted, and the next drag over text highlights it too

#### Scenario: Changing one's mind

- **WHEN** the user clicks Highlight and presses Escape before dragging
- **THEN** the next drag only selects text

## ADDED Requirements

### Requirement: Highlight colors

The Highlight tool SHALL offer five colors, in this order: Yellow, Green, Blue, Pink and Purple, as choices of the tool, with the current color checked. Picking a color SHALL make it the current color and then do what choosing Highlight does: highlight selected text at once in that color and arm the highlighter. New highlights SHALL use the current color; highlights already on the page SHALL keep theirs.

#### Scenario: Picking a color

- **WHEN** the user picks Green from the Highlight button's menu and drags over a sentence
- **THEN** the sentence gets a green highlight, a yellow highlight made earlier stays yellow, and saving writes both colors into the file

#### Scenario: A selection made first

- **WHEN** the user selects a word and picks Blue from Tools > Highlight Color
- **THEN** the word is highlighted in blue at once, and the next drag over text is highlighted in blue too

#### Scenario: Read-only document

- **WHEN** a PDF opens read-only
- **THEN** the colors are greyed out with the Highlight tool's reason, as Highlight is

### Requirement: The highlight color is remembered

The current highlight color SHALL be remembered for every PDF, in windows and across launches, starting as Yellow. A remembered value that isn't one of the five SHALL count as Yellow.

#### Scenario: Remembered

- **WHEN** the user picks Purple, quits Peeker, and opens another PDF
- **THEN** Tools > Highlight Color shows Purple checked, and the next highlight is purple

#### Scenario: Something else remembered

- **WHEN** the remembered color is a name Peeker doesn't offer
- **THEN** PDFs open with Yellow checked and highlight in yellow
