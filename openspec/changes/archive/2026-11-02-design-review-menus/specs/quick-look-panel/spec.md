## MODIFIED Requirements

### Requirement: The app can open at login

Open at Login, in the menu bar icon's menu and in Settings' Permissions pane, SHALL register or unregister the app as a login item, because the panel only works while the app runs. The app menu SHALL NOT have it. A failure SHALL be reported in an alert.

#### Scenario: Turning on Open at Login

- **WHEN** the user chooses Open at Login
- **THEN** Peeker starts at the next login and the panel works without launching it by hand

#### Scenario: The app menu

- **WHEN** a document window is open and the user opens the Peeker menu
- **THEN** it has Settings… but no Open at Login
