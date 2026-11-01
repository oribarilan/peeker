## MODIFIED Requirements

### Requirement: Config is a JSON file

The app SHALL read its settings from `~/.config/peeker/config.json`, or from the path in `$PEEKER_CONFIG` when set. The file SHALL be a JSON object with sections `quickLook`, `plugins` (keyed by plugin id) and `updates` (`check`, true or false). A missing file or a missing key SHALL mean that setting's default. The old `~/.config/peeker/config` dotfile SHALL NOT be read.

#### Scenario: No config file

- **WHEN** no `config.json` exists
- **THEN** every plugin is enabled with its default extension list, Space opens the quick-look panel, and Peeker checks for updates daily

#### Scenario: Only one setting

- **WHEN** `config.json` is `{"plugins": {"image": {"enabled": false}}}`
- **THEN** images no longer open in Peeker and every other setting keeps its default

#### Scenario: Turning update checks off

- **WHEN** the user saves `{"updates": {"check": false}}`
- **THEN** Peeker stops checking for updates automatically, without a restart
