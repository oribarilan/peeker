## MODIFIED Requirements

### Requirement: Dock icon and menus only while windows are open

Peeker SHALL show its Dock icon, its app menus and a place in Cmd+Tab while a document window or the Settings window is open, and hide all three once the last such window closes. The Peek panel SHALL NOT count as a window here, so pressing Space never makes a Dock icon appear.

#### Scenario: Opening and closing a file

- **WHEN** Peeker runs with no windows and the user opens a PDF, then closes it
- **THEN** the Dock icon and menus appear while the PDF is open and disappear when it closes, and the menu bar icon stays throughout

#### Scenario: Space in Finder

- **WHEN** Peeker runs with no windows and the user presses Space on a file in Finder
- **THEN** the panel shows the file and no Dock icon appears

### Requirement: The menu bar icon shows a missing Accessibility permission

While the Peek panel key is on and Accessibility isn't granted, the menu bar icon SHALL show the same red dot it shows for config problems, and its menu SHALL say that the Peek panel needs Accessibility, opening the Permissions pane when chosen. Both SHALL go away once Accessibility is granted or the key is turned off.

#### Scenario: First launch

- **WHEN** Peeker starts for the first time, before the user grants Accessibility
- **THEN** the menu bar icon shows a red dot, and its menu has a line about Accessibility that opens the Permissions pane

#### Scenario: Granting it

- **WHEN** the user grants Accessibility while the config has no problems
- **THEN** the red dot and the menu line go away within a few seconds
