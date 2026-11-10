## ADDED Requirements

### Requirement: The Peek panel shows its file in Finder

The Peek panel SHALL have a folder button left of Open in Peeker in its title bar, and its button's menu SHALL end with Show in Finder, after Other…. Either SHALL close the panel and open a Finder window with the file selected, bringing Finder forward. Neither SHALL open the file in any app.

#### Scenario: The folder button

- **WHEN** the panel shows report.pdf and the user clicks the folder button
- **THEN** the panel closes and Finder shows report.pdf selected

#### Scenario: The menu item

- **WHEN** the user opens the arrow beside Open in Peeker and chooses Show in Finder
- **THEN** the panel closes and Finder shows the file selected
