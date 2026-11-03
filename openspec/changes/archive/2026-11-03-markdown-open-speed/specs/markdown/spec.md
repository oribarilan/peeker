## MODIFIED Requirements

### Requirement: The first screen appears before the rest

When the Peek panel or the Editor shows a long Markdown file, it SHALL draw the first part of the document before the rest, so the top shows without waiting for the whole document. In the Editor, a file over 64 KB SHALL open from a parse of its start, with the outline and counts completing once the rest is parsed.

#### Scenario: Long document

- **WHEN** the user presses Space on an 844 KB Markdown file
- **THEN** the top of the document is drawn first and the rest follows on the next turn of the run loop

#### Scenario: Long document in the Editor

- **WHEN** the user opens an 864 KB Markdown file in a window
- **THEN** the window shows the top styled without waiting for the whole file, and shortly after the outline lists every heading

## ADDED Requirements

### Requirement: The cursor starts at the top

A Markdown file SHALL open in the Editor with the cursor at the start of the text, and the outline SHALL mark the heading that section belongs to.

#### Scenario: Opening a long file

- **WHEN** the user opens a Markdown file with 4,000 headings
- **THEN** the cursor is at the start, the outline marks the first heading and shows the top of the list
