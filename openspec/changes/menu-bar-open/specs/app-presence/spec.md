# Spec Delta

## MODIFIED Requirements

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
