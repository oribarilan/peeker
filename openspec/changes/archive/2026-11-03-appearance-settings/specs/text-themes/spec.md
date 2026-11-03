## MODIFIED Requirements

### Requirement: Built-in text themes

Peeker SHALL offer eight text themes: System (the default, in the system's own colors), Paper, Slate, Graphite, Ink, Catppuccin, Tokyo Night and High Contrast. Each SHALL have a light and a dark variant and SHALL show the one the text appearance picks, which by default matches the app's appearance, switching when it changes. Catppuccin SHALL use its official Latte and Mocha colors and Tokyo Night its official Light and Night colors, with their licenses noted in the third-party notices.

#### Scenario: Dark mode

- **WHEN** the theme is Paper, text matches the app, and the system switches from light to dark
- **THEN** open Markdown and text windows change from Paper's cream background to its dark background without reopening

#### Scenario: Forced light text

- **WHEN** the theme is Paper, Text appearance is Light, and the system switches to dark
- **THEN** open Markdown and text windows keep Paper's cream background

#### Scenario: Default

- **WHEN** no theme has been chosen
- **THEN** Markdown and text look as they do in the system's colors

### Requirement: What a theme colors

One theme SHALL apply to both Markdown and Plain Text, in the Editor and in the Peek panel. It SHALL set the text area's background and body text, Markdown's headings, dimmed markers, links and code background, the selection, the insertion point, and the find matches near the visible text, without dimming the rest; the current match SHALL keep the system's find indicator. The sidebar, the toolbar, notes and fonts SHALL stay as they are.

#### Scenario: A text file in Tokyo Night

- **WHEN** the theme is Tokyo Night, the system is dark, and the user opens a text file
- **THEN** the text area has Tokyo Night's dark background and text color, and the sidebar keeps the system look

#### Scenario: The Peek panel

- **WHEN** the theme is Catppuccin and the user presses Space on a Markdown file
- **THEN** the Peek panel shows it rendered on Catppuccin's background, with Catppuccin's heading and link colors

#### Scenario: Finding in Paper

- **WHEN** the theme is Paper and the user searches a text file for a word with Cmd+F
- **THEN** every match on screen has Paper's find color, the rest of the text isn't dimmed, and find options and Replace work as before
