# Spec Delta

## ADDED Requirements

### Requirement: The menu bar icon shows an available update

While a scheduled check has found an update the user hasn't seen yet, the menu bar icon SHALL show a small indigo dot, and the top of its menu SHALL read "Update to" with the version, opening the update window when chosen. Both SHALL go away once the user has seen the update window. While the icon also has a config problem or a missing permission to show, the red dot SHALL show instead of the indigo one.

#### Scenario: An update found in the background

- **WHEN** the daily check finds 0.3.0 while the user works in another app
- **THEN** the menu bar icon shows an indigo dot, and its menu starts with "Update to 0.3.0…"

#### Scenario: Opening it

- **WHEN** the user chooses "Update to 0.3.0…"
- **THEN** the update window for 0.3.0 opens, and the dot and the menu line go away

#### Scenario: Also missing Accessibility

- **WHEN** an update is waiting and Accessibility isn't granted
- **THEN** the icon shows the red dot, and its menu has both the update line and the Accessibility line
