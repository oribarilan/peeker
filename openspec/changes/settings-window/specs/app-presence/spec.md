## ADDED Requirements

### Requirement: The menu bar icon shows a missing Accessibility permission

While the quick-look key is on and Accessibility isn't granted, the menu bar icon SHALL show the same red dot it shows for config problems, and its menu SHALL say that Space in Finder needs Accessibility, opening the Permissions pane when chosen. Both SHALL go away once Accessibility is granted or the key is turned off.

#### Scenario: First launch

- **WHEN** Peeker starts for the first time, before the user grants Accessibility
- **THEN** the menu bar icon shows a red dot, and its menu has a line about Accessibility that opens the Permissions pane

#### Scenario: Granting it

- **WHEN** the user grants Accessibility while the config has no problems
- **THEN** the red dot and the menu line go away within a few seconds
