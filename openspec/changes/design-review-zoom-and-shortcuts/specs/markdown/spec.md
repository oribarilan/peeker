## ADDED Requirements

### Requirement: Actual Size in the Markdown Editor

Actual Size (Cmd+0) SHALL put the Markdown Editor's text back at the size it opens at, every style together, listed in the View menu only, with no toolbar button. The Markdown Editor SHALL NOT offer Zoom to Fit, since its text always wraps to the window's width.

#### Scenario: Back to the default size

- **WHEN** the user presses Cmd+= twice in a Markdown window and then Cmd+0
- **THEN** body text and headings are at the sizes they opened at, and View lists Zoom In, Zoom Out and Actual Size but no Zoom to Fit
