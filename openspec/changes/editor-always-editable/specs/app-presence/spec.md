## MODIFIED Requirements

### Requirement: Dock icon and menus only while windows are open

Peeker SHALL show its Dock icon, its app menus and a place in Cmd+Tab while an Editor window or the Settings window is open, and hide all three once the last such window closes. The Peek panel SHALL NOT count as a window here, so pressing Space never makes a Dock icon appear.

#### Scenario: Opening and closing a file

- **WHEN** Peeker runs with no windows and the user opens a PDF, then closes it
- **THEN** the Dock icon and menus appear while the PDF is open and disappear when it closes, and the menu bar icon stays throughout

#### Scenario: Space in Finder

- **WHEN** Peeker runs with no windows and the user presses Space on a file in Finder
- **THEN** the panel shows the file and no Dock icon appears
