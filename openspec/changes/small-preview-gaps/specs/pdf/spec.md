## ADDED Requirements

### Requirement: Password-protected PDFs

A PDF that needs a password SHALL show, in a document window, a lock with the file's name, a password field and Unlock. The right password SHALL show the PDF with thumbnails, info, Find and Print, view-only with Edit greyed out and the reason; a wrong one SHALL say "Wrong password." and clear the field. The password SHALL never be stored. The Space panel SHALL say the PDF is password protected and that Open unlocks it in a window.

#### Scenario: Unlocking
- **WHEN** the user opens a password-protected PDF, types its password and presses Return
- **THEN** the pages, thumbnails and info appear and Edit is greyed out with the reason

#### Scenario: Wrong password
- **WHEN** the user types a wrong password and presses Unlock
- **THEN** the tab says "Wrong password." and the field is empty

#### Scenario: Space panel
- **WHEN** the user presses Space on a password-protected PDF
- **THEN** the panel says the PDF is password protected and that Open unlocks it in a window
