# Spec Delta

## MODIFIED Requirements

### Requirement: Plugins are built into the app

Each plugin SHALL be code built into the app that declares an id, a display name and the file extensions it opens by default. A plugin SHALL do no work until the first file routed to it opens.

#### Scenario: Launch without files

- **WHEN** the app launches with no file to open
- **THEN** no plugin reads or decodes anything
