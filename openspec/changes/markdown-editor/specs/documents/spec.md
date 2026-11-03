## MODIFIED Requirements

### Requirement: Saving is explicit and done by the owning plugin

Edits made in the Editor SHALL reach the file only through Cmd+S; there SHALL be no autosave. The host SHALL send the edits to the plugin that opened the document, and that plugin SHALL write the file. Edits made while a save is running SHALL stay pending after it.

#### Scenario: Typing during a save

- **WHEN** the user keeps typing while a save is in flight
- **THEN** the save writes the text as it was when the save started, and the document stays marked edited for the newer typing

#### Scenario: Ticking a Markdown task

- **WHEN** the user clicks a task box in a Markdown file in the Editor
- **THEN** the file on disk changes only when the user saves
