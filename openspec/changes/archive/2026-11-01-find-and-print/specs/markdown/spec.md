## ADDED Requirements

### Requirement: Print Markdown

Printing a Markdown file SHALL print it rendered, as the window shows it, but in the light appearance (dark text on white) whatever the system appearance, wrapped to the page width across as many pages as it takes. Each page SHALL carry the system's header and footer: the file's name, the date and the page number.

#### Scenario: Rendered, not source
- **WHEN** the user prints a file with a `# Title` heading
- **THEN** the printout shows "Title" as a heading, without the `#`

#### Scenario: Dark mode
- **WHEN** the system is in dark mode and the user prints a Markdown file
- **THEN** the printout uses dark text on white
