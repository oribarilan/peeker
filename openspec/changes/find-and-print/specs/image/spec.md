## ADDED Requirements

### Requirement: Print an image

Printing an image SHALL print it on one page, centered, at its own size as given by its pixel dimensions and resolution (72 pixels per inch when the file states none), shrunk to fit the printable area when larger and never enlarged. The print panel SHALL start in landscape for an image wider than it is tall and in portrait otherwise, and the image SHALL print upright as it is shown.

#### Scenario: A large photo
- **WHEN** the user prints a 4000 × 3000 pixel photo
- **THEN** the print panel starts in landscape and the photo fills the printable area's width or height, centered

#### Scenario: A small icon
- **WHEN** the user prints a 64 × 64 pixel icon with no resolution set
- **THEN** it prints centered at 64 × 64 points, not enlarged

#### Scenario: A rotated photo
- **WHEN** the photo's file says it was taken rotated
- **THEN** it prints upright, as the window shows it
