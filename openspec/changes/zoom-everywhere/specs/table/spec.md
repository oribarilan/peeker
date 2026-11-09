## ADDED Requirements

### Requirement: Zooming a table

Zoom In and Zoom Out (Cmd+= and Cmd+-) SHALL change the table's text size, with its rows and columns growing to fit, and Actual Size (Cmd+0) SHALL go back to the default size. They SHALL be listed in the View menu only. The size SHALL be remembered across files and launches, in a window or the Peek panel, as plain text's is; tables already open keep their own until changed.

#### Scenario: Zooming in on a table
- **WHEN** the user presses Cmd+= twice in a CSV window, then opens another CSV file
- **THEN** both tables show larger text, and Cmd+0 puts the second back at the default size
