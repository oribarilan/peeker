## MODIFIED Requirements

### Requirement: Shows text in a native, monospaced view

The text SHALL appear in a native text view in the system monospaced font, with the native find bar (Cmd+F, Cmd+G), lines wrapped by default, Wrap Lines in the View menu and the toolbar to toggle wrapping, and Zoom In and Zoom Out (Cmd+= and Cmd+-) for the font size. Wrap Lines SHALL show whether wrapping is on: checked in the menu and pressed in the toolbar. The sidebar SHALL show the line count, the encoding (noting a byte-order mark), the dominant line ending and the file size.

#### Scenario: Toggling wrap on a long line

- **WHEN** the user turns Wrap Lines off on a file with a long line
- **THEN** the line runs on to the right and the view scrolls horizontally

#### Scenario: Wrap state shows

- **WHEN** a text file opens with lines wrapped and the user then turns Wrap Lines off
- **THEN** View > Wrap Lines is checked at first, and unchecked after

#### Scenario: Wrap Lines has no default shortcut

- **WHEN** a text file is in front and the config sets no shortcut for Wrap Lines
- **THEN** View > Wrap Lines shows no shortcut, and Opt+Cmd+W doesn't change wrapping

#### Scenario: A configured shortcut stays

- **WHEN** the config sets `plugins.text.tools.toggle-wrap.shortcut` to `opt+cmd+w`
- **THEN** Opt+Cmd+W toggles wrapping, and View > Wrap Lines shows it

## ADDED Requirements

### Requirement: Actual Size in plain text

Actual Size (Cmd+0) SHALL put the text back at the font size it opens at. It SHALL be listed in the View menu only, with no toolbar button. Plain text SHALL NOT offer Zoom to Fit.

#### Scenario: Back to the default size

- **WHEN** the user presses Cmd+= three times in a text file and then Cmd+0
- **THEN** the text is at the size it opened at, and View lists Zoom In, Zoom Out and Actual Size but no Zoom to Fit
