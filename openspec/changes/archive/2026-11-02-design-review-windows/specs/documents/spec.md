## ADDED Requirements

### Requirement: Document windows have a minimum size

A document window SHALL NOT shrink below about 480 by 320 points.

#### Scenario: Shrinking a window

- **WHEN** the user drags a document window's corner inward as far as it goes
- **THEN** the window stops at its minimum size, with the toolbar and content still shown
