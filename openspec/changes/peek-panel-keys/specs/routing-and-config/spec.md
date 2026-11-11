## ADDED Requirements

### Requirement: The config sets the Peek panel's button keys

The config SHALL take `peekPanel.openKey` and `peekPanel.showInFinderKey`, each a key written as other keys are or `"off"`, defaulting to `"cmd+o"` and `"cmd+r"`. A key without Command, Option or Control, one Peeker can't read, or one equal to the Peek panel key or the other action's key SHALL be reported as a problem at its path and leave that action's default in place.

#### Scenario: Turning a key off

- **WHEN** the config has `"peekPanel": {"showInFinderKey": "off"}`
- **THEN** Command-R does nothing special while the panel is up, and the folder button shows no key

#### Scenario: A bare key

- **WHEN** the config has `"peekPanel": {"openKey": "o"}`
- **THEN** the config reports a problem at peekPanel.openKey and Command-O still opens the file
