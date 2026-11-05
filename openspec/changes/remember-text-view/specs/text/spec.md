# Spec Delta

## ADDED Requirements

### Requirement: Text size and wrapping are remembered

Plain text SHALL remember its font size and whether Wrap Lines is on, across files and launches: a change in any window SHALL apply to every text file opened after it, in a window or the Peek panel. Text files already open SHALL keep their own until changed.

#### Scenario: Reading logs unwrapped

- **WHEN** the user turns Wrap Lines off and zooms in twice in one log file, then quits Peeker and later opens another log
- **THEN** the other log opens unwrapped at the larger size

#### Scenario: A bad stored size

- **WHEN** the stored size is outside 6 to 72 points
- **THEN** text opens at the default 12 points

## MODIFIED Requirements

### Requirement: Actual Size in plain text

Actual Size (Cmd+0) SHALL put the text back at the default font size, 12 points, and that size SHALL be remembered like any other. It SHALL be listed in the View menu only, with no toolbar button. Plain text SHALL NOT offer Zoom to Fit.

#### Scenario: Back to the default size

- **WHEN** the user presses Cmd+= three times in a text file and then Cmd+0
- **THEN** the text is at 12 points, and View lists Zoom In, Zoom Out and Actual Size but no Zoom to Fit
