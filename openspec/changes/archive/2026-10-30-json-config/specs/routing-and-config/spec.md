# Spec Delta

## ADDED Requirements

### Requirement: Config is a JSON file

The app SHALL read its settings from `~/.config/peeker/config.json`, or from the path in `$PEEKER_CONFIG` when set. The file SHALL be a JSON object with sections: `quickLook`, `plugins` (keyed by plugin id) and `open` (keyed by extension). A missing file or a missing key SHALL mean that setting's default. The old `~/.config/peeker/config` dotfile SHALL NOT be read.

#### Scenario: No config file

- **WHEN** no `config.json` exists
- **THEN** every plugin is enabled, routing uses the built-in ranking, and Space opens the quick-look panel

#### Scenario: Only one setting

- **WHEN** `config.json` is `{"open": {"md": "text"}}`
- **THEN** Markdown files open in the text plugin and every other setting keeps its default

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

## MODIFIED Requirements

### Requirement: Users can turn plugins off

`"plugins": {"<id>": {"enabled": false}}` SHALL turn off that plugin. A disabled plugin SHALL never open files: it SHALL drop out of default routing, the Open With menu and the quick-look panel.

#### Scenario: Disabling the image plugin

- **WHEN** the config contains `{"plugins": {"image": {"enabled": false}}}`
- **THEN** images no longer open in Peeker, and Space on an image falls through to Finder's Quick Look

### Requirement: Config routes choose a plugin per extension

`"open": {"<ext>": "<id>"}` SHALL make the named plugin the default for files with that extension, when the plugin is enabled and supports the file's type. Extensions SHALL match without regard to case. A route to a plugin that doesn't support a typed file SHALL be ignored and listed as a problem.

#### Scenario: Route to an unsupported plugin

- **WHEN** the config contains `{"open": {"pdf": "text"}}`
- **THEN** PDFs still open in the PDF plugin

### Requirement: Untyped files open only where the config routes them

Files macOS has no real type for (an extension it doesn't recognize, such as `.conf`, or a plain data type) SHALL be offered only to the plugin the config routes them to, whether or not that plugin declares the type. `"open": {"noExtension": "<id>"}` SHALL route files that have no extension. Without a route, no plugin SHALL open such a file.

#### Scenario: Dotfile routed to text

- **WHEN** the config contains `{"open": {"noExtension": "text"}}` and the user presses Space on `.zshrc` in Finder
- **THEN** the text plugin shows it

#### Scenario: Untyped file without a route

- **WHEN** the user opens a `.conf` file and the config has no route for `conf`
- **THEN** no plugin opens it, and a window open shows "No enabled plugin opens" with a hint to route it in the config

### Requirement: Plugin command shortcuts can be rebound

`"plugins": {"<id>": {"commands": {"<command>": {"shortcut": "<shortcut>"}}}}` (for example `cmd+shift+h`) SHALL replace that command's default shortcut. A shortcut that can't be parsed SHALL be listed as a problem and the default kept.

#### Scenario: Rebinding highlight

- **WHEN** the config sets `plugins.pdf.commands.highlight.shortcut` to `cmd+shift+h`
- **THEN** Cmd+Shift+H highlights the selection in PDFs, including ones already open

## REMOVED Requirements

### Requirement: Config is a plain dotfile

**Reason**: Settings move to a JSON file with a schema (see "Config is a JSON file").

**Migration**: Write the old settings into `~/.config/peeker/config.json` by hand: `disable = image` becomes `{"plugins": {"image": {"enabled": false}}}`, `open.md = markdown` becomes `{"open": {"md": "markdown"}}`, `open.none` becomes `open.noExtension`, `key.pdf.highlight = …` becomes `plugins.pdf.commands.highlight.shortcut`, and `quicklook.key` becomes `quickLook.key`. The old file is left alone.

### Requirement: Reload Config applies new settings without a restart

**Reason**: Saving the file now applies it at once (see "Saving the config applies it everywhere at once").

**Migration**: Just save the file; the menu item is gone.
