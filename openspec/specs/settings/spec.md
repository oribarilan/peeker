# settings Specification

## Purpose

The Settings window: where the user sees and changes how Peeker is set up. It starts with the config file's location and problems, and grows panes as settings move into it.

## Requirements

### Requirement: Settings opens from the menu bar and the app menu

Settings… in the menu bar icon's menu and in the app menu (Cmd+,) SHALL open the Settings window, or bring it forward when it's already open. Launching Peeker by hand with no file to open, and reopening it while it runs with no window showing, SHALL do the same; a launch at login SHALL NOT. Opening it SHALL show the Dock icon and menus like any other window.

#### Scenario: Opening Settings with no files open

- **WHEN** no document is open and the user chooses Settings… from the menu bar icon
- **THEN** the Settings window comes forward

#### Scenario: Launching from Spotlight

- **WHEN** Peeker isn't running and the user opens it from Spotlight
- **THEN** the Settings window opens next to the menu bar icon

#### Scenario: At login

- **WHEN** Peeker starts at login with no files to open
- **THEN** only the menu bar icon appears

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

### Requirement: General shows the update controls

The General pane SHALL show a "Check for updates automatically" checkbox bound to `updates.check`, a Check Now button and the version of Peeker running. Changing the checkbox SHALL apply at once and rewrite the config file like any other change in Settings; Check Now SHALL check right away whether the checkbox is on or off.

#### Scenario: Opting out

- **WHEN** the user clears "Check for updates automatically"
- **THEN** `config.json` has `"updates": {"check": false}` and automatic checks stop

#### Scenario: Checking by hand while opted out

- **WHEN** automatic checks are off and the user clicks Check Now
- **THEN** Peeker checks right away and says what it found

### Requirement: A command's shortcut can be cleared

Each command's shortcut in a plugin pane SHALL have a clear button that leaves the command without a shortcut, applied at once and written as `"shortcut": "off"`. Reset SHALL bring the default back. A command without a shortcut SHALL show that it has none.

#### Scenario: Clearing a shortcut

- **WHEN** the user clicks the clear button beside Zoom In's shortcut in the PDF pane
- **THEN** `config.json` has `"shortcut": "off"` for zoom-in, Cmd+= no longer zooms a PDF, and the recorder shows no shortcut

### Requirement: Settings is a sidebar of panes

The Settings window SHALL show a sidebar of panes and the selected pane beside it. The sidebar SHALL list General, then one pane per plugin in sidebar order (Image, PDF, Markdown, Plain Text), each with the icon its plugin names, then Permissions and Config File. It SHALL open on General the first time, and afterwards on the pane last shown, also after a relaunch. The window SHALL resize but its zoom button SHALL be disabled.

#### Scenario: Opening Settings

- **WHEN** the user opens Settings for the first time
- **THEN** the sidebar lists General, Image, PDF, Markdown, Plain Text, Permissions and Config File, and General is selected

#### Scenario: Choosing a pane

- **WHEN** the user clicks Plain Text in the sidebar
- **THEN** the Plain Text pane replaces the General pane beside the sidebar

#### Scenario: Back where it was

- **WHEN** the user shows the PDF pane, closes Settings, quits Peeker and opens Settings again
- **THEN** the PDF pane is selected

#### Scenario: An icon per plugin

- **WHEN** the user opens Settings
- **THEN** Image, PDF, Markdown and Plain Text each show their own icon in the sidebar

### Requirement: General sets the Peek panel key

The General pane SHALL show the Peek panel key in a key recorder and an Off choice. The recorder SHALL accept a bare Space or a key with at least one modifier, and SHALL refuse any other bare key, saying it works only with a modifier. A key the config can't express SHALL be refused with a message. A recorded key or Off SHALL apply at once, as a saved config would.

#### Scenario: Moving the Peek panel to Option-Space

- **WHEN** the user records Option-Space
- **THEN** Option-Space opens the Peek panel from any app, and Space alone no longer does

#### Scenario: A bare letter

