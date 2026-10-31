## ADDED Requirements

### Requirement: Find in a PDF

In a document window, Find… (Cmd+F) SHALL show a find bar above the pages with a search field, the match count, previous and next buttons and Done, with the cursor in the field. Typing SHALL search the whole document, ignoring case and accents, without stalling the window. Every match SHALL be highlighted and the current one selected and in view. Find SHALL work in the read view and in Edit mode and never change the file.

#### Scenario: Searching
- **WHEN** the user presses Cmd+F in a PDF window and types "invoice", which appears 3 times
- **THEN** all 3 matches are highlighted, the first is selected and in view, and the bar says "1 of 3"

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

### Requirement: Moving between PDF matches

Return, Find Next (Cmd+G) and the next button SHALL make the next match current; Shift+Return, Find Previous (Shift+Cmd+G) and the previous button the one before. Both SHALL wrap around at either end. Find Next and Find Previous SHALL work whether or not the bar's field has focus, and after the bar is closed they SHALL use the last search.

#### Scenario: Wrapping around
- **WHEN** the third of 3 matches is current and the user presses Cmd+G
- **THEN** the first match becomes current and the bar says "1 of 3"

#### Scenario: Previous match
- **WHEN** the first of 3 matches is current and the user presses Shift+Return in the field
- **THEN** the third match becomes current

#### Scenario: After closing
- **WHEN** the user closed the bar after searching and presses Cmd+G
- **THEN** the next match of the last search is selected and in view

### Requirement: Closing the PDF find bar

Escape in the field or Done SHALL close the bar and clear the highlights, leaving the current match selected.

#### Scenario: Escape
- **WHEN** the user presses Escape in the find bar's field
- **THEN** the bar closes, the highlights disappear and the current match stays selected

### Requirement: Print a PDF

Printing a PDF SHALL print its pages as they appear in the window, including filled form fields, text boxes, signatures and highlights not yet saved. Each page SHALL be scaled to fit the paper and turned to match the paper's orientation.

#### Scenario: Unsaved text box prints
- **WHEN** the user adds a text box reading "Approved" and prints without saving
- **THEN** the printout shows "Approved" on that page

#### Scenario: Landscape page on portrait paper
- **WHEN** a PDF has a landscape page and the paper is portrait
- **THEN** that page is turned and scaled to fill the paper
