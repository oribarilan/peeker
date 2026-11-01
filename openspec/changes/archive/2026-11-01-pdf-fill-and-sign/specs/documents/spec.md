## MODIFIED Requirements

### Requirement: Edits happen in windows and show as edited

Only document windows SHALL allow edits; the quick-look panel SHALL only view. A document that has an edit mode SHALL allow edits only while Edit mode is on. A document with unsaved edits SHALL show the standard edited mark in its window's close button, and File > Save SHALL be enabled only while there are unsaved edits and no save is running.

#### Scenario: First edit

- **WHEN** the user types into a text file in a window
- **THEN** the close button shows the edited mark and File > Save becomes available

#### Scenario: A document with an edit mode, in its read view

- **WHEN** a PDF form is open in its read view and the user clicks one of its fields
- **THEN** nothing in the document changes and it isn't marked edited

## ADDED Requirements

### Requirement: Documents with an edit mode open in a read view

A document whose plugin declares an edit mode SHALL open in a read view. The window toolbar SHALL show an Edit button, and the button and Cmd+E SHALL turn Edit mode on and off. The plugin's editing tools SHALL appear in the toolbar only while Edit mode is on; they SHALL stay listed in the Commands menu, where choosing one from the read view turns Edit mode on first. A document without an edit mode SHALL show no Edit button and behave as before.

#### Scenario: Turning on Edit mode

- **WHEN** a PDF is open and the user presses Cmd+E
- **THEN** the Edit button shows as on and the toolbar gains Text Box, Sign and Highlight

#### Scenario: A text file

- **WHEN** a text file is open in a window
- **THEN** there's no Edit button and the text can be edited as before

### Requirement: Leaving Edit mode asks about unsaved changes

Turning Edit mode off while the document has unsaved edits SHALL ask whether to save them, offering Save, Don't Save and Cancel. Save SHALL save and leave Edit mode; Don't Save SHALL drop the unsaved edits and leave; Cancel SHALL stay in Edit mode with the edits. Saving with Cmd+S SHALL keep Edit mode on.

#### Scenario: Leaving after signing

- **WHEN** the user places a signature and presses Cmd+E
- **THEN** a sheet asks to save changes, and Don't Save removes the signature and returns to the read view

#### Scenario: Saving while editing

- **WHEN** the user fills a field and presses Cmd+S
- **THEN** the field is saved and the document stays in Edit mode

### Requirement: Edit mode can be unavailable, with the reason

A document SHALL be able to say why Edit mode isn't available for its file. The Edit button SHALL then be disabled, with the reason as its tooltip, and Cmd+E or a tool's shortcut SHALL show the reason instead of turning Edit mode on.

#### Scenario: Pressing Cmd+E on an uneditable file

- **WHEN** a document can't be edited and the user presses Cmd+E
- **THEN** a message gives the reason and the document stays in its read view

### Requirement: A tool's shortcut switches to Edit mode

A plugin SHALL be able to mark a command as an editing tool. Used from the read view, by its shortcut or its Commands menu item, such a command SHALL turn Edit mode on and then run.

#### Scenario: Highlighting from the read view

- **WHEN** a PDF is in its read view with text selected and the user presses Ctrl+Cmd+H
- **THEN** Edit mode turns on and the selection is highlighted

### Requirement: Recovered edits reopen in Edit mode

When the app reopens a document with recovered unsaved edits and the document has an edit mode, the document SHALL open in Edit mode with those edits.

#### Scenario: After a crash while signing

- **WHEN** the app quits unexpectedly with an unsaved signature in a PDF and is launched again
- **THEN** the PDF reopens in Edit mode with the signature, marked edited
