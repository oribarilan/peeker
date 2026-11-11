## ADDED Requirements

### Requirement: The Peek panel's buttons have keys

While the Peek panel is up and Finder is in front, Command-O SHALL do what the panel's main button does, and Command-R SHALL show the file in Finder and close the panel, both by default and as Settings or the config set them. The keys SHALL reach Finder as usual while the panel isn't showing, and SHALL go to the button's menu while it's open. Each button SHALL show its key as a caption while Show shortcuts is on, and its tooltip SHALL name the key.

#### Scenario: Opening with Command-O

- **WHEN** the panel shows notes.md and the user presses Command-O
- **THEN** notes.md opens in the Editor, and Finder doesn't open it

#### Scenario: Revealing with Command-R

- **WHEN** the panel shows notes.md and the user presses Command-R
- **THEN** the panel closes and Finder shows notes.md selected

#### Scenario: Without the panel

- **WHEN** no panel shows and the user presses Command-O in Finder
- **THEN** Finder opens the selected file as it always does

#### Scenario: Captions

- **WHEN** Show shortcuts is on and the panel opens
- **THEN** the main button reads "Open in Peeker ⌘O" and the folder button shows ⌘R beside its icon
