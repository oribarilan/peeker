## ADDED Requirements

### Requirement: Built-in text themes

Peeker SHALL offer eight text themes: System (the default, in the system's own colors), Paper, Slate, Graphite, Ink, Catppuccin, Tokyo Night and High Contrast. Each SHALL have a light and a dark variant and SHALL show the one matching the system appearance, switching when the appearance changes. Catppuccin SHALL use its official Latte and Mocha colors and Tokyo Night its official Light and Night colors, with their licenses noted in the project's third-party notices.

#### Scenario: Dark mode

- **WHEN** the theme is Paper and the system switches from light to dark
- **THEN** open Markdown and text windows change from Paper's cream background to its dark background without reopening

#### Scenario: Default

- **WHEN** no theme has been chosen
- **THEN** Markdown and text look as they do in the system's colors

### Requirement: What a theme colors

One theme SHALL apply to both Markdown and Plain Text, in the Editor and in the Peek panel. It SHALL set the text area's background and body text, Markdown's headings, dimmed markers, links and code background, the selection, the insertion point, and the highlights of find matches. The sidebar, the toolbar, notes and fonts SHALL stay as they are.

#### Scenario: A text file in Tokyo Night

- **WHEN** the theme is Tokyo Night, the system is dark, and the user opens a text file
- **THEN** the text area has Tokyo Night's dark background and text color, and the sidebar keeps the system look

#### Scenario: The Peek panel

- **WHEN** the theme is Catppuccin and the user presses Space on a Markdown file
- **THEN** the Peek panel shows it rendered on Catppuccin's background, with Catppuccin's heading and link colors

### Requirement: Changing the theme applies at once

Choosing another theme SHALL recolor every open Markdown and text window and the Peek panel at once, keeping their text, unsaved edits, scroll position and selection.

#### Scenario: Switching with an edit pending

- **WHEN** a Markdown window has unsaved typing and the user picks Graphite in Settings
- **THEN** the window takes Graphite's colors and still has the typing, marked edited

### Requirement: Printing ignores the theme

Printing a Markdown or text file SHALL use dark text on white whatever the theme.

#### Scenario: Printing in Tokyo Night

- **WHEN** the theme is Tokyo Night and the user prints a Markdown file
- **THEN** the printout has dark text on white, with no Tokyo Night colors
