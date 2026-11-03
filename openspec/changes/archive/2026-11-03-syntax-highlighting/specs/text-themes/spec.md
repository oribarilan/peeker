## ADDED Requirements

### Requirement: A theme colors code

Each theme SHALL have six syntax colors in each look, for keywords, strings, comments, numbers and constants, type names and function names: System in Xcode's default colors, Catppuccin and Tokyo Night in their official syntax colors, and the others in palettes of their own.

#### Scenario: Catppuccin code

- **WHEN** the theme is Catppuccin, the look is dark, and the user opens a Python file
- **THEN** keywords show in Catppuccin Mocha's mauve and strings in its green

## MODIFIED Requirements

### Requirement: Printing ignores the theme

Printing a Markdown or text file SHALL use dark text on white whatever the theme. Colored code SHALL print in the System theme's light syntax colors.

#### Scenario: Printing in Tokyo Night

- **WHEN** the theme is Tokyo Night and the user prints a Markdown file
- **THEN** the printout has dark text on white, with no Tokyo Night colors
