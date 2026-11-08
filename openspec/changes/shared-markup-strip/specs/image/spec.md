## MODIFIED Requirements

### Requirement: Markup tools

An image window's toolbar SHALL have Markup (M), which shows a strip under the toolbar with Arrow (A), Line (L), Box (B, an ellipse with Option held), Text (T), Pixelate (X), Steps (N), Pen (P), Marker (H) and Spotlight (S), each also reachable by its key, which the strip shows beside the tool's icon. Markup SHALL be greyed out with the reason wherever editing is, and absent from the Peek panel.

#### Scenario: Pointing at a button

- **WHEN** the user presses M, then A, and drags from an empty spot to a button in a screenshot
- **THEN** an arrow in the current color points at the button

#### Scenario: Keys on the strip

- **WHEN** the strip shows
- **THEN** each tool's key letter shows beside its icon

#### Scenario: A straight line

- **WHEN** the user presses L and drags across a table row
- **THEN** a straight line without a head runs along the row
