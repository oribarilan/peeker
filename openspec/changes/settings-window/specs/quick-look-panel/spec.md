## MODIFIED Requirements

### Requirement: The app asks for the permissions the panel needs

The panel needs Accessibility (to see the key system-wide) and Automation for Finder (to read the selection). Without Accessibility, the app SHALL ask once, then start watching the key as soon as it's granted, without a relaunch. The Permissions pane in Settings SHALL show both permissions' status and lead to where each is granted.

#### Scenario: Granting Accessibility later

- **WHEN** the user grants Accessibility after launching the app
- **THEN** Space in Finder starts working within a few seconds, without restarting Peeker

#### Scenario: Finding out why Space does nothing

- **WHEN** Space in Finder does nothing and the user opens the Permissions pane
- **THEN** the pane shows which permission is missing, with Grant Access next to it

### Requirement: The app can open at login

Open at Login, in the menu bar icon's menu and in Settings' Permissions pane, SHALL register or unregister the app as a login item, because the panel only works while the app runs. The app menu SHALL NOT have it. A failure SHALL be reported in an alert.

#### Scenario: Turning on Open at Login

- **WHEN** the user chooses Open at Login
- **THEN** Peeker starts at the next login and the panel works without launching it by hand

#### Scenario: The app menu

- **WHEN** a document window is open and the user opens the Peeker menu
- **THEN** it has Settings… but no Open at Login
