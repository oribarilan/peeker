## ADDED Requirements

### Requirement: General's sections

The General pane SHALL show, in this order, the Peek panel key, Open at Login, the Default app list and the update controls.

#### Scenario: Opening General

- **WHEN** the user opens the General pane
- **THEN** it shows the Peek panel section first, then Open at Login, Default app and Updates

## RENAMED Requirements

- FROM: `### Requirement: General sets the quick-look key`
- TO: `### Requirement: General sets the Peek panel key`
- FROM: `### Requirement: Permissions shows what Space in Finder needs`
- TO: `### Requirement: Permissions shows what the Peek panel needs`
- FROM: `### Requirement: Permissions turns Open at Login on and off`
- TO: `### Requirement: General turns Open at Login on and off`
- FROM: `### Requirement: Permissions shows whether Peeker is the default app`
- TO: `### Requirement: General shows whether Peeker is the default app`

## MODIFIED Requirements

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

#### Scenario: Moving the panel to Option-Space

- **WHEN** the user records Option-Space
- **THEN** Option-Space opens the Peek panel from any app, and Space alone no longer does

#### Scenario: A bare letter

- **WHEN** the user presses J alone while recording
- **THEN** the recorder refuses it, says a key other than Space needs a modifier, and the key stays as it was

#### Scenario: Turning the panel off

- **WHEN** the user chooses Off
- **THEN** Space in Finder goes to Finder's Quick Look

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

### Requirement: Settings locks while the config can't be used

While the config file isn't valid JSON or can't be read, every control that changes the config SHALL be disabled, and the window SHALL say why and offer Open in Editor. The controls SHALL unlock as soon as a saved file can be read. Controls that don't change the config (Permissions, Open at Login and Default app) SHALL stay usable.

#### Scenario: Broken JSON

- **WHEN** the user saves the config with a missing brace while Settings is open
- **THEN** the switches, lists and recorders are disabled with a note that the file isn't valid JSON, and they come back once the brace is fixed and saved

#### Scenario: Open at Login while locked

- **WHEN** the config isn't valid JSON and the user turns on Open at Login in General
- **THEN** the switch works

### Requirement: The Permissions row shows a missing permission

While the Peek panel key is on and Accessibility isn't granted, the Permissions row in the sidebar SHALL show a red dot. The dot SHALL go away once Accessibility is granted or the key is turned off.

#### Scenario: Before granting Accessibility

- **WHEN** Peeker runs without Accessibility and the Peek panel key is Space
- **THEN** the Permissions row in the sidebar shows a red dot
