## MODIFIED Requirements

### Requirement: Shows text in a native, monospaced view

The text SHALL appear in a native text view in the system monospaced font, with the native find bar (Cmd+F, Cmd+G), lines wrapped by default, Wrap Lines (Opt+Cmd+W) in the View menu and the toolbar to toggle wrapping, and Zoom In and Zoom Out (Cmd+= and Cmd+-) for the font size. Wrap Lines SHALL show whether wrapping is on: checked in the menu and pressed in the toolbar. The sidebar SHALL show the line count, the encoding (noting a byte-order mark), the dominant line ending and the file size.

#### Scenario: Toggling wrap on a long line

- **WHEN** the user turns Wrap Lines off on a file with a long line
- **THEN** the line runs on to the right and the view scrolls horizontally

#### Scenario: Wrap state shows

- **WHEN** a text file opens with lines wrapped and the user then turns Wrap Lines off
- **THEN** View > Wrap Lines is checked at first, and unchecked after
