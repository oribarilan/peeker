# Spec Delta

## MODIFIED Requirements

### Requirement: PDF edit tools: Text Box, Sign and Highlight

A PDF opened in the Editor SHALL offer the edit tools Text Box (T), Sign (S) and Highlight Selection (H), each on a single key by default; Rotate Left, Rotate Right and Delete Page SHALL have no default key. Each tool's shortcut can be set or rebound like other plugin tools, and a key set in the config SHALL replace the default. The Peek panel SHALL never offer edit tools.

#### Scenario: The tools

- **WHEN** the user opens a PDF in the Editor
- **THEN** the toolbar offers Text Box, Sign and Highlight Selection

#### Scenario: Highlighting with H

- **WHEN** text is selected in a PDF in the Editor and the user presses H
- **THEN** the selection is highlighted

#### Scenario: Typing an h in a form field

- **WHEN** a PDF form field has the keyboard and the user types "h"
- **THEN** the letter goes into the field and nothing is highlighted

#### Scenario: Ctrl+Cmd+S in a PDF

- **WHEN** a PDF is in front
- **THEN** Ctrl+Cmd+S shows or hides the sidebar, and S alone starts Sign

#### Scenario: A key from the config

- **WHEN** the config sets Highlight's shortcut to `ctrl+cmd+h`
- **THEN** ⌃⌘H highlights, and H alone does nothing in the PDF
