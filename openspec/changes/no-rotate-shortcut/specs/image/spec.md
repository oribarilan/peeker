## MODIFIED Requirements

### Requirement: Rotate & Resize panel

Rotate & Resize SHALL have no default key; it opens from its toolbar button or the Tools menu, and a key can be set in Settings or the config. It SHALL open a panel just below the toolbar, with buttons to rotate left, rotate right, flip horizontally and flip vertically (also L, R, H and V while it's open), width and height fields in pixels or percent, and an aspect lock, on by default. Applying a new size SHALL resize the image as one edit; enlarging SHALL be allowed. Escape SHALL close the panel.

#### Scenario: Turning twice
- **WHEN** the user clicks Rotate & Resize, then presses R twice
- **THEN** the image is upside down, as two edits

#### Scenario: Resizing to half
- **WHEN** the user sets the width to 50 percent with the lock on and applies it
- **THEN** both sides are half their size

#### Scenario: Toolbar stays clear
- **WHEN** the user opens Rotate & Resize from the toolbar button or the Tools menu
- **THEN** the panel's top edge is below the toolbar, and every toolbar item stays visible and clickable

#### Scenario: No default key
- **WHEN** the user presses Cmd+R in an image window with the default config
- **THEN** Rotate & Resize doesn't open
