# Spec Delta

## ADDED Requirements

### Requirement: Page edits move into place

In a window, a rotated page SHALL turn into its new position, a deleted page SHALL shrink and fade away, and a page brought back by Undo SHALL grow into place, each in about 0.2 seconds. The edit SHALL be applied at once, so nothing waits for the motion. Nothing SHALL move while Reduce Motion is on, for pages not on screen, or for edits applied while a document opens.

#### Scenario: Rotating a page

- **WHEN** the user rotates page 2 to the right in the Editor
- **THEN** page 2 turns a quarter turn clockwise into its new shape, and the page is already rotated when the motion starts

#### Scenario: Deleting and undoing

- **WHEN** the user deletes page 3 and then chooses Undo
- **THEN** page 3 shrinks away, and on Undo it grows back into place

#### Scenario: Reduce Motion

- **WHEN** Reduce Motion is on and the user rotates or deletes a page
- **THEN** the page changes at once, with no motion
