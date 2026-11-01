## ADDED Requirements

### Requirement: General shows the update controls

The General pane SHALL show a "Check for updates automatically" checkbox bound to `updates.check`, a Check Now button and the version of Peeker running. Changing the checkbox SHALL apply at once and rewrite the config file like any other change in Settings; Check Now SHALL check right away whether the checkbox is on or off.

#### Scenario: Opting out

- **WHEN** the user clears "Check for updates automatically"
- **THEN** `config.json` has `"updates": {"check": false}` and automatic checks stop

#### Scenario: Checking by hand while opted out

- **WHEN** automatic checks are off and the user clicks Check Now
- **THEN** Peeker checks right away and says what it found
