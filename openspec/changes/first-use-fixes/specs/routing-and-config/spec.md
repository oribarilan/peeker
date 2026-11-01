## MODIFIED Requirements

### Requirement: Plugin command shortcuts can be rebound

`"plugins": {"<id>": {"commands": {"<command>": {"shortcut": "<shortcut>"}}}}` (for example `cmd+shift+h`) SHALL replace that command's default shortcut, and `"shortcut": "off"` SHALL leave the command without one. A shortcut that can't be parsed SHALL be listed as a problem and the default kept.

#### Scenario: Rebinding highlight

- **WHEN** the config sets `plugins.pdf.commands.highlight.shortcut` to `cmd+shift+h`
- **THEN** Cmd+Shift+H turns on the highlighter in PDFs, including ones already open

#### Scenario: No shortcut

- **WHEN** the config sets `plugins.pdf.commands.highlight.shortcut` to `off`
- **THEN** Ctrl+Cmd+H no longer highlights, and the Commands menu shows Highlight without a shortcut