- **WHEN** the user presses J alone while recording
- **THEN** the recorder refuses it, says a key other than Space needs a modifier, and the key stays as it was

#### Scenario: Turning the Peek panel off

- **WHEN** the user chooses Off
- **THEN** Space in Finder goes to Finder's Quick Look

### Requirement: A plugin pane turns the plugin on and off

Each plugin pane SHALL have a switch that turns the plugin on or off, with the same effect as `enabled` in the config.

#### Scenario: Turning Image off

- **WHEN** the user turns off the switch in the Image pane
- **THEN** images no longer open in Peeker, and Space on an image goes to Finder's Quick Look

### Requirement: A plugin pane edits the plugin's extensions

Each plugin pane SHALL show the extensions the plugin opens as tokens that can be removed, a text field showing "Add an extension" to add one, and Reset, which restores the plugin's default list. An added entry SHALL be checked like a config entry: one leading dot dropped, lowercased, and refused when empty or holding a dot, slash or space; `noExtension` stands for files without one. Adding one the plugin already has SHALL change nothing.

#### Scenario: Adding an extension

- **WHEN** the user types `.Rst` into Plain Text's field and presses Return
- **THEN** a `rst` token appears and `.rst` files open in Plain Text

#### Scenario: Removing and resetting

- **WHEN** the user removes `log` from Plain Text and later clicks Reset
- **THEN** `.log` files stop opening in Plain Text, and after Reset the default list, `log` included, is back

#### Scenario: Not an extension

- **WHEN** the user types `tar.gz`
- **THEN** the field says it isn't an extension and nothing is added

#### Scenario: An empty field

- **WHEN** a plugin pane shows with nothing typed in the field
- **THEN** the field shows "Add an extension"

### Requirement: Adding another plugin's extension offers to move it

When the user adds an extension that another plugin opens, the pane SHALL name that plugin and offer to move the extension. Moving SHALL take it off the other plugin's list and add it to this one; cancelling SHALL change nothing.

#### Scenario: Markdown files in Plain Text

- **WHEN** the user adds `md` in the Plain Text pane
- **THEN** the pane says Markdown opens `md` and offers Move; after Move, `.md` files open in Plain Text and `md` is gone from the Markdown pane

### Requirement: A plugin pane rebinds the plugin's commands

Each plugin pane SHALL list the plugin's commands, each with its shortcut in a key recorder and a reset to the default. The recorder SHALL refuse a key without a modifier, and a shortcut that another command of the same plugin or an app menu item already uses, naming it. A refusal's reason SHALL stay shown until the next recording and SHALL be announced to VoiceOver. A recorded shortcut SHALL work in open windows at once.

#### Scenario: Rebinding Highlight Selection

- **WHEN** the user records Command-Shift-H for Highlight Selection in the PDF pane
- **THEN** Command-Shift-H highlights the selection in PDFs, including ones already open

#### Scenario: A taken key

- **WHEN** the user records Command-S for a command
- **THEN** the recorder refuses it, saying the Save menu item uses it, and the shortcut stays as it was

#### Scenario: The reason stays and is heard

- **WHEN** the recorder refuses Command-P while VoiceOver runs
- **THEN** VoiceOver reads that Print uses it, and the reason stays under the recorder until the user records again

### Requirement: Permissions shows what the Peek panel needs

The Permissions pane SHALL show whether Accessibility and permission to control Finder are granted, not granted, or not asked yet, and SHALL update within two seconds of a change while it's open. Each row SHALL say what the permission is for and offer Grant Access, which opens the matching page of System Settings or, for Finder when not asked yet, shows the system's request. The pane SHALL show nothing else.

#### Scenario: Granting Accessibility

- **WHEN** the Permissions pane shows Accessibility as not granted and the user grants it in System Settings
- **THEN** the row shows it as granted within two seconds, without reopening Settings

#### Scenario: Only permissions

- **WHEN** the user opens the Permissions pane
- **THEN** it shows Accessibility and Control Finder, and no Open at Login or Default app

