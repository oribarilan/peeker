## ADDED Requirements

### Requirement: Single-key shortcuts for edit tools

An edit tool's shortcut MAY be a single key with no Command, Option or Control. Such a shortcut SHALL run its tool only while the document is in Edit mode and no text field, text view or text box has keyboard focus; otherwise the key SHALL go where it would have gone. The Settings window's recorder SHALL accept single keys for edit tools and keep requiring a modifier for other commands.

#### Scenario: A letter in Edit mode
- **WHEN** an image is in Edit mode and the user presses C
- **THEN** cropping starts

#### Scenario: A letter in the read view
- **WHEN** an image is in the read view and the user presses C
- **THEN** nothing happens and Edit mode stays off

#### Scenario: Typing
- **WHEN** a text field has focus in Edit mode and the user types "c"
- **THEN** the "c" goes into the field

#### Scenario: Recording a single key
- **WHEN** the user records C for an edit tool in Settings
- **THEN** it's accepted; for a command that isn't an edit tool it's refused as before
