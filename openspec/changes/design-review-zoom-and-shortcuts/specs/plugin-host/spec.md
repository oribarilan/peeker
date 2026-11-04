## MODIFIED Requirements

### Requirement: Plugins draw their own content

A plugin SHALL provide the native views for its file's content and its sidebar panels, and the tools it offers. The host SHALL provide the window, tabs, toolbar, Open With and the menus that list plugin tools (View and Tools). Plugins that zoom SHALL use Cmd+= and Cmd+- for it, and Cmd+0 for Actual Size and Cmd+9 for Zoom to Fit wherever they offer those.

#### Scenario: Highlighting a PDF selection

- **WHEN** the user runs Highlight Selection on a PDF
- **THEN** the PDF plugin's own view draws the highlight

#### Scenario: The same zoom keys in every plugin

- **WHEN** the user presses Cmd+0 in an image, a PDF, a text file and a Markdown window in turn
- **THEN** each shows its content at actual size, the way its plugin defines it
