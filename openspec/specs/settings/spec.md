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

The General pane SHALL show an Automatic updates pop-up bound to `updates.automatic` with the choices Off, Check and Ask, and Download and Install; a "Show what's new after updating" checkbox bound to `updates.showWhatsNew`; a Check Now button; and the version of Peeker running. Changing either control SHALL apply at once and rewrite the config file like any other change in Settings; Check Now SHALL check right away whatever the pop-up says.

#### Scenario: Opting out

- **WHEN** the user picks Off in Automatic updates
- **THEN** `config.json` has `"updates": {"automatic": "off"}` and automatic checks stop

#### Scenario: Installing by itself

- **WHEN** the user picks Download and Install
- **THEN** `config.json` has `"updates": {"automatic": "download"}`, and the next update found downloads and installs without asking

#### Scenario: No what's-new window

- **WHEN** the user clears "Show what's new after updating"
- **THEN** `config.json` has `"updates": {"showWhatsNew": false}`, and the next update shows no what's-new window

#### Scenario: Checking by hand while opted out

- **WHEN** automatic updates are Off and the user clicks Check Now
- **THEN** Peeker checks right away and says what it found

### Requirement: Settings is a sidebar of panes

The Settings window SHALL show a sidebar of panes and the selected pane beside it. The sidebar SHALL list General, then Appearance, then one pane per plugin in sidebar order (Image, PDF, Markdown, Plain Text), each with the icon its plugin names, then Permissions and Config File. It SHALL open on General the first time, and afterwards on the pane last shown, also after a relaunch. The window SHALL resize but its zoom button SHALL be disabled.

#### Scenario: Opening Settings

- **WHEN** the user opens Settings for the first time
- **THEN** the sidebar lists General, Appearance, Image, PDF, Markdown, Plain Text, Permissions and Config File, and General is selected

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

The General pane SHALL show, in this order, the Peek panel key, Open at Login, the Default app list, the update controls and Tips.

#### Scenario: Opening General

- **WHEN** the user opens the General pane
- **THEN** it shows the Peek panel section first, then Open at Login, Default app, Updates and Tips

### Requirement: A tool's shortcut can be cleared

Each tool's shortcut in a plugin pane SHALL have a clear button that leaves the tool without a shortcut, applied at once and written as `"shortcut": "off"`. Reset SHALL bring the default back. A tool without a shortcut SHALL show that it has none.

#### Scenario: Clearing a shortcut

- **WHEN** the user clicks the clear button beside Text Box's shortcut in the PDF pane
- **THEN** `config.json` has `"shortcut": "off"` for text-box, Ctrl+Cmd+T no longer starts a text box, and the recorder shows no shortcut

### Requirement: A plugin pane rebinds the plugin's tools

Each plugin pane SHALL list the plugin's tools, each with its shortcut in a key recorder and a reset to the default. The recorder SHALL refuse a key without a modifier (except single keys for edit tools), and a shortcut that another tool of the same plugin or an app menu item already uses, naming it. A refusal's reason SHALL stay shown until the next recording and SHALL be announced to VoiceOver. A recorded shortcut SHALL work in open windows at once.

#### Scenario: Rebinding Highlight Selection

- **WHEN** the user records Command-Shift-H for Highlight Selection in the PDF pane
- **THEN** Command-Shift-H highlights the selection in PDFs, including ones already open

#### Scenario: A taken key

- **WHEN** the user records Command-S for a tool
- **THEN** the recorder refuses it, saying the Save menu item uses it, and the shortcut stays as it was

#### Scenario: The reason stays and is heard

- **WHEN** the recorder refuses Command-P while VoiceOver runs
- **THEN** VoiceOver reads that Print uses it, and the reason stays under the recorder until the user records again

### Requirement: Appearance sets the app's look

The Appearance pane SHALL have an Appearance control with System, Light and Dark, bound to `appearance`. System SHALL follow the Mac's appearance; Light and Dark SHALL hold every Peeker window, Settings and the Peek panel included, in that look. A choice SHALL apply at once and rewrite the config file. While the config file can't be used, the pane's controls SHALL be disabled.

#### Scenario: Dark app on a light Mac

- **WHEN** the Mac is light and the user picks Dark
- **THEN** `config.json` says `"appearance": "dark"`, and Settings and open windows turn dark at once

#### Scenario: Broken config

- **WHEN** `config.json` isn't valid JSON
- **THEN** the Appearance pane's controls are disabled

### Requirement: Appearance sets the text's look

The Appearance pane SHALL have a Text appearance control with Match App, Light and Dark, bound to `textAppearance`. It SHALL pick the light or dark variant of the text theme in Markdown and text files, in windows and the Peek panel, at once. Match App SHALL use the app's appearance. Toolbars, sidebars, notes and the Peek panel's frame SHALL keep the app's appearance.

#### Scenario: Light page in a dark app

- **WHEN** the app is Dark, the theme is Paper and the user picks Light for Text appearance
- **THEN** open Markdown windows show Paper's light background while their toolbar and sidebar stay dark

### Requirement: Appearance shows the themes as cards

The Appearance pane SHALL show the eight text themes as cards in four columns and two rows, in the themes' order. Each card SHALL show a short styled Markdown sample (a heading with its dimmed marker, a link, a code span and a task) in that theme's colors and in the variant Text appearance picks, with its name under it. The chosen card SHALL be marked. Clicking a card SHALL choose that theme at once and write `textTheme`.

#### Scenario: Picking Paper

- **WHEN** the user clicks the Paper card
- **THEN** `config.json` says `"textTheme": "paper"`, the Paper card is marked, and open Markdown and text windows turn Paper's colors

#### Scenario: Cards follow Text appearance

- **WHEN** the user switches Text appearance from Light to Dark
- **THEN** every card redraws in its theme's dark colors

#### Scenario: Cards for VoiceOver

- **WHEN** VoiceOver reads the cards
- **THEN** each reads as a button with its theme's name, and the chosen one as selected

### Requirement: General resets the Peek panel's size

The General pane's Peek panel section SHALL have a Reset Panel Size button, greyed out until the user has moved or resized the panel. It SHALL forget the panel's saved size and position, so the panel opens at its default size and place, including a panel showing at the time.

#### Scenario: Resetting

- **WHEN** the user has made the panel 600 × 500 points and clicks Reset Panel Size
- **THEN** the button greys out, and the next Space opens the panel at its default size, centered

#### Scenario: Nothing to reset

- **WHEN** the panel has never been moved or resized
- **THEN** Reset Panel Size is greyed out

### Requirement: Appearance turns the shortcut captions on and off

The Appearance pane SHALL have a "Show shortcuts in the toolbar" checkbox bound to `showShortcuts`, on by default. Changing it SHALL apply to every open window at once and rewrite the config file like any other change in Settings.

#### Scenario: Turning captions off

- **WHEN** the user clears "Show shortcuts in the toolbar"
- **THEN** `config.json` has `"showShortcuts": false` and the toolbars lose their key captions

### Requirement: General can show the tips again

The General pane SHALL have a Show Tips Again button, greyed out until at least one tip has been shown. It SHALL forget which tips were shown, so each tool's tip appears again on its next first use.

#### Scenario: Seeing a tip again

- **WHEN** the user has seen Highlight's tip and clicks Show Tips Again
- **THEN** the next Highlight shows its tip
