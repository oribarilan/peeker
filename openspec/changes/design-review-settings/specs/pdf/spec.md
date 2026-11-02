## MODIFIED Requirements

### Requirement: PDFs have an edit mode with Text Box, Sign and Highlight

A PDF opened in a window SHALL have an edit mode. Its tools SHALL be Text Box (Ctrl+Cmd+T), Sign and Highlight Selection (Ctrl+Cmd+H); Sign SHALL have no shortcut by default, leaving Ctrl+Cmd+S to Show/Hide Sidebar. Each tool's shortcut can be set or rebound like other plugin commands. Zoom In and Zoom Out SHALL work in both modes. The Peek panel SHALL never offer Edit mode.

#### Scenario: The tools

- **WHEN** the user turns on Edit mode for a PDF
- **THEN** the toolbar offers Text Box, Sign and Highlight Selection

#### Scenario: Ctrl+Cmd+S in a PDF

- **WHEN** a PDF is in front and the config sets no shortcut for Sign
- **THEN** Ctrl+Cmd+S shows or hides the sidebar, and Tools > Sign shows no shortcut

### Requirement: Page commands

In a document window, the PDF plugin SHALL offer Rotate Left (Cmd+L), Rotate Right (Cmd+R) and Delete Page, in the Tools menu and a right-click menu on the thumbnails, with Rotate and Delete buttons in the toolbar in Edit mode. Run from the read view, they SHALL turn Edit mode on first. Each SHALL act on the selected thumbnails (Shift- and Cmd-click select several), or on the current page when none is selected. The Peek panel SHALL have no page commands.

#### Scenario: Rotating selected pages
- **WHEN** pages 2 and 3 are selected in the sidebar and the user presses Cmd+R in Edit mode
- **THEN** both pages turn a quarter turn clockwise, and their thumbnails show it

#### Scenario: Current page when nothing is selected
- **WHEN** no thumbnail is selected, page 4 is the current page, and the user chooses Rotate Left
- **THEN** page 4 turns a quarter turn counterclockwise

#### Scenario: From the read view
- **WHEN** the user presses Cmd+L in the read view of an editable PDF
- **THEN** Edit mode turns on and the page rotates

### Requirement: Reordering pages

In Edit mode, dragging thumbnails in the sidebar SHALL move those pages to where they are dropped, keeping their relative order. In the read view and the Peek panel, thumbnails SHALL only select and go to pages, never move them. Pages dragged in from outside the document SHALL be refused.

#### Scenario: Dragging a page
- **WHEN** in Edit mode the user drags page 5's thumbnail above page 1
- **THEN** that page becomes page 1 and the others move down

#### Scenario: Read view
- **WHEN** the user drags a thumbnail in the read view
- **THEN** no page moves

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
- **WHEN** a PDF is shown in the Peek panel
- **THEN** Find is unavailable

### Requirement: Password-protected PDFs

A PDF that needs a password SHALL show, in a document window, a lock with the file's name, a password field and Unlock. The right password SHALL show the PDF with thumbnails, info, Find and Print, view-only with Edit greyed out and the reason; a wrong one SHALL say "Wrong password." and clear the field. The password SHALL never be stored. The Peek panel SHALL say the PDF is password protected and that Open unlocks it in a window.

#### Scenario: Unlocking
- **WHEN** the user opens a password-protected PDF, types its password and presses Return
- **THEN** the pages, thumbnails and info appear and Edit is greyed out with the reason

#### Scenario: Wrong password
- **WHEN** the user types a wrong password and presses Unlock
- **THEN** the tab says "Wrong password." and the field is empty

#### Scenario: Space panel
- **WHEN** the user presses Space on a password-protected PDF
- **THEN** the panel says the PDF is password protected and that Open unlocks it in a window
