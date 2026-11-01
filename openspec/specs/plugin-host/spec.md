# plugin-host Specification

## Purpose

How the app finds its format plugins, runs them, and keeps working when one fails. Each plugin is a Swift module built into the app that draws its own content, isolated from the host and other plugins in code.

## Requirements

### Requirement: Plugins are built into the app

Each plugin SHALL be code built into the app that declares an id, a display name and the file extensions it opens by default. A plugin SHALL do no work until the first file routed to it opens.

#### Scenario: Launch without files

- **WHEN** the app launches with no file to open
- **THEN** no plugin reads or decodes anything

### Requirement: Plugins draw their own content

A plugin SHALL provide the native views for its file's content and its sidebar panels, and the commands it offers. The host SHALL provide the window, tabs, toolbar, Open With and the menus that list plugin commands. Plugins that zoom SHALL use Cmd+= and Cmd+- for it.

#### Scenario: Highlighting a PDF selection

- **WHEN** the user runs Highlight Selection on a PDF
- **THEN** the PDF plugin's own view draws the highlight

### Requirement: Plugin code is isolated

A plugin's code SHALL be able to use only the shared plugin kit, never the host's internals or another plugin's code. The build SHALL enforce this.

#### Scenario: One plugin reaching into another

- **WHEN** the image plugin's code refers to a type that belongs to the PDF plugin
- **THEN** the app doesn't build

### Requirement: Slow file work never freezes the app

Reading, decoding and saving a file SHALL run off the main thread. While a file opens, its tab SHALL show that it's loading, and the rest of the app SHALL keep responding.

#### Scenario: Opening a large log

- **WHEN** the user opens an 86 MB log and immediately switches to another tab
- **THEN** the other tab responds at once, and the log appears when it's ready

### Requirement: Closing cancels pending work

Closing a tab or window, or moving the Space panel to another file, SHALL cancel that document's open in progress, and nothing from it SHALL be applied afterwards.

#### Scenario: Browsing past a large photo

- **WHEN** the Space panel starts opening a 48 MP photo and the user presses the down arrow
- **THEN** the panel shows the next file, and the photo never replaces it

### Requirement: A plugin error stays in its tab

When a plugin can't open a file, its tab SHALL show the reason and a Reopen button, while other tabs keep working. Reopen SHALL open the file afresh. A crash in plugin code MAY quit the app; unsaved edits then come back through crash recovery.

#### Scenario: Corrupt file

- **WHEN** the user opens a corrupt PDF
- **THEN** the tab says the file isn't a readable PDF, offers Reopen, and other tabs are unaffected

### Requirement: Unavailable commands

A document SHALL be able to report that one of its commands can't run right now, with a reason. The host SHALL then grey out that command's menu item and toolbar button, show the reason as the button's tooltip, and ignore its shortcut. When the document no longer reports a reason, the command SHALL work again without reopening the file.

#### Scenario: A command greyed out with its reason
- **WHEN** a document reports "This PDF's permissions don't allow page changes." for Rotate Left
- **THEN** Rotate Left is greyed out in the Commands menu and the toolbar, the toolbar button's tooltip shows that sentence, and Cmd+L does nothing

#### Scenario: Available again
- **WHEN** a command's reason goes away, such as Delete Page once not every page is selected
- **THEN** its menu item and button work again

### Requirement: Single-key shortcuts for edit tools

An edit tool's shortcut MAY be a single key with no Command, Option or Control. Such a shortcut SHALL run its tool only while the document is in Edit mode and no text field, text view or text box has keyboard focus; otherwise the key SHALL go where it would have gone. The Settings window's recorder SHALL accept single keys for edit tools and keep requiring a modifier for other commands.

#### Scenario: A letter in Edit mode
- **WHEN** an image is in Edit mode and the user presses C
- **THEN** cropping starts

#### Scenario: A letter in the read view
- **WHEN** an image is in the read view and the user presses C
- **THEN** nothing happens and Edit mode stays off

#### Scenario: Typing
- **WHEN** a text field has focus in Edit mode and the user types "c"
- **THEN** the "c" goes into the field

#### Scenario: Recording a single key
- **WHEN** the user records C for an edit tool in Settings
- **THEN** it's accepted; for a command that isn't an edit tool it's refused as before

### Requirement: Print from document windows

The File menu SHALL have Print (Cmd+P). In a document window it SHALL show the system print panel for the current document, as a sheet on the window, with the file's name as the job title. What prints SHALL be decided by the document's plugin and SHALL include unsaved edits, and typing in progress (such as in a PDF text box) SHALL count. Print SHALL be unavailable when no document window is in front, while the document is still opening or failed to open, and for a plugin that offers no printing.

#### Scenario: Printing a document
- **WHEN** the user presses Cmd+P in a document window showing an opened file
- **THEN** the system print panel opens as a sheet on that window, titled with the file's name

#### Scenario: Unsaved edits print
- **WHEN** a document has unsaved edits and the user prints it
- **THEN** the printout shows the document with those edits

#### Scenario: Nothing to print
- **WHEN** the front window is the Space panel or the Settings window, or the document is still opening
- **THEN** Print is greyed out

### Requirement: Find menu items

The Edit menu SHALL offer Find… (Cmd+F), Find Next (Cmd+G) and Find Previous (Shift+Cmd+G). Each SHALL reach the focused view's find, and SHALL be greyed out where the view offers no find. Because they are menu shortcuts, Settings SHALL refuse Cmd+P, Cmd+F, Cmd+G and Shift+Cmd+G for plugin commands, as it does other menu keys.

#### Scenario: Find Previous in a text file
- **WHEN** the user searched a text file and presses Shift+Cmd+G
- **THEN** the selection moves to the previous match

#### Scenario: No find in an image
- **WHEN** an image document is in front
- **THEN** Find…, Find Next and Find Previous are greyed out

#### Scenario: A menu key refused for a command
- **WHEN** the user records Cmd+P for a plugin command in Settings
- **THEN** the recorder refuses it and names Print

### Requirement: A document can replace itself

A document SHALL be able to hand the host another document for the same file, such as a PDF unlocked from its lock screen. The host SHALL then show the replacement as if it had just opened: its content, sidebar, commands, toolbar and edit mode.

#### Scenario: Unlocked PDF
- **WHEN** the lock screen of a PDF unlocks it
- **THEN** the tab shows the PDF with its thumbnails and info, and the Commands menu lists the PDF's commands

### Requirement: A document can show an active command

A document MAY name one of its commands as active, such as a tool waiting for its click, and SHALL tell the host when that changes. The host SHALL show the active command's toolbar button as selected and check its menu item, and show none selected when the document names none. A document that never names one SHALL look as before.

#### Scenario: A tool becomes active

- **WHEN** a PDF document names Text Box as its active command
- **THEN** the window's Text Box toolbar button shows as selected and Commands > Text Box is checked, until the document names none
