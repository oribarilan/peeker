# Spec Delta

## MODIFIED Requirements

### Requirement: Each extension opens in one plugin

A file SHALL open in the enabled plugin whose extension list contains the file's extension, compared without regard to case. For a symlink, the extension SHALL come from the file it points to. A file with no extension, including a dotfile such as `.zshrc`, SHALL match the list entry `noExtension`. A folder SHALL match nothing. When no enabled plugin lists the extension, no plugin SHALL open the file. No two plugins SHALL list the same extension by default.

#### Scenario: Markdown file

- **WHEN** the user opens `notes.md` and every plugin has its default list
- **THEN** Markdown opens it

#### Scenario: Extension in capitals

- **WHEN** the user opens `README.MD`
- **THEN** Markdown opens it, as for `.md`

#### Scenario: Dotfile

- **WHEN** the user presses Space on `.zshrc` in Finder
- **THEN** Plain Text shows it, because its default list has `noExtension`

#### Scenario: Extension no plugin lists

- **WHEN** the user opens `movie.mp4`
- **THEN** no plugin opens it, and an alert says Peeker doesn't open “movie.mp4”

#### Scenario: Space on a folder

- **WHEN** the user presses Space on a folder in Finder
- **THEN** Finder's Quick Look shows it

### Requirement: A file no plugin opens points to Settings

When the user opens a file no enabled plugin opens, the alert SHALL say Peeker doesn't open it, suggest adding its extension to a format or turning on the format that has it in Settings, and offer Open Settings and OK. Open Settings SHALL show the pane of a turned-off plugin whose list has the extension, or otherwise the Plain Text pane. Neither the alert nor its suggestion SHALL use the word "plugin".

#### Scenario: A turned-off plugin has it

- **WHEN** the Image plugin is off and the user opens `photo.png`, then clicks Open Settings
- **THEN** Settings shows the Image pane

#### Scenario: No plugin lists it

- **WHEN** the user opens `movie.mp4` and clicks Open Settings
- **THEN** Settings shows the Plain Text pane, where `mp4` can be added

#### Scenario: The alert's words

- **WHEN** the user opens `movie.mp4`
- **THEN** the alert reads Peeker doesn't open “movie.mp4” and suggests adding `mp4` to a format in Settings, or turning on the format that has it

## ADDED Requirements

### Requirement: Config problems and the schema say format

Problems listed for the config and the descriptions in `schema.json` SHALL call a plugin a format, as Settings does, while key paths such as `plugins.pdf.extensions` stay as they are.

#### Scenario: An extension in two lists

- **WHEN** the config adds `md` to `plugins.text.extensions` and leaves Markdown's list at its default
- **THEN** the problem names `plugins.text.extensions` and says `md` belongs to the Markdown format

#### Scenario: An unknown id

- **WHEN** the config has `plugins.pdff`
- **THEN** the problem names `plugins.pdff` and says there's no format with that id, listing the ids there are
