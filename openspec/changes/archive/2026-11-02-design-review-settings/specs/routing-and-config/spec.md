## MODIFIED Requirements

### Requirement: Config is a JSON file

The app SHALL read its settings from `~/.config/peeker/config.json`, or from the path in `$PEEKER_CONFIG` when set. The file SHALL be a JSON object with sections `peekPanel`, `plugins` (keyed by plugin id) and `updates` (`check`, true or false). A missing file or a missing key SHALL mean that setting's default. The old `~/.config/peeker/config` dotfile SHALL NOT be read.

#### Scenario: No config file

- **WHEN** no `config.json` exists
- **THEN** every plugin is enabled with its default extension list, Space opens the Peek panel, and Peeker checks for updates daily

#### Scenario: Only one setting

- **WHEN** `config.json` is `{"plugins": {"image": {"enabled": false}}}`
- **THEN** images no longer open in Peeker and every other setting keeps its default

#### Scenario: Turning update checks off

- **WHEN** the user saves `{"updates": {"check": false}}`
- **THEN** Peeker stops checking for updates automatically, without a restart

#### Scenario: The key's old name

- **WHEN** `config.json` still has a `quickLook` section
- **THEN** it's listed as an unknown key, and the Peek panel uses its default key

### Requirement: Saving the config applies it everywhere at once

The app SHALL watch the config file and apply a saved change within a second, without a restart and without a menu command, including when an editor saves by writing a new file and renaming it over the old one. A change SHALL reach open windows too: shortcuts, the Peek panel key and routing for files opened next. A plugin turned off while its files are open SHALL keep those tabs. A config file that is a symlink SHALL keep working, and the app SHALL never replace the link.

#### Scenario: Rebinding while a PDF is open

- **WHEN** the user saves a new shortcut for Highlight Selection while a PDF window is open
- **THEN** the new shortcut works in that window right away

#### Scenario: Config from a dotfiles repo

- **WHEN** `config.json` is a symlink into a dotfiles repository and the user edits the target
- **THEN** the change applies, and the symlink is still a symlink

### Requirement: Users can turn plugins off

`"plugins": {"<id>": {"enabled": false}}` SHALL turn off that plugin. A disabled plugin SHALL never open files: it SHALL drop out of default routing, the Open With menu and the Peek panel. No other plugin SHALL take its extensions.

#### Scenario: Disabling the image plugin

- **WHEN** the config contains `{"plugins": {"image": {"enabled": false}}}`
- **THEN** images no longer open in Peeker, and Space on an image falls through to Finder's Quick Look

#### Scenario: Disabling Markdown

- **WHEN** the Markdown plugin is off and the user opens a `.md` file
- **THEN** no plugin opens it by default, and Open With offers the other enabled plugins
