## MODIFIED Requirements

### Requirement: Settings opens from the menu bar and the app menu

Settings… in the menu bar icon's menu and in the app menu (Cmd+,) SHALL open the Settings window, or bring it forward when it's already open. Launching Peeker by hand with no file to open and no window to restore, and reopening it while it runs with no window showing, SHALL do the same; a launch at login SHALL NOT. Opening it SHALL show the Dock icon and menus like any other window.

#### Scenario: Opening Settings with no files open

- **WHEN** no document is open and the user chooses Settings… from the menu bar icon
- **THEN** the Settings window comes forward

#### Scenario: Launching from Spotlight

- **WHEN** Peeker isn't running and the user opens it from Spotlight
- **THEN** the Settings window opens next to the menu bar icon

#### Scenario: At login

- **WHEN** Peeker starts at login with no files to open
- **THEN** only the menu bar icon appears

#### Scenario: Windows to restore

- **WHEN** Peeker quit with a document open and the user launches it from Spotlight
- **THEN** the document's window comes back and Settings doesn't open