### Requirement: General turns Open at Login on and off

The General pane SHALL have an Open at Login switch showing whether Peeker opens at login, and when the system still needs the user's approval, a note saying so with a button that opens Login Items in System Settings. A failure to change it SHALL be reported in an alert.

#### Scenario: Turning on Open at Login

- **WHEN** the user turns on Open at Login in the General pane
- **THEN** Peeker starts at the next login, and the switch stays on when Settings is reopened

### Requirement: General shows whether Peeker is the default app

For each plugin, the General pane SHALL say whether Peeker is the default app for all, some (as a count) or none of the plugin's extensions, with Make Default to make it the default for all of them. When it's the default for some, the row SHALL expand to one row per extension, naming the current default app, each with its own Make Default. Extensions the system has no file type for SHALL be listed as ones Peeker can't set.

#### Scenario: Partly the default

- **WHEN** Peeker is the default for `.md` but not `.markdown`
- **THEN** the Markdown row says 1 of 2, and expanding it shows `markdown` with its current app and a Make Default button

#### Scenario: Making Peeker the default for PDFs

- **WHEN** the user clicks Make Default on the PDF row
- **THEN** double-clicking a PDF in Finder opens it in Peeker

### Requirement: A change in Settings rewrites the config file

A change made in Settings SHALL write the whole config file: every setting, defaults included, with sorted keys and the `$schema` key, creating the file and its folder when missing. Keys the app doesn't understand, values it couldn't use and extensions another plugin keeps SHALL be left out. Opening Settings or editing the file by hand SHALL NOT write it. A failed write SHALL be reported in an alert and change nothing.

#### Scenario: First change with no config file

- **WHEN** there's no `config.json` and the user turns off the Image plugin in Settings
- **THEN** `config.json` is created with every setting, `plugins.image.enabled` false, keys sorted

#### Scenario: A typo is dropped

- **WHEN** the config holds `plugins.image.enabeld` and the user changes any setting in Settings
- **THEN** the rewritten file no longer has `enabeld`, and the Config File pane lists no problems

#### Scenario: A symlinked config

- **WHEN** `config.json` is a symlink into a dotfiles repository and the user changes a setting
- **THEN** the target file holds the change and `config.json` is still a symlink

### Requirement: Settings locks while the config can't be used

While the config file isn't valid JSON or can't be read, every control that changes the config SHALL be disabled, and the window SHALL say why and offer Open in Editor. The controls SHALL unlock as soon as a saved file can be read. Controls that don't change the config (Permissions, Open at Login and Default app) SHALL stay usable.

#### Scenario: Broken JSON

- **WHEN** the user saves the config with a missing brace while Settings is open
- **THEN** the switches, lists and recorders are disabled with a note that the file isn't valid JSON, and they come back once the brace is fixed and saved

#### Scenario: Open at Login while locked

- **WHEN** the config isn't valid JSON and the user turns on Open at Login in General
- **THEN** the switch works

### Requirement: Settings follows changes to the file

While Settings is open, a change saved to the config file by another app SHALL show in every pane within a second.

#### Scenario: Editing by hand

- **WHEN** Settings shows the Image pane and the user saves `"enabled": false` for Image in an editor
- **THEN** the Image switch turns off without reopening Settings

### Requirement: The Permissions row shows a missing permission

While the Peek panel key is on and Accessibility isn't granted, the Permissions row in the sidebar SHALL show a red dot. The dot SHALL go away once Accessibility is granted or the key is turned off.

#### Scenario: Before granting Accessibility

- **WHEN** Peeker runs without Accessibility and the Peek panel key is Space
- **THEN** the Permissions row in the sidebar shows a red dot

### Requirement: General's sections

The General pane SHALL show, in this order, the Peek panel key, Open at Login, the Default app list and the update controls.

#### Scenario: Opening General

- **WHEN** the user opens the General pane
- **THEN** it shows the Peek panel section first, then Open at Login, Default app and Updates
