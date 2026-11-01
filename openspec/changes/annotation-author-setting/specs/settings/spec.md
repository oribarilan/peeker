## ADDED Requirements

### Requirement: The PDF pane sets the author name

The PDF pane SHALL have a field for the author name Peeker writes on the annotations it saves, empty by default. A change SHALL be written to the config file at once, like every other Settings change.

#### Scenario: Setting a name

- **WHEN** the user types "Sam Lee" into the author field
- **THEN** the config file holds that name, and highlights saved from then on carry it

#### Scenario: Clearing the name

- **WHEN** the user empties the author field
- **THEN** the name leaves the config file, and annotations saved from then on carry no author
