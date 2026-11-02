## MODIFIED Requirements

### Requirement: Edits happen in windows and show as edited

Only document windows SHALL allow edits; the Peek panel SHALL only view. A document that has an edit mode SHALL allow edits only while Edit mode is on. A document with unsaved edits SHALL show the standard edited mark in its window's close button, and File > Save SHALL be enabled only while there are unsaved edits and no save is running.

#### Scenario: First edit

- **WHEN** the user types into a text file in a window
- **THEN** the close button shows the edited mark and File > Save becomes available

#### Scenario: A document with an edit mode, in its read view

- **WHEN** a PDF form is open in its read view and the user clicks one of its fields
- **THEN** nothing in the document changes and it isn't marked edited
