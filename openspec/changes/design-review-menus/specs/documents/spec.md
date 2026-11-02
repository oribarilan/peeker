## MODIFIED Requirements

### Requirement: Documents with an edit mode open in a read view

A document whose plugin declares an edit mode SHALL open in a read view. The window toolbar SHALL show an Edit button, and the button, Tools > Edit Mode and Cmd+E SHALL turn Edit mode on and off. The plugin's editing tools SHALL appear in the toolbar only while Edit mode is on; they SHALL stay listed in the Tools menu, where choosing one from the read view turns Edit mode on first. A document without an edit mode SHALL show no Edit button and behave as before.

#### Scenario: Turning on Edit mode

- **WHEN** a PDF is open and the user presses Cmd+E
- **THEN** the Edit button shows as on and the toolbar gains Text Box, Sign and Highlight

#### Scenario: A text file

- **WHEN** a text file is open in a window
- **THEN** there's no Edit button and the text can be edited as before

### Requirement: Unsaved edits are never discarded without asking

Closing a tab or window, switching Open With, reverting to the saved version, or quitting SHALL ask before discarding each document's unsaved edits. Closing, switching and quitting SHALL ask Save, Don't Save (Cmd+D) or Cancel; Revert to Saved… SHALL ask Revert or Cancel. Quitting SHALL bring each such window forward in turn, and the first Cancel SHALL stop the quit. Don't Save and Revert SHALL return the document to its last loaded or saved state.

#### Scenario: Quit with two edited windows

- **WHEN** the user quits with unsaved edits in two windows and cancels at the second prompt
- **THEN** the first window is resolved and closed, the second stays open with its edits, and the app keeps running

#### Scenario: Cancelling a revert

- **WHEN** the user chooses Revert to Saved… and then Cancel
- **THEN** the document keeps its unsaved edits

### Requirement: A tool's shortcut switches to Edit mode

A plugin SHALL be able to mark a command as an editing tool. Used from the read view, by its shortcut or its Tools menu item, such a command SHALL turn Edit mode on and then run.

#### Scenario: Highlighting from the read view

- **WHEN** a PDF is in its read view with text selected and the user presses Ctrl+Cmd+H
- **THEN** Edit mode turns on and the selection is highlighted
