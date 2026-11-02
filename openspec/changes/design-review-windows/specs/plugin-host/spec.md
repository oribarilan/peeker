## ADDED Requirements

### Requirement: The toolbar groups view commands and edit tools

A document window's toolbar SHALL show the plugin's view commands and its edit tools as separate groups, each on its own piece of glass, with the edit tools after the view commands.

#### Scenario: A PDF in Edit mode

- **WHEN** a PDF is in Edit mode
- **THEN** the toolbar shows the edit tools (Text Box, Sign, Highlight, Rotate Left, Rotate Right, Delete Page) as one group, apart from any view commands

### Requirement: A command can stay out of the toolbar

A plugin SHALL be able to mark a command as menu-only. Such a command SHALL be listed in its menu with its shortcut and SHALL have no toolbar button. Every zoom command (Zoom In, Zoom Out, Zoom to Fit, Actual Size) SHALL be menu-only.

#### Scenario: Zoom only in View

- **WHEN** an image is open
- **THEN** View lists Zoom In, Zoom Out, Zoom to Fit and Actual Size with their shortcuts, and the toolbar has no zoom buttons

#### Scenario: A PDF in Edit mode fits

- **WHEN** a PDF is in Edit mode in a window of the default size
- **THEN** every edit tool shows as a toolbar button, none in the overflow menu

### Requirement: Command buttons don't delay the first paint

When a file opens in a document window, its content SHALL show before the window adds the document's command buttons to the toolbar. Open With, the sidebar button and the Edit button SHALL be in the toolbar from the start.

#### Scenario: Opening a PDF

- **WHEN** the user opens a PDF
- **THEN** its pages show, and its tools join the toolbar in the next frame
