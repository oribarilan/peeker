## MODIFIED Requirements

### Requirement: Settings is a sidebar of panes

The Settings window SHALL show a sidebar of panes and the selected pane beside it. The sidebar SHALL list General, then Appearance, then one pane per plugin in sidebar order (Image, PDF, Markdown, Table, Plain Text), each with the icon its plugin names, then Permissions and Config File. It SHALL open on General the first time, and afterwards on the pane last shown, also after a relaunch. The window SHALL resize but its zoom button SHALL be disabled.

#### Scenario: Opening Settings

- **WHEN** the user opens Settings for the first time
- **THEN** the sidebar lists General, Appearance, Image, PDF, Markdown, Table, Plain Text, Permissions and Config File, and General is selected

#### Scenario: Choosing a pane

- **WHEN** the user clicks Plain Text in the sidebar
- **THEN** the Plain Text pane replaces the General pane beside the sidebar

#### Scenario: Back where it was

- **WHEN** the user shows the PDF pane, closes Settings, quits Peeker and opens Settings again
- **THEN** the PDF pane is selected

#### Scenario: An icon per plugin

- **WHEN** the user opens Settings
- **THEN** Image, PDF, Markdown, Table and Plain Text each show their own icon in the sidebar
