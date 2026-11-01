# routing-and-config Specification

## Purpose

Which plugin opens a file, how the user turns plugins on and off and overrides that choice, and how the config file that holds those settings is read.

## Requirements

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

### Requirement: Saving the config applies it everywhere at once

The app SHALL watch the config file and apply a saved change within a second, without a restart and without a menu command, including when an editor saves by writing a new file and renaming it over the old one. A change SHALL reach open windows too: shortcuts, the quick-look key and routing for files opened next. A plugin turned off while its files are open SHALL keep those tabs. A config file that is a symlink SHALL keep working, and the app SHALL never replace the link.

#### Scenario: Rebinding while a PDF is open

- **WHEN** the user saves a new shortcut for Highlight Selection while a PDF window is open
- **THEN** the new shortcut works in that window right away

#### Scenario: Config from a dotfiles repo

- **WHEN** `config.json` is a symlink into a dotfiles repository and the user edits the target
- **THEN** the change applies, and the symlink is still a symlink

### Requirement: Mistakes in the config are reported, not guessed at

A config that isn't valid JSON SHALL change nothing: the settings in use stay as they were. Otherwise, an unknown key SHALL be skipped, and a value of the wrong kind or out of range SHALL leave that setting as it was, while the rest of the file applies. Each such problem SHALL be listed with where it is (such as `plugins.pdf.commands.highlight.shortcut`) and what's wrong.

#### Scenario: A typo in a key

- **WHEN** the config contains `{"plugins": {"image": {"enabeld": false}}}`
- **THEN** the image plugin stays enabled, and the problems list says `plugins.image.enabeld` is not a known setting

#### Scenario: Broken JSON

- **WHEN** the user saves the config with a missing closing brace
- **THEN** every setting stays as it was, and the problems list says the file isn't valid JSON

### Requirement: Editors autocomplete the config

At launch, the app SHALL write `schema.json`, a JSON Schema describing every key, next to `config.json` whenever its content differs from what's there, and SHALL never change `config.json` itself. A `"$schema"` key in the config SHALL be accepted and otherwise ignored.

#### Scenario: Autocomplete in an editor

- **WHEN** the config starts with `"$schema": "schema.json"` and the user opens it in an editor that supports JSON Schema
- **THEN** the editor offers the known keys and describes them

### Requirement: Users can turn plugins off

`"plugins": {"<id>": {"enabled": false}}` SHALL turn off that plugin. A disabled plugin SHALL never open files: it SHALL drop out of default routing, the Open With menu and the quick-look panel. No other plugin SHALL take its extensions.

#### Scenario: Disabling the image plugin

- **WHEN** the config contains `{"plugins": {"image": {"enabled": false}}}`
- **THEN** images no longer open in Peeker, and Space on an image falls through to Finder's Quick Look

#### Scenario: Disabling Markdown

- **WHEN** the Markdown plugin is off and the user opens a `.md` file
- **THEN** no plugin opens it by default, and Open With offers the other enabled plugins

### Requirement: Each extension opens in one plugin

A file SHALL open in the enabled plugin whose extension list contains the file's extension, compared without regard to case. For a symlink, the extension SHALL come from the file it points to. A file with no extension, including a dotfile such as `.zshrc`, SHALL match the list entry `noExtension`. A folder SHALL match nothing. When no enabled plugin lists the extension, no plugin SHALL open the file. No two plugins SHALL list the same extension by default.

#### Scenario: Markdown file

- **WHEN** the user opens `notes.md` and every plugin has its default list
- **THEN** Markdown opens it

#### Scenario: Extension in capitals

- **WHEN** the user opens `README.MD`
- **THEN** Markdown opens it, as for `.md`

#### Scenario: Dotfile

- **WHEN** the user presses Space on `.zshrc` in Finder
- **THEN** Plain Text shows it, because its default list has `noExtension`

#### Scenario: Extension no plugin lists

- **WHEN** the user opens `movie.mp4`
- **THEN** no plugin opens it, and the window says no enabled plugin opens this file

#### Scenario: Space on a folder

- **WHEN** the user presses Space on a folder in Finder
- **THEN** Finder's Quick Look shows it

### Requirement: The config can change a plugin's extensions

`"plugins": {"<id>": {"extensions": [...]}}` SHALL replace that plugin's default list with the given list. A missing key SHALL keep the default list, and an empty list SHALL mean the plugin opens nothing. An entry SHALL be an extension without its dot (a leading dot is ignored) or `noExtension`. An entry that's empty or contains a dot, a slash or a space SHALL be listed as a problem and skipped.

#### Scenario: Adding an extension

- **WHEN** the config sets `plugins.text.extensions` to the default list plus `nginx`
- **THEN** `site.nginx` opens in Plain Text

#### Scenario: Moving an extension

- **WHEN** the config sets `plugins.markdown.extensions` to `["markdown"]` and adds `md` to `plugins.text.extensions`
- **THEN** `.md` files open in Plain Text and `.markdown` files in Markdown

#### Scenario: Bad entry

- **WHEN** `plugins.text.extensions` contains `"tar.gz"`
- **THEN** that entry is skipped, the problems list names `plugins.text.extensions`, and the rest of the list applies

### Requirement: An extension in two lists stays with one plugin

When the config gives the same extension to more than one plugin, the extension SHALL stay with the plugin whose default list has it, or, if none does, with the first of them in sidebar order (Image, PDF, Markdown, Plain Text). The other lists SHALL drop it, and each one SHALL be listed as a problem naming the plugin that kept it.

#### Scenario: md added to Plain Text but left in Markdown

- **WHEN** the config adds `md` to `plugins.text.extensions` and leaves Markdown's list at its default
- **THEN** `.md` files still open in Markdown, and the problems list says `md` in `plugins.text.extensions` belongs to Markdown

### Requirement: Open With switches the plugin for one tab

Each document window SHALL show an Open With control listing every enabled plugin, the one whose list has the file's extension first. Choosing another plugin SHALL reopen that tab with it; a plugin that can't read the file SHALL show its error in the tab. Unsaved edits SHALL be resolved first (Save, Don't Save or Cancel), and cancelling SHALL leave the tab and the control unchanged.

#### Scenario: View Markdown as plain text

- **WHEN** the user picks Plain Text in Open With on a Markdown tab with no unsaved edits
- **THEN** the tab reopens showing the Markdown source in the text plugin

#### Scenario: A plugin that can't read the file

- **WHEN** the user picks Image in Open With on a Markdown tab
- **THEN** the tab says the file isn't a readable image, and Open With can switch it back

### Requirement: Plugin command shortcuts can be rebound

`"plugins": {"<id>": {"commands": {"<command>": {"shortcut": "<shortcut>"}}}}` (for example `cmd+shift+h`) SHALL replace that command's default shortcut. A shortcut that can't be parsed SHALL be listed as a problem and the default kept.

#### Scenario: Rebinding highlight

- **WHEN** the config sets `plugins.pdf.commands.highlight.shortcut` to `cmd+shift+h`
- **THEN** Cmd+Shift+H highlights the selection in PDFs, including ones already open

### Requirement: The app is an alternate handler for its formats

The app SHALL declare the file types of every extension on the plugins' default lists, so it appears in Finder's Open With menu for them and can be chosen as the default app, without claiming to be the default on install. Extensions added only in the config SHALL open in Peeker but need not appear in Finder's Open With menu.

#### Scenario: Fresh install

- **WHEN** the app is installed and the user hasn't changed any default
- **THEN** files keep opening in their previous apps, and Peeker appears under Open With
