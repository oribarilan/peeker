## ADDED Requirements

### Requirement: Plugin tool shortcuts can be rebound

`"plugins": {"<id>": {"tools": {"<tool>": {"shortcut": "<shortcut>"}}}}` (for example `cmd+shift+h`) SHALL replace that tool's default shortcut, and `"shortcut": "off"` SHALL leave the tool without one. A shortcut that can't be parsed SHALL be a problem, and the default kept. A shortcut a fixed menu item uses SHALL be a problem naming that item, and the tool SHALL have none. The old `commands` section SHALL be reported as an unknown key.

#### Scenario: Rebinding highlight

- **WHEN** the config sets `plugins.pdf.tools.highlight.shortcut` to `cmd+shift+h`
- **THEN** Cmd+Shift+H turns on the highlighter in PDFs, including ones already open

#### Scenario: No shortcut

- **WHEN** the config sets `plugins.pdf.tools.highlight.shortcut` to `off`
- **THEN** Ctrl+Cmd+H no longer highlights, and the Tools menu shows Highlight without a shortcut

#### Scenario: A key a menu item uses

- **WHEN** the config sets `plugins.pdf.tools.sign.shortcut` to `ctrl+cmd+s`
- **THEN** the config's problems say Ctrl+Cmd+S is used by Show/Hide Sidebar, Tools > Sign shows no shortcut, and Ctrl+Cmd+S still shows or hides the sidebar

#### Scenario: The section's old name

- **WHEN** `config.json` still has `plugins.pdf.commands`
- **THEN** it's listed as an unknown key, and the PDF tools keep their default shortcuts

## REMOVED Requirements

### Requirement: Plugin command shortcuts can be rebound
**Reason**: Commands are now called tools, in the config too.
**Migration**: Rename `plugins.<id>.commands` to `plugins.<id>.tools`; Settings writes the new key on its next save. See "Plugin tool shortcuts can be rebound".

## MODIFIED Requirements

### Requirement: Mistakes in the config are reported, not guessed at

A config that isn't valid JSON SHALL change nothing: the settings in use stay as they were. Otherwise, an unknown key SHALL be skipped, and a value of the wrong kind or out of range SHALL leave that setting as it was, while the rest of the file applies. Each such problem SHALL be listed with where it is (such as `plugins.pdf.tools.highlight.shortcut`) and what's wrong.

#### Scenario: A typo in a key

- **WHEN** the config contains `{"plugins": {"image": {"enabeld": false}}}`
- **THEN** the image plugin stays enabled, and the problems list says `plugins.image.enabeld` is not a known setting

#### Scenario: Broken JSON

- **WHEN** the user saves the config with a missing closing brace
- **THEN** every setting stays as it was, and the problems list says the file isn't valid JSON

### Requirement: Open With switches the plugin for one tab

Each Editor window SHALL have an Open With control in its toolbar (tooltip "Open With") and File > Open With, both listing every enabled plugin, the file's owner first, the menu checking the current one. Choosing another plugin SHALL reopen that tab with it; a plugin that can't read the file SHALL show its error in the tab. Unsaved edits SHALL be resolved first (Save, Don't Save or Cancel), and cancelling SHALL leave the tab and the control unchanged.

#### Scenario: View Markdown as plain text

- **WHEN** the user picks Plain Text in Open With on a Markdown tab with no unsaved edits
- **THEN** the tab reopens showing the Markdown source in the text plugin

#### Scenario: From the File menu

- **WHEN** the user chooses File > Open With > Plain Text on a Markdown tab with no unsaved edits
- **THEN** the tab reopens in the text plugin, and File > Open With now checks Plain Text

#### Scenario: A plugin that can't read the file

- **WHEN** the user picks Image in Open With on a Markdown tab
- **THEN** the tab says the file isn't a readable image, and Open With can switch it back
