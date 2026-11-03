## ADDED Requirements

### Requirement: General picks the text theme

The General pane SHALL have a Text theme pop-up bound to `textTheme`, listing System first, then Paper, Slate, Graphite and Ink, then Catppuccin and Tokyo Night, then High Contrast, with separators between the groups. Choosing one SHALL apply at once and rewrite the config file like any other change in Settings. While the config file can't be used, the pop-up SHALL be disabled like the pane's other controls.

#### Scenario: Picking Paper

- **WHEN** the user picks Paper in the Text theme pop-up
- **THEN** `config.json` says `"textTheme": "paper"` and open Markdown and text windows turn Paper's colors

#### Scenario: Broken config

- **WHEN** `config.json` isn't valid JSON
- **THEN** the Text theme pop-up is disabled
