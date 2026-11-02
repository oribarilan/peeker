## MODIFIED Requirements

### Requirement: Find in a PDF

In a document window, Find… (Cmd+F) SHALL show a find bar above the pages and below the toolbar, never under it, with a search field, the match count, previous and next buttons and Done, with the cursor in the field. Typing SHALL search the whole document, ignoring case and accents, without stalling the window. Every match SHALL be highlighted and the current one selected and in view. Find SHALL work in the read view and in Edit mode and never change the file.

#### Scenario: Searching
- **WHEN** the user presses Cmd+F in a PDF window and types "invoice", which appears 3 times
- **THEN** all 3 matches are highlighted, the first is selected and in view, and the bar says "1 of 3"

#### Scenario: Bar below the toolbar
- **WHEN** the user presses Cmd+F in a PDF window
- **THEN** the whole find bar, its field and match count included, shows below the toolbar and the window title

#### Scenario: Case and accents ignored
- **WHEN** the user searches for "cafe" in a PDF containing "Café"
- **THEN** "Café" is a match

#### Scenario: No text
- **WHEN** the user searches a scanned PDF that has no text, or for a word that isn't there
- **THEN** the bar says "Not found"

#### Scenario: Edit mode
- **WHEN** the user searches while in Edit mode
- **THEN** matches are found and shown as in the read view, and nothing is added to the unsaved edits

#### Scenario: Space panel
- **WHEN** a PDF is shown in the Space panel
- **THEN** Find is unavailable
