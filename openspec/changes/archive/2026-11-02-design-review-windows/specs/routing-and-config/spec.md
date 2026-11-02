## ADDED Requirements

### Requirement: A file no plugin opens points to Settings

When the user opens a file no enabled plugin opens, the alert SHALL say so, suggest adding its extension to a plugin or turning on the plugin that has it in Settings, and offer Open Settings and OK. Open Settings SHALL show the pane of a turned-off plugin whose list has the extension, or otherwise the Plain Text pane.

#### Scenario: A turned-off plugin has it

- **WHEN** the Image plugin is off and the user opens `photo.png`, then clicks Open Settings
- **THEN** Settings shows the Image pane

#### Scenario: No plugin lists it

- **WHEN** the user opens `movie.mp4` and clicks Open Settings
- **THEN** Settings shows the Plain Text pane, where `mp4` can be added
