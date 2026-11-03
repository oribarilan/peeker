## MODIFIED Requirements

### Requirement: Config is a JSON file

The app SHALL read its settings from `~/.config/peeker/config.json`, or from the path in `$PEEKER_CONFIG` when set. The file SHALL be a JSON object with sections `peekPanel`, `plugins` (keyed by plugin id) and `updates` (`check`, true or false), and the strings `textTheme`, `appearance` and `textAppearance`. A missing file or a missing key SHALL mean that setting's default. The old `~/.config/peeker/config` dotfile SHALL NOT be read.

#### Scenario: No config file

- **WHEN** no `config.json` exists
- **THEN** every plugin is enabled with its default extension list, Space opens the Peek panel, Peeker checks for updates daily, the text theme is System, the app follows the Mac's appearance and text matches the app

#### Scenario: Only one setting

- **WHEN** `config.json` is `{"plugins": {"image": {"enabled": false}}}`
- **THEN** images no longer open in Peeker and every other setting keeps its default

#### Scenario: Turning update checks off

- **WHEN** the user saves `{"updates": {"check": false}}`
- **THEN** Peeker stops checking for updates automatically, without a restart

#### Scenario: The key's old name

- **WHEN** `config.json` still has a `quickLook` section
- **THEN** it's listed as an unknown key, and the Peek panel uses its default key

#### Scenario: Choosing a theme in the file

- **WHEN** the user saves `{"textTheme": "tokyo-night"}`
- **THEN** Markdown and text windows take the Tokyo Night theme, without a restart

#### Scenario: Choosing appearances in the file

- **WHEN** the user saves `{"appearance": "dark", "textAppearance": "light"}`
- **THEN** Peeker's windows turn dark and the text in Markdown and text files shows its theme's light variant, without a restart

## ADDED Requirements

### Requirement: An unknown appearance is reported

An `appearance` other than `system`, `light` or `dark`, or a `textAppearance` other than `app`, `light` or `dark`, or either one not a string, SHALL be listed as a config problem naming the allowed values, and that setting's default SHALL be used. The schema written next to the config SHALL list the values.

#### Scenario: A misspelled appearance

- **WHEN** the config says `"appearance": "night"`
- **THEN** the problems list says `appearance` must be one of system, light or dark, and the app follows the Mac
