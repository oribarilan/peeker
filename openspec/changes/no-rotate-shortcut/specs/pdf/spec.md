## MODIFIED Requirements

### Requirement: Page tools

In the Editor, the PDF plugin SHALL offer Rotate Left, Rotate Right and Delete Page, with no default keys, in the toolbar, the Tools menu and a right-click menu on the thumbnails. Each SHALL act on the selected thumbnails (Shift- and Cmd-click select several), or on the current page when none is selected. The Peek panel SHALL have no page tools.

#### Scenario: Rotating selected pages
- **WHEN** pages 2 and 3 are selected in the sidebar and the user chooses Rotate Right
- **THEN** both pages turn a quarter turn clockwise, and their thumbnails show it

#### Scenario: Current page when nothing is selected
- **WHEN** no thumbnail is selected, page 4 is the current page, and the user chooses Rotate Left
- **THEN** page 4 turns a quarter turn counterclockwise
