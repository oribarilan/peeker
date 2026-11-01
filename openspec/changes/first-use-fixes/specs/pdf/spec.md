## ADDED Requirements

### Requirement: Highlight is a highlighter for one drag

Highlight (Ctrl+Cmd+H) SHALL be an Edit mode tool that, from the read view, turns Edit mode on first. Choosing it SHALL arm the highlighter: the next drag over text SHALL cover each line it selects with an opaque yellow highlight, clear the selection, mark the document edited and disarm it. Text already selected SHALL be highlighted at once, leaving the highlighter armed for one drag. Escape, another tool or leaving Edit mode SHALL disarm it. Highlights SHALL stay pending until Cmd+S.

#### Scenario: Highlighting by dragging

- **WHEN** in Edit mode the user clicks Highlight and drags over a sentence spanning two lines
- **THEN** both lines are highlighted, the window shows the edited mark, and a second drag only selects text

#### Scenario: A selection made first

- **WHEN** the user selects a word and presses Ctrl+Cmd+H in the read view
- **THEN** Edit mode turns on, the word is highlighted, and the next drag over text highlights it too

#### Scenario: Changing one's mind

- **WHEN** the user clicks Highlight and presses Escape before dragging
- **THEN** the next drag only selects text

## REMOVED Requirements

### Requirement: Highlighting a selection is an edit

**Reason**: Replaced by "Highlight is a highlighter for one drag", which keeps highlighting a selection made first and adds highlighting by dragging.
**Migration**: None: the command keeps its id (`highlight`) and its shortcut; only its menu title changes from "Highlight Selection" to "Highlight".
