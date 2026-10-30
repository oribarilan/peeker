# Spec Delta

## MODIFIED Requirements

### Requirement: Opens PDFs quickly and safely

The plugin SHALL open PDF files without stalling the app, checking that the file is a readable PDF before showing it. A file that isn't a readable PDF SHALL show "This file isn't a readable PDF." in its tab, and a password-protected PDF SHALL show "This PDF is password protected."

#### Scenario: Locked PDF

- **WHEN** the user opens a password-protected PDF
- **THEN** the tab says the PDF is password protected

#### Scenario: Not a PDF

- **WHEN** the user opens a text file renamed to `.pdf`
- **THEN** the tab says the file isn't a readable PDF, and the app keeps running
