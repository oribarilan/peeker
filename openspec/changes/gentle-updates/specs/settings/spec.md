# Spec Delta

## MODIFIED Requirements

### Requirement: General shows the update controls

The General pane SHALL show an Automatic updates pop-up bound to `updates.automatic` with the choices Off, Check and Ask, and Download and Install; a "Show what's new after updating" checkbox bound to `updates.showWhatsNew`; a Check Now button; and the version of Peeker running. Changing either control SHALL apply at once and rewrite the config file like any other change in Settings; Check Now SHALL check right away whatever the pop-up says.

#### Scenario: Opting out

- **WHEN** the user picks Off in Automatic updates
- **THEN** `config.json` has `"updates": {"automatic": "off"}` and automatic checks stop

#### Scenario: Installing by itself

- **WHEN** the user picks Download and Install
- **THEN** `config.json` has `"updates": {"automatic": "download"}`, and the next update found downloads and installs without asking

#### Scenario: No what's-new window

- **WHEN** the user clears "Show what's new after updating"
- **THEN** `config.json` has `"updates": {"showWhatsNew": false}`, and the next update shows no what's-new window

#### Scenario: Checking by hand while opted out

- **WHEN** automatic updates are Off and the user clicks Check Now
- **THEN** Peeker checks right away and says what it found
