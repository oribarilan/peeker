# app-presence Specification

## Purpose

How Peeker shows itself on the Mac: a menu bar icon while it runs, and a Dock icon with full menus only while there are files open to work with.

## Requirements

### Requirement: A menu bar icon while Peeker runs

While Peeker runs, it SHALL show an icon in the menu bar: the system's viewfinder symbol, four corner marks, drawn in the menu bar's own color so it follows light and dark menu bars like other menu bar icons. Its menu SHALL offer Open…, Settings…, Check for Updates…, Open at Login (with a checkmark when on) and Quit Peeker. Open… SHALL work as File > Open… does.

#### Scenario: Launched at login

- **WHEN** Peeker starts at login with no files to open
- **THEN** its viewfinder icon appears in the menu bar and nothing else appears on screen

#### Scenario: Checking for updates with no windows open

- **WHEN** no window is open and the user chooses Check for Updates… from the menu bar icon
- **THEN** Peeker checks right away and says what it found

#### Scenario: Opening a file with no windows open

- **WHEN** no window is open and the user chooses Open… from the menu bar icon
- **THEN** the Open panel comes up in front with the keyboard, and the file chosen opens in a window

#### Scenario: Dark menu bar

- **WHEN** the menu bar is dark
- **THEN** the viewfinder icon is drawn light, like the system's own menu bar icons

### Requirement: The menu bar icon shows config problems

While the config has problems, the menu bar icon SHALL show a small red dot, and its menu SHALL say how many problems there are, opening the Config file pane when chosen. The dot SHALL go away once a saved config has no problems.

#### Scenario: A bad value

- **WHEN** the user saves a config with an unparseable shortcut
- **THEN** the menu bar icon shows a red dot and its menu reads "Config has 1 problem"

### Requirement: Dock icon and menus only while windows are open

Peeker SHALL show its Dock icon, its app menus and a place in Cmd+Tab while an Editor window, the Settings window or the Open panel is open, and hide all three once the last of them closes. The Peek panel SHALL NOT count as a window here, so pressing Space never makes a Dock icon appear.

#### Scenario: Opening and closing a file

- **WHEN** Peeker runs with no windows and the user opens a PDF, then closes it
- **THEN** the Dock icon and menus appear while the PDF is open and disappear when it closes, and the menu bar icon stays throughout

#### Scenario: Space in Finder

- **WHEN** Peeker runs with no windows and the user presses Space on a file in Finder
- **THEN** the panel shows the file and no Dock icon appears

#### Scenario: Cancelling the Open panel

- **WHEN** Peeker runs with no windows, the user chooses Open… from the menu bar icon and clicks Cancel
- **THEN** the Dock icon shows while the panel does and goes away after Cancel

### Requirement: The menu bar icon shows a missing Accessibility permission

While the Peek panel key is on and Accessibility isn't granted, the menu bar icon SHALL show the same red dot it shows for config problems, and its menu SHALL say that the Peek panel needs Accessibility, opening the Permissions pane when chosen. Both SHALL go away once Accessibility is granted or the key is turned off.

#### Scenario: First launch

- **WHEN** Peeker starts for the first time, before the user grants Accessibility
- **THEN** the menu bar icon shows a red dot, and its menu has a line about Accessibility that opens the Permissions pane

#### Scenario: Granting it

- **WHEN** the user grants Accessibility while the config has no problems
- **THEN** the red dot and the menu line go away within a few seconds

### Requirement: Peeker has its own app icon

Peeker SHALL have its own app icon, wherever macOS shows one (the Dock, Finder, Get Info, the About panel, Login Items, Open With menus and Cmd+Tab): four rounded viewfinder corners around a stack of three cards, the top card tilted to the right, in indigo. The icon SHALL have a dark appearance and SHALL follow the system's Clear and Tinted icon styles.

#### Scenario: In the Dock

- **WHEN** the user opens a file in Peeker
- **THEN** the Dock shows the indigo Framed Lift icon, not the generic app icon

#### Scenario: In Open With

- **WHEN** the user right-clicks a PDF in Finder and opens the Open With submenu
- **THEN** Peeker is listed with its own icon

#### Scenario: Dark icon style

- **WHEN** the system's icon style is Dark
- **THEN** Peeker's icon has a dark background with the cards and corners lit in indigo

#### Scenario: Tinted icon style

- **WHEN** the system's icon style is Tinted
- **THEN** Peeker's icon takes the tint like other apps' icons, keeping the corners and the tilted card recognizable

### Requirement: Peeker's accent color is indigo

When the system accent color is Multicolor, Peeker's buttons, switches, selections and links SHALL use indigo: `#4a52d4` in light appearance and `#7d82e0` in dark. When the user has chosen any other system accent, Peeker SHALL use that one.

#### Scenario: Multicolor accent

- **WHEN** the system accent is Multicolor and the user opens Settings
- **THEN** the selected pane in the sidebar and the switches that are on are indigo

#### Scenario: A chosen accent

- **WHEN** the system accent is Green and the user opens Settings
- **THEN** the selected pane and the switches that are on are green

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
