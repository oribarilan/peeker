# Spec Delta

## ADDED Requirements

### Requirement: Markdown text size is remembered

The Markdown Editor SHALL remember its text size across files and launches: a zoom in any window SHALL apply to every Markdown file opened after it, in a window or the Peek panel. Files already open SHALL keep their own until changed.

#### Scenario: Reading at a larger size

- **WHEN** the user zooms in twice in a Markdown window, quits Peeker and later presses Space on another Markdown file
- **THEN** the Peek panel shows it at the larger size

## MODIFIED Requirements

### Requirement: Actual Size in the Markdown Editor

Actual Size (Cmd+0) SHALL put the Markdown Editor's text back at the default size, 14 points for body text, every style together, and that size SHALL be remembered like any other. It SHALL be listed in the View menu only, with no toolbar button. The Markdown Editor SHALL NOT offer Zoom to Fit, since its text always wraps to the window's width.

#### Scenario: Back to the default size

- **WHEN** the user presses Cmd+= twice in a Markdown window and then Cmd+0
- **THEN** body text is at 14 points and headings at their sizes for it, and View lists Zoom In, Zoom Out and Actual Size but no Zoom to Fit
