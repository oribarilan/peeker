## MODIFIED Requirements

### Requirement: The app can open at login

Open at Login, in the menu bar icon's menu, SHALL register or unregister the app as a login item, because the panel only works while the app runs. A failure SHALL be reported in an alert.

#### Scenario: Turning on Open at Login

- **WHEN** the user chooses Open at Login
- **THEN** Peeker starts at the next login and the panel works without launching it by hand
