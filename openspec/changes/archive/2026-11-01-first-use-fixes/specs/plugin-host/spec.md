## ADDED Requirements

### Requirement: A document can show an active command

A document MAY name one of its commands as active, such as a tool waiting for its click, and SHALL tell the host when that changes. The host SHALL show the active command's toolbar button as selected and check its menu item, and show none selected when the document names none. A document that never names one SHALL look as before.

#### Scenario: A tool becomes active

- **WHEN** a PDF document names Text Box as its active command
- **THEN** the window's Text Box toolbar button shows as selected and Commands > Text Box is checked, until the document names none
