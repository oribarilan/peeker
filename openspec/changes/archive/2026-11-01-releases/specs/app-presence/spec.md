## MODIFIED Requirements

### Requirement: A menu bar icon while Peeker runs

While Peeker runs, it SHALL show an icon in the menu bar. Its menu SHALL offer Settings…, Check for Updates…, Open at Login (with a checkmark when on) and Quit Peeker.

#### Scenario: Launched at login

- **WHEN** Peeker starts at login with no files to open
- **THEN** its icon appears in the menu bar and nothing else appears on screen

#### Scenario: Checking for updates with no windows open

- **WHEN** no window is open and the user chooses Check for Updates… from the menu bar icon
- **THEN** Peeker checks right away and says what it found
