# routing-and-config Specification

## Purpose

Which plugin opens a file, how the user turns plugins on and off and overrides that choice, and how the config dotfile that holds those settings is read.

## Requirements

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

### Requirement: Users can turn plugins off

`"plugins": {"<id>": {"enabled": false}}` SHALL turn off that plugin. A disabled plugin SHALL never open files: it SHALL drop out of default routing, the Open With menu and the quick-look panel.

#### Scenario: Disabling the image plugin

- **WHEN** the config contains `{"plugins": {"image": {"enabled": false}}}`
- **THEN** images no longer open in Peeker, and Space on an image falls through to Finder's Quick Look

### Requirement: The best-matching plugin opens a file by default

The app SHALL determine a file's type from macOS, following a symlink to the file it points to. Among enabled plugins that support the type, a plugin that declares the exact type SHALL rank before one that supports it through a parent type. The top-ranked plugin SHALL open the file unless a config route says otherwise.

#### Scenario: Markdown file

- **WHEN** the user opens a `.md` file and both the Markdown and Plain Text plugins are enabled
- **THEN** Markdown opens it, because it declares Markdown exactly while Plain Text supports it only as text

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

### Requirement: Open With switches the plugin for one tab

Each document window SHALL show an Open With control listing every enabled plugin that supports the file, best first. Choosing another plugin SHALL reopen that tab with it. Unsaved edits SHALL be resolved first (Save, Don't Save or Cancel), and cancelling SHALL leave the tab and the control unchanged.

#### Scenario: View Markdown as plain text

- **WHEN** the user picks Plain Text in Open With on a Markdown tab with no unsaved edits
- **THEN** the tab reopens showing the Markdown source in the text plugin

### Requirement: Plugin command shortcuts can be rebound

`"plugins": {"<id>": {"commands": {"<command>": {"shortcut": "<shortcut>"}}}}` (for example `cmd+shift+h`) SHALL replace that command's default shortcut. A shortcut that can't be parsed SHALL be listed as a problem and the default kept.

#### Scenario: Rebinding highlight

- **WHEN** the config sets `plugins.pdf.commands.highlight.shortcut` to `cmd+shift+h`
- **THEN** Cmd+Shift+H highlights the selection in PDFs, including ones already open

### Requirement: The app is an alternate handler for its formats

The app SHALL declare text, JSON, XML, YAML, TOML, PDF, Markdown and image types so it appears in Finder's Open With menu and can be chosen as the default app, without claiming to be the default on install.

#### Scenario: Fresh install

- **WHEN** the app is installed and the user hasn't changed any default
- **THEN** files keep opening in their previous apps, and Peeker appears under Open With
