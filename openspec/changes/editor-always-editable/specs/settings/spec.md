## ADDED Requirements

### Requirement: A tool's shortcut can be cleared

Each tool's shortcut in a plugin pane SHALL have a clear button that leaves the tool without a shortcut, applied at once and written as `"shortcut": "off"`. Reset SHALL bring the default back. A tool without a shortcut SHALL show that it has none.

#### Scenario: Clearing a shortcut

- **WHEN** the user clicks the clear button beside Text Box's shortcut in the PDF pane
- **THEN** `config.json` has `"shortcut": "off"` for text-box, Ctrl+Cmd+T no longer starts a text box, and the recorder shows no shortcut

### Requirement: A plugin pane rebinds the plugin's tools

Each plugin pane SHALL list the plugin's tools, each with its shortcut in a key recorder and a reset to the default. The recorder SHALL refuse a key without a modifier (except single keys for edit tools), and a shortcut that another tool of the same plugin or an app menu item already uses, naming it. A refusal's reason SHALL stay shown until the next recording and SHALL be announced to VoiceOver. A recorded shortcut SHALL work in open windows at once.

#### Scenario: Rebinding Highlight Selection

- **WHEN** the user records Command-Shift-H for Highlight Selection in the PDF pane
- **THEN** Command-Shift-H highlights the selection in PDFs, including ones already open

#### Scenario: A taken key

- **WHEN** the user records Command-S for a tool
- **THEN** the recorder refuses it, saying the Save menu item uses it, and the shortcut stays as it was

#### Scenario: The reason stays and is heard

- **WHEN** the recorder refuses Command-P while VoiceOver runs
- **THEN** VoiceOver reads that Print uses it, and the reason stays under the recorder until the user records again

## REMOVED Requirements

### Requirement: A command's shortcut can be cleared
**Reason**: Commands are now called tools.
**Migration**: See "A tool's shortcut can be cleared".

### Requirement: A plugin pane rebinds the plugin's commands
**Reason**: Commands are now called tools.
**Migration**: See "A plugin pane rebinds the plugin's tools".
