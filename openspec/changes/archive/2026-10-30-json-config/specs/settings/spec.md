# Spec Delta

## Purpose

The Settings window: where the user sees and changes how Peeker is set up. It starts with the config file's location and problems, and grows panes as settings move into it.

## ADDED Requirements

### Requirement: Settings opens from the menu bar and the app menu

Settings… in the menu bar icon's menu and in the app menu (Cmd+,) SHALL open the Settings window, or bring it forward when it's already open. Opening it SHALL show the Dock icon and menus like any other window.

#### Scenario: Opening Settings with no files open

- **WHEN** no document is open and the user chooses Settings… from the menu bar icon
- **THEN** the Settings window comes forward

### Requirement: The Config file pane shows the file and its problems

The Settings window SHALL have a Config file pane showing the config file's path, a button to open it in the user's default editor, and the problems found the last time it was read, each with where it is and what's wrong. With no problems it SHALL say the config has none. The pane SHALL update as soon as the file is saved.

#### Scenario: Fixing a typo

- **WHEN** the pane lists a problem with `plugins.image.enabeld` and the user fixes the key in their editor and saves
- **THEN** the problem disappears from the pane without reopening Settings

### Requirement: Open in Editor creates a starter file

When no config file exists, Open in Editor SHALL first create one containing only `{"$schema": "schema.json"}`, then open it. It SHALL never overwrite an existing file.

#### Scenario: First time

- **WHEN** there's no `config.json` and the user clicks Open in Editor
- **THEN** `~/.config/peeker/config.json` is created with the schema line and opens in their editor
