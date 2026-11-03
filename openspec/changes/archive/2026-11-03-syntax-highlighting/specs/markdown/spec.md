## MODIFIED Requirements

### Requirement: Print Markdown

Printing a Markdown file SHALL print it rendered, as the Peek panel shows it, unsaved edits included, in the light appearance (dark text on white, code blocks in the System theme's light syntax colors) whatever the system appearance, wrapped to the page width across as many pages as it takes. Each page SHALL carry the system's header and footer: the file's name, the date and the page number.

#### Scenario: Rendered, not source
- **WHEN** the user prints a file with a `# Title` heading
- **THEN** the printout shows "Title" as a heading, without the `#`

#### Scenario: Unsaved edits
- **WHEN** the user types a new paragraph in the Editor and prints without saving
- **THEN** the printout includes the new paragraph

#### Scenario: Dark mode
- **WHEN** the system is in dark mode and the user prints a Markdown file
- **THEN** the printout uses dark text on white
