## MODIFIED Requirements

### Requirement: Open With switches the plugin for one tab

Each document window SHALL show an Open With control in its toolbar, with "Open With" as its tooltip, and File > Open With SHALL list the same choices: every enabled plugin, the one whose list has the file's extension first, with the current one checked in the menu. Choosing another plugin in either SHALL reopen that tab with it; a plugin that can't read the file SHALL show its error in the tab. Unsaved edits SHALL be resolved first (Save, Don't Save or Cancel), and cancelling SHALL leave the tab and the control unchanged.

#### Scenario: View Markdown as plain text

- **WHEN** the user picks Plain Text in Open With on a Markdown tab with no unsaved edits
- **THEN** the tab reopens showing the Markdown source in the text plugin

#### Scenario: From the File menu

- **WHEN** the user chooses File > Open With > Plain Text on a Markdown tab with no unsaved edits
- **THEN** the tab reopens in the text plugin, and File > Open With now checks Plain Text

#### Scenario: A plugin that can't read the file

- **WHEN** the user picks Image in Open With on a Markdown tab
- **THEN** the tab says the file isn't a readable image, and Open With can switch it back

### Requirement: Plugin command shortcuts can be rebound

`"plugins": {"<id>": {"commands": {"<command>": {"shortcut": "<shortcut>"}}}}` (for example `cmd+shift+h`) SHALL replace that command's default shortcut, and `"shortcut": "off"` SHALL leave the command without one. A shortcut that can't be parsed SHALL be listed as a problem and the default kept. A shortcut that a fixed menu item already uses, such as Ctrl+Cmd+S for Show/Hide Sidebar or Cmd+S for Save, SHALL be listed as a problem naming that item, and the command SHALL have no shortcut while the menu item keeps its key.

#### Scenario: Rebinding highlight

- **WHEN** the config sets `plugins.pdf.commands.highlight.shortcut` to `cmd+shift+h`
- **THEN** Cmd+Shift+H turns on the highlighter in PDFs, including ones already open

#### Scenario: No shortcut

- **WHEN** the config sets `plugins.pdf.commands.highlight.shortcut` to `off`
- **THEN** Ctrl+Cmd+H no longer highlights, and the Tools menu shows Highlight without a shortcut

#### Scenario: A key a menu item uses

- **WHEN** the config sets `plugins.pdf.commands.sign.shortcut` to `ctrl+cmd+s`
- **THEN** the config's problems say Ctrl+Cmd+S is used by Show/Hide Sidebar, Tools > Sign shows no shortcut, and Ctrl+Cmd+S still shows or hides the sidebar
