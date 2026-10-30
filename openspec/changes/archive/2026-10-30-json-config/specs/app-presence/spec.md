# Spec Delta

## Purpose

How Peeker shows itself on the Mac: a menu bar icon while it runs, and a Dock icon with full menus only while there are files open to work with.

## ADDED Requirements

### Requirement: A menu bar icon while Peeker runs

While Peeker runs, it SHALL show an icon in the menu bar. Its menu SHALL offer Settings…, Open at Login (with a checkmark when on) and Quit Peeker.

#### Scenario: Launched at login

- **WHEN** Peeker starts at login with no files to open
- **THEN** its icon appears in the menu bar and nothing else appears on screen

### Requirement: The menu bar icon shows config problems

While the config has problems, the menu bar icon SHALL show a small red dot, and its menu SHALL say how many problems there are, opening the Config file pane when chosen. The dot SHALL go away once a saved config has no problems.

#### Scenario: A bad value

- **WHEN** the user saves a config with an unparseable shortcut
- **THEN** the menu bar icon shows a red dot and its menu reads "Config has 1 problem"

### Requirement: Dock icon and menus only while windows are open

Peeker SHALL show its Dock icon, its app menus and a place in Cmd+Tab while a document window or the Settings window is open, and hide all three once the last such window closes. The quick-look panel SHALL NOT count as a window here, so pressing Space never makes a Dock icon appear.

#### Scenario: Opening and closing a file

- **WHEN** Peeker runs with no windows and the user opens a PDF, then closes it
- **THEN** the Dock icon and menus appear while the PDF is open and disappear when it closes, and the menu bar icon stays throughout

#### Scenario: Space in Finder

- **WHEN** Peeker runs with no windows and the user presses Space on a file in Finder
- **THEN** the panel shows the file and no Dock icon appears
