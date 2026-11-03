## MODIFIED Requirements

### Requirement: Config is a JSON file

The app SHALL read its settings from `~/.config/peeker/config.json`, or from the path in `$PEEKER_CONFIG` when set. The file SHALL be a JSON object with sections `peekPanel`, `plugins` (keyed by plugin id) and `updates` (`check`, true or false), and a `textTheme` string naming the text theme. A missing file or a missing key SHALL mean that setting's default. The old `~/.config/peeker/config` dotfile SHALL NOT be read.

#### Scenario: No config file

- **WHEN** no `config.json` exists
- **THEN** every plugin is enabled with its default extension list, Space opens the Peek panel, Peeker checks for updates daily, and the text theme is System

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

## ADDED Requirements

### Requirement: An unknown text theme is reported

A `textTheme` that isn't one of `system`, `paper`, `slate`, `graphite`, `ink`, `catppuccin`, `tokyo-night` or `high-contrast`, or isn't a string, SHALL be listed as a config problem naming the themes Peeker has, and the System theme SHALL be used. The schema written next to the config SHALL list the names, so editors can autocomplete them.

#### Scenario: A misspelled theme

- **WHEN** the config says `"textTheme": "tokyonight"`
- **THEN** the problems list says `textTheme` isn't a theme Peeker has and names the eight, and windows use System
