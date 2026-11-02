## MODIFIED Requirements

### Requirement: PDFs have an edit mode with Text Box, Sign and Highlight

A PDF opened in a window SHALL have an edit mode. Its tools SHALL be Text Box (Ctrl+Cmd+T), Sign and Highlight Selection (Ctrl+Cmd+H); Sign SHALL have no shortcut by default, leaving Ctrl+Cmd+S to Show/Hide Sidebar. Each tool's shortcut can be set or rebound like other plugin commands. Zoom In and Zoom Out SHALL work in both modes. The Space panel SHALL never offer Edit mode.

#### Scenario: The tools

- **WHEN** the user turns on Edit mode for a PDF
- **THEN** the toolbar offers Text Box, Sign and Highlight Selection

#### Scenario: Ctrl+Cmd+S in a PDF

- **WHEN** a PDF is in front and the config sets no shortcut for Sign
- **THEN** Ctrl+Cmd+S shows or hides the sidebar, and Tools > Sign shows no shortcut

### Requirement: Reordering pages by dragging needs macOS 27

On macOS 26, thumbnails SHALL NOT be draggable, in Edit mode or out of it; Rotate Left, Rotate Right and Delete Page SHALL keep working from the toolbar, the Tools menu and the thumbnails' menu. On macOS 27 and later, dragging SHALL reorder pages as before.

#### Scenario: Dragging on macOS 26

- **WHEN** on macOS 26 the user drags page 3's thumbnail above page 1 in Edit mode
- **THEN** no page moves, and Rotate and Delete Page still work on the selected thumbnails

#### Scenario: Dragging on macOS 27

- **WHEN** on macOS 27 the user drags page 3's thumbnail above page 1 in Edit mode
- **THEN** page 3 becomes page 1

### Requirement: Page commands

In a document window, the PDF plugin SHALL offer Rotate Left (Cmd+L), Rotate Right (Cmd+R) and Delete Page, in the Tools menu and a right-click menu on the thumbnails, with Rotate and Delete buttons in the toolbar in Edit mode. Run from the read view, they SHALL turn Edit mode on first. Each SHALL act on the selected thumbnails (Shift- and Cmd-click select several), or on the current page when none is selected. The Space panel SHALL have no page commands.

#### Scenario: Rotating selected pages
- **WHEN** pages 2 and 3 are selected in the sidebar and the user presses Cmd+R in Edit mode
- **THEN** both pages turn a quarter turn clockwise, and their thumbnails show it

#### Scenario: Current page when nothing is selected
- **WHEN** no thumbnail is selected, page 4 is the current page, and the user chooses Rotate Left
- **THEN** page 4 turns a quarter turn counterclockwise

#### Scenario: From the read view
- **WHEN** the user presses Cmd+L in the read view of an editable PDF
- **THEN** Edit mode turns on and the page rotates

### Requirement: A waiting tool shows itself

While Text Box, Sign or Highlight waits for its click or drag, its toolbar button SHALL show as selected and its Tools menu item SHALL be checked, and the pointer over a page SHALL show the tool: a crosshair for Text Box, a highlighter for Highlight, and the signature following it for Sign. Once the tool is used or dismissed, both SHALL go back.

#### Scenario: Arming the highlighter

- **WHEN** the user clicks Highlight in Edit mode
- **THEN** the Highlight button shows as selected and the pointer over the page becomes a highlighter, until the drag that highlights or Escape

#### Scenario: Placing a text box

- **WHEN** the user clicks Text Box and then clicks on the page
- **THEN** the button shows as selected with a crosshair pointer until that click, then neither
