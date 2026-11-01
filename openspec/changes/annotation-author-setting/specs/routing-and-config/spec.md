## ADDED Requirements

### Requirement: The config sets the PDF author name

The config SHALL accept an author name for the PDF plugin's annotations (the key, such as `plugins.pdf.author`, is settled in the design). A value that isn't text SHALL be listed as a problem and ignored, leaving no author.

#### Scenario: A name in the file

- **WHEN** the config sets the PDF author name to "Sam Lee"
- **THEN** annotations Peeker saves in PDFs carry "Sam Lee"

#### Scenario: A value that isn't text

- **WHEN** the config sets the PDF author name to a number
- **THEN** Settings lists the problem and saved annotations carry no author
