# routing-and-config Specification

## Purpose

Which plugin opens a file, how the user turns plugins on and off and overrides that choice, and how the config dotfile that holds those settings is read.

## Requirements

### Requirement: Config is a plain dotfile

The app SHALL read its settings from `~/.config/peeker/config`, or from the path in `$PEEKER_CONFIG` when set, at launch. Each line SHALL be `key = value`, with `#` starting a comment. A missing file SHALL mean default settings. A line that can't be parsed, or an unknown key, SHALL be skipped and logged, and the rest of the file SHALL still apply. A file that exists but can't be read at launch SHALL fall back to defaults and log the problem.

#### Scenario: One bad line

- **WHEN** the config has a line without `=` among valid lines
- **THEN** that line is logged and skipped, and every other line takes effect

#### Scenario: No config file

- **WHEN** no config file exists
- **THEN** every plugin is enabled, routing uses the built-in ranking, and Space opens the quick-look panel

### Requirement: Reload Config applies new settings without a restart

Peeker > Reload Config (Cmd+Shift+R) SHALL re-read the config file. New settings SHALL apply to documents opened afterwards, while open documents keep the settings they started with. A changed quick-look key SHALL take effect immediately. If the file can't be read, the app SHALL say so and keep the previous settings.

#### Scenario: Unreadable config on reload

- **WHEN** the user reloads while the config file exists but can't be read
- **THEN** an alert explains the problem and the previous settings stay in use

### Requirement: Users can turn plugins off

`disable = <id>, <id>` SHALL turn off the named plugins. A disabled plugin SHALL never open files: it SHALL drop out of default routing, the Open With menu and the quick-look panel.

#### Scenario: Disabling the image plugin

- **WHEN** the config contains `disable = image`
- **THEN** images no longer open in Peeker, and Space on an image falls through to Finder's Quick Look

### Requirement: The best-matching plugin opens a file by default

The app SHALL determine a file's type from macOS, following a symlink to the file it points to. Among enabled plugins that support the type, a plugin that declares the exact type SHALL rank before one that supports it through a parent type. The top-ranked plugin SHALL open the file unless a config route says otherwise.

#### Scenario: Markdown file

- **WHEN** the user opens a `.md` file and both the Markdown and Plain Text plugins are enabled
- **THEN** Markdown opens it, because it declares Markdown exactly while Plain Text supports it only as text

### Requirement: Config routes choose a plugin per extension

`open.<ext> = <id>` SHALL make the named plugin the default for files with that extension, when the plugin is enabled and supports the file's type. A route to a plugin that doesn't support a typed file SHALL be ignored.

#### Scenario: Route to an unsupported plugin

- **WHEN** the config contains `open.pdf = text`
- **THEN** PDFs still open in the PDF plugin

### Requirement: Untyped files open only where the config routes them

Files macOS has no real type for (an extension it doesn't recognize, such as `.conf`, or a plain data type) SHALL be offered only to the plugin the config routes them to, whether or not that plugin declares the type. `open.none = <id>` SHALL route files that have no extension. Without a route, no plugin SHALL open such a file.

#### Scenario: Dotfile routed to text

- **WHEN** the config contains `open.none = text` and the user presses Space on `.zshrc` in Finder
- **THEN** the text plugin shows it

#### Scenario: Untyped file without a route

- **WHEN** the user opens a `.conf` file and the config has no `open.conf` line
- **THEN** no plugin opens it, and a window open shows "No enabled plugin opens" with a hint to enable one in the config

### Requirement: Open With switches the plugin for one tab

Each document window SHALL show an Open With control listing every enabled plugin that supports the file, best first. Choosing another plugin SHALL reopen that tab with it. Unsaved edits SHALL be resolved first (Save, Don't Save or Cancel), and cancelling SHALL leave the tab and the control unchanged.

#### Scenario: View Markdown as plain text

- **WHEN** the user picks Plain Text in Open With on a Markdown tab with no unsaved edits
- **THEN** the tab reopens showing the Markdown source in the text plugin

### Requirement: Plugin command shortcuts can be rebound

`key.<plugin>.<command> = <shortcut>` (for example `cmd+shift+h`) SHALL replace that command's default shortcut. A shortcut that can't be parsed SHALL be logged and skipped.

#### Scenario: Rebinding highlight

- **WHEN** the config contains `key.pdf.highlight = cmd+shift+h`
- **THEN** Cmd+Shift+H highlights the selection in PDFs opened afterwards

### Requirement: The app is an alternate handler for its formats

The app SHALL declare text, JSON, XML, YAML, TOML, PDF, Markdown and image types so it appears in Finder's Open With menu and can be chosen as the default app, without claiming to be the default on install.

#### Scenario: Fresh install

- **WHEN** the app is installed and the user hasn't changed any default
- **THEN** files keep opening in their previous apps, and Peeker appears under Open With
