# Spec Delta

## MODIFIED Requirements

### Requirement: Config is a JSON file

The app SHALL read its settings from `~/.config/peeker/config.json`, or from the path in `$PEEKER_CONFIG` when set. The file SHALL be a JSON object with sections `peekPanel`, `plugins` (keyed by plugin id) and `updates` (`automatic` and `showWhatsNew`), the strings `textTheme`, `appearance` and `textAppearance`, and the boolean `showShortcuts`. A missing file or a missing key SHALL mean that setting's default. The old `~/.config/peeker/config` dotfile SHALL NOT be read.

#### Scenario: No config file

- **WHEN** no `config.json` exists
- **THEN** every plugin is enabled with its default extension list, Space opens the Peek panel, Peeker checks for updates daily and asks before installing, shows what's new after an update, the text theme is System, the app follows the Mac's appearance, text matches the app, and the toolbar shows shortcut captions

#### Scenario: Only one setting

- **WHEN** `config.json` is `{"plugins": {"image": {"enabled": false}}}`
- **THEN** images no longer open in Peeker and every other setting keeps its default

#### Scenario: Turning update checks off

- **WHEN** the user saves `{"updates": {"automatic": "off"}}`
- **THEN** Peeker stops checking for updates automatically, without a restart

#### Scenario: The update key's old name

- **WHEN** `config.json` has `{"updates": {"check": false}}`
- **THEN** `updates.check` is listed as an unknown key, and Peeker checks daily as by default

#### Scenario: The key's old name

- **WHEN** `config.json` still has a `quickLook` section
- **THEN** it's listed as an unknown key, and the Peek panel uses its default key

#### Scenario: Choosing a theme in the file

- **WHEN** the user saves `{"textTheme": "tokyo-night"}`
- **THEN** Markdown and text windows take the Tokyo Night theme, without a restart

#### Scenario: Choosing appearances in the file

- **WHEN** the user saves `{"appearance": "dark", "textAppearance": "light"}`
- **THEN** Peeker's windows turn dark and the text in Markdown and text files shows its theme's light variant, without a restart

#### Scenario: Hiding shortcut captions

- **WHEN** the user saves `{"showShortcuts": false}`
- **THEN** the toolbar's key captions go away in every open window, without a restart
