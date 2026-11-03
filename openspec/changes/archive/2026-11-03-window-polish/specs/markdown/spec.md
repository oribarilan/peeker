## MODIFIED Requirements

### Requirement: Outline and info in the sidebar

The sidebar SHALL list the document's headings; a row SHALL highlight while the pointer is over it, and clicking one SHALL put the cursor at the start of that heading's line and scroll to it. In the Editor the outline SHALL mark the heading of the section the cursor is in, following the cursor as it moves. The sidebar SHALL also show the word count and, when the file has tasks, how many are done out of the total. While the user types, the outline and counts SHALL refresh after a short pause.

#### Scenario: Jumping to a section

- **WHEN** the user clicks a heading in the outline
- **THEN** the view scrolls to that heading, the cursor sits at the start of its line, and the heading is marked

#### Scenario: A new heading

- **WHEN** the user types a new `## Notes` line in the Editor
- **THEN** Notes appears in the outline shortly after, without saving

#### Scenario: Hovering a heading

- **WHEN** the pointer moves over a heading in the outline
- **THEN** that row highlights, and the highlight goes when the pointer leaves

#### Scenario: The cursor's section

- **WHEN** the cursor moves from the text under `# One` into the text under `## Two`
- **THEN** the outline's mark moves from One to Two

#### Scenario: Before the first heading

- **WHEN** the cursor is in text above the first heading
- **THEN** no heading is marked
