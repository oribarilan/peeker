## MODIFIED Requirements

### Requirement: Editors autocomplete the config

At launch, the app SHALL write `schema.json`, a JSON Schema describing every key, next to `config.json` whenever its content differs from what's there. The app SHALL change `config.json` itself only to save a change the user made in Settings. A `"$schema"` key in the config SHALL be accepted and otherwise ignored.

#### Scenario: Autocomplete in an editor

- **WHEN** the config starts with `"$schema": "schema.json"` and the user opens it in an editor that supports JSON Schema
- **THEN** the editor offers the known keys and describes them

#### Scenario: Launching leaves the config alone

- **WHEN** the app launches with a hand-formatted `config.json`
- **THEN** the file is byte for byte as it was
