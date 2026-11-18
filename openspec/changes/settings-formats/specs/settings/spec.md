# Spec Delta

## MODIFIED Requirements

### Requirement: Settings is a sidebar of panes

The Settings window SHALL show a sidebar of panes and the selected pane beside it. The sidebar SHALL list General, then Appearance, then, under the heading Formats, one pane per plugin in sidebar order (Image, PDF, Markdown, Table, Data, Plain Text), each with the icon its plugin names, then Permissions and Config File. It SHALL open on General the first time, and afterwards on the pane last shown, also after a relaunch. The window SHALL resize but its zoom button SHALL be disabled.

#### Scenario: Opening Settings

- **WHEN** the user opens Settings for the first time
- **THEN** the sidebar lists General, Appearance, then Image, PDF, Markdown, Table, Data and Plain Text under Formats, then Permissions and Config File, and General is selected

#### Scenario: Choosing a pane

- **WHEN** the user clicks Plain Text in the sidebar
- **THEN** the Plain Text pane replaces the General pane beside the sidebar

#### Scenario: Back where it was

- **WHEN** the user shows the PDF pane, closes Settings, quits Peeker and opens Settings again
- **THEN** the PDF pane is selected

#### Scenario: An icon per plugin

- **WHEN** the user opens Settings
- **THEN** Image, PDF, Markdown, Table, Data and Plain Text each show their own icon in the sidebar

### Requirement: A plugin pane turns the plugin on and off

Each plugin pane SHALL have a switch reading "Open <Name> files in Peeker", where <Name> is the plugin's name, that turns the plugin on or off with the same effect as `enabled` in the config. Below it the pane SHALL say "When this is off, Peeker opens no <Name> files and no other format takes them. Space shows Finder's Quick Look instead."

#### Scenario: Turning Image off

- **WHEN** the user turns off "Open Image files in Peeker" in the Image pane
- **THEN** images no longer open in Peeker, and Space on an image goes to Finder's Quick Look

### Requirement: Settings locks while the config can't be used

While the config file isn't valid JSON or can't be read, every control that changes the config SHALL be disabled, and the window SHALL say why and offer Open in Text Editor. The controls SHALL unlock as soon as a saved file can be read. Controls that don't change the config (Permissions, Open at Login and Default App) SHALL stay usable.

#### Scenario: Broken JSON

- **WHEN** the user saves the config with a missing brace while Settings is open
- **THEN** the switches, lists and recorders are disabled with a note that the file isn't valid JSON, and they come back once the brace is fixed and saved

#### Scenario: Open at Login while locked

- **WHEN** the config isn't valid JSON and the user turns on Open at Login in General
- **THEN** the switch works

#### Scenario: Make Default while locked

- **WHEN** the config isn't valid JSON and the user clicks Make Default in the PDF pane
- **THEN** double-clicking a PDF in Finder opens it in Peeker

### Requirement: General's sections

The General pane SHALL show, in this order, the Peek panel key, Open at Login, the update controls and Tips.

#### Scenario: Opening General

- **WHEN** the user opens the General pane
- **THEN** it shows the Peek panel section first, then Open at Login, Updates and Tips, and no list of default apps

### Requirement: The Config file pane shows the file and its problems

The Settings window SHALL have a Config file pane showing the config file's path, an Open in Text Editor button that opens it in the user's default editor, and the problems found the last time it was read, each with where it is and what's wrong. With no problems it SHALL say the config has none. The pane SHALL update as soon as the file is saved.

#### Scenario: Fixing a typo

- **WHEN** the pane lists a problem with `plugins.image.enabeld` and the user fixes the key in their editor and saves
- **THEN** the problem disappears from the pane without reopening Settings

### Requirement: Open in Editor creates a starter file

When no config file exists, Open in Text Editor SHALL first create one containing only `{"$schema": "schema.json"}`, then open it. It SHALL never overwrite an existing file.

#### Scenario: First time

- **WHEN** there's no `config.json` and the user clicks Open in Text Editor
- **THEN** `~/.config/peeker/config.json` is created with the schema line and opens in their editor

## ADDED Requirements

### Requirement: A plugin pane shows its files' default app

Each plugin pane SHALL have a Default App section after Extensions, with an "Opens in" row naming the app macOS opens the plugin's files with, and Make Default when that isn't Peeker for all of them. When the extensions open in different apps, the row SHALL say "Several apps" and expand to one row per extension, each naming its app, with its own Make Default. The section SHALL be hidden while the plugin is off.

#### Scenario: Making Peeker the PDF app

- **WHEN** the PDF pane says Opens in Preview and the user clicks Make Default
- **THEN** the row says Opens in Peeker, and double-clicking a PDF in Finder opens it in Peeker

#### Scenario: Split between apps

- **WHEN** Peeker opens `.md` files and Typora opens `.markdown` files
- **THEN** the Markdown pane's row says Several apps with Make Default, and expands to `.md` with Peeker and `.markdown` with Typora and its own Make Default

#### Scenario: Turned off

- **WHEN** the user turns off "Open Image files in Peeker"
- **THEN** the Image pane hides its Default App section, and shows it again once the switch is back on

### Requirement: Extensions without a file type are named as ones Peeker can't set

In the Default App section, an extension the system has no file type for SHALL be listed as one Peeker can't set here, with a note that Get Info in Finder can set it, and the row SHALL expand to show it. When none of the plugin's extensions can be set, the row SHALL say so and offer no Make Default.

#### Scenario: conf in Plain Text

- **WHEN** Plain Text's extensions include `conf`
- **THEN** the expanded rows list `.conf` as one Peeker can't set here, without a Make Default button

## REMOVED Requirements

### Requirement: General shows whether Peeker is the default app

**Reason**: The default app for a format's files now shows in that format's pane, next to its extensions, under Default App.
**Migration**: Use Make Default in the format's pane; General no longer has it.
