## ADDED Requirements

### Requirement: A document can replace itself

A document SHALL be able to hand the host another document for the same file, such as a PDF unlocked from its lock screen. The host SHALL then show the replacement as if it had just opened: its content, sidebar, commands, toolbar and edit mode.

#### Scenario: Unlocked PDF
- **WHEN** the lock screen of a PDF unlocks it
- **THEN** the tab shows the PDF with its thumbnails and info, and the Commands menu lists the PDF's commands
