## ADDED Requirements

### Requirement: Zooming a data file

Zoom In and Zoom Out (Cmd+= and Cmd+-) SHALL change the text size of the tree and of Show Text together, and Actual Size (Cmd+0) SHALL go back to the default size. They SHALL be listed in the View menu only. The size SHALL be remembered across files and launches, in a window or the Peek panel, as plain text's is; files already open keep their own until changed.

#### Scenario: Zooming a JSON tree
- **WHEN** the user presses Cmd+= in a JSON file's tree and switches to Show Text
- **THEN** both the tree and the text are larger, and Cmd+0 puts both back
