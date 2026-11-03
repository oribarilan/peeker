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

A plugin SHALL provide the native views for its file's content and its sidebar panels, and the tools it offers. The host SHALL provide the window, tabs, toolbar, Open With and the menus that list plugin tools (View and Tools). Plugins that zoom SHALL use Cmd+= and Cmd+- for it.

#### Scenario: Highlighting a PDF selection

- **WHEN** the user runs Highlight Selection on a PDF
- **THEN** the PDF plugin's own view draws the highlight

### Requirement: Plugin code is isolated

A plugin's code SHALL be able to use only the shared plugin kit, never the host's internals or another plugin's code. The build SHALL enforce this.

#### Scenario: One plugin reaching into another

- **WHEN** the image plugin's code refers to a type that belongs to the PDF plugin
- **THEN** the app doesn't build

### Requirement: Slow file work never freezes the app

Reading, decoding and saving a file SHALL run off the main thread. While a file opens in the Editor and nothing of it shows yet, a spinner SHALL appear in the middle of the content once the open has taken about half a second, and go away when the file or its failure appears. An open that finishes sooner SHALL never show it, and the Peek panel SHALL show none. The rest of the app SHALL keep responding.

#### Scenario: Opening a large log

- **WHEN** the user opens an 86 MB log and immediately switches to another tab
- **THEN** the other tab responds at once, and the log appears when it's ready

#### Scenario: A slow open shows a spinner

- **WHEN** opening a file in the Editor takes two seconds
- **THEN** a spinner shows in the middle of the empty content from about half a second on, and goes away when the file appears

#### Scenario: A fast open shows none

- **WHEN** a file opens in under half a second
- **THEN** no spinner is ever drawn

#### Scenario: A failed open replaces the spinner

- **WHEN** a slow open fails
- **THEN** the spinner goes away and the failure shows in its place

### Requirement: Closing cancels pending work

Closing a tab or window, or moving the Peek panel to another file, SHALL cancel that document's open in progress, and nothing from it SHALL be applied afterwards.

#### Scenario: Browsing past a large photo

- **WHEN** the Peek panel starts opening a 48 MP photo and the user presses the down arrow
- **THEN** the panel shows the next file, and the photo never replaces it

### Requirement: A plugin error stays in its tab

When a plugin can't open a file, its tab SHALL show the reason and a Reopen button, while other tabs keep working. Reopen SHALL open the file afresh. A crash in plugin code MAY quit the app; unsaved edits then come back through crash recovery.

#### Scenario: Corrupt file

- **WHEN** the user opens a corrupt PDF
- **THEN** the tab says the file isn't a readable PDF, offers Reopen, and other tabs are unaffected

### Requirement: Print from document windows

The File menu SHALL have Print (Cmd+P). In an Editor window it SHALL show the system print panel for the current document, as a sheet on the window, with the file's name as the job title. What prints SHALL be decided by the document's plugin and SHALL include unsaved edits, and typing in progress (such as in a PDF text box) SHALL count. Print SHALL be unavailable when no Editor window is in front, while the document is still opening or failed to open, and for a plugin that offers no printing.

#### Scenario: Printing a document
- **WHEN** the user presses Cmd+P in an Editor window showing an opened file
- **THEN** the system print panel opens as a sheet on that window, titled with the file's name

#### Scenario: Unsaved edits print
- **WHEN** a document has unsaved edits and the user prints it
- **THEN** the printout shows the document with those edits

#### Scenario: Nothing to print
- **WHEN** the front window is the Peek panel or the Settings window, or the document is still opening
- **THEN** Print is greyed out

### Requirement: Find menu items

The Edit menu SHALL offer Find… (Cmd+F), Find Next (Cmd+G) and Find Previous (Shift+Cmd+G). Each SHALL reach the focused view's find, and SHALL be greyed out where the view offers no find. Because they are menu shortcuts, Settings SHALL refuse Cmd+P, Cmd+F, Cmd+G and Shift+Cmd+G for plugin tools, as it does other menu keys.

#### Scenario: Find Previous in a text file
- **WHEN** the user searched a text file and presses Shift+Cmd+G
- **THEN** the selection moves to the previous match

#### Scenario: No find in an image
- **WHEN** an image document is in front
- **THEN** Find…, Find Next and Find Previous are greyed out

#### Scenario: A menu key refused for a command
- **WHEN** the user records Cmd+P for a plugin tool in Settings
- **THEN** the recorder refuses it and names Print

### Requirement: A document can replace itself

A document SHALL be able to hand the host another document for the same file, such as a PDF unlocked from its lock screen. The host SHALL then show the replacement as if it had just opened: its content, sidebar, tools, toolbar and whether it can be edited.

#### Scenario: Unlocked PDF
- **WHEN** the lock screen of a PDF unlocks it
- **THEN** the tab shows the PDF with its thumbnails and info, and the View and Tools menus list the PDF's tools

### Requirement: The View menu

View SHALL offer Show Sidebar or Hide Sidebar (Ctrl+Cmd+S), Show Toolbar or Hide Toolbar, and Enter Full Screen or Exit Full Screen, each titled for what it will do and greyed out where it can't act. The document's view tools SHALL follow them.

#### Scenario: Hiding the toolbar
- **WHEN** the user chooses View > Hide Toolbar in an Editor window
- **THEN** the toolbar goes away and the item reads Show Toolbar

### Requirement: The info sidebar shows and hides

An Editor window whose plugin shows sidebar panels SHALL have the system sidebar button at the leading end of its toolbar, over the sidebar, as in Finder. The button and View > Show/Hide Sidebar SHALL show and hide the sidebar. Whether the sidebar is shown, and its width, SHALL apply to every Editor window, and SHALL last through saves, reloads, Open With and relaunching. Where a document has no sidebar, the item SHALL be greyed out.

#### Scenario: Where the button sits
- **WHEN** the user opens a Markdown file with the sidebar shown
- **THEN** the sidebar button is over the sidebar next to the window buttons, and Open With is right of the sidebar

#### Scenario: Hidden stays hidden after a save
- **WHEN** the user hides the sidebar, edits the file and presses Cmd+S
- **THEN** the sidebar stays hidden

#### Scenario: The next window
- **WHEN** the user hides the sidebar in one window and then opens another file
- **THEN** the new window opens with its sidebar hidden

#### Scenario: Width is remembered
- **WHEN** the user drags the sidebar wider, quits and opens a file again
- **THEN** the sidebar opens at the width it had

### Requirement: File menu additions

File SHALL offer Open Recent, listing recently opened files with Clear Menu at the end; choosing a file SHALL open it as Open… would. File SHALL offer Open With, a submenu listing the plugins the toolbar's Open With control lists, with the current one checked, switching the same way. File SHALL offer Revert to Saved…, enabled only while the document has unsaved edits; it SHALL ask before discarding them, and confirming SHALL return the document to its last saved or loaded state.

#### Scenario: Reopening a recent file
- **WHEN** the user opened notes.md earlier and chooses File > Open Recent > notes.md
- **THEN** notes.md opens in the Editor

#### Scenario: Reverting
- **WHEN** a text document has unsaved edits and the user chooses Revert to Saved… and confirms
- **THEN** the text is back as last saved and the window no longer shows unsaved edits

#### Scenario: Nothing to revert
- **WHEN** a document has no unsaved edits
- **THEN** Revert to Saved… is greyed out

### Requirement: Standard app, window and help items

The Peeker menu SHALL offer Hide Others (Opt+Cmd+H) and Show All next to Hide Peeker. Window SHALL offer Minimize, Zoom and Bring All to Front alongside the tab items. A Help menu SHALL offer Peeker Help, which opens the project's page in the browser, and SHALL be the menu macOS adds its search field to.

#### Scenario: Help
- **WHEN** the user chooses Help > Peeker Help
- **THEN** the project's page opens in the default browser

### Requirement: Unavailable tools

A document SHALL be able to report that one of its tools can't run right now, with a reason. The host SHALL then grey out that tool's menu item and toolbar button, show the reason as the button's tooltip, and ignore its shortcut. When the document no longer reports a reason, the tool SHALL work again without reopening the file.

#### Scenario: A tool greyed out with its reason
- **WHEN** a document reports "This PDF's permissions don't allow page changes." for Rotate Left
- **THEN** Rotate Left is greyed out in the Tools menu and the toolbar, the toolbar button's tooltip shows that sentence, and Cmd+L does nothing

#### Scenario: Available again
- **WHEN** a tool's reason goes away, such as Delete Page once not every page is selected
- **THEN** its menu item and button work again

### Requirement: Single-key edit tool shortcuts

An edit tool's shortcut MAY be a single key with no Command, Option or Control. Such a shortcut SHALL run its tool in the Editor while no text field, text view or text box has keyboard focus; otherwise, and in the Peek panel, the key SHALL go where it would have gone. The Settings window's recorder SHALL accept single keys for edit tools and keep requiring a modifier for view tools.

#### Scenario: A letter in the Editor
- **WHEN** an image is open in the Editor and the user presses C
- **THEN** cropping starts

#### Scenario: Typing
- **WHEN** a text field has focus and the user types "c"
- **THEN** the "c" goes into the field

#### Scenario: Recording a single key
- **WHEN** the user records C for an edit tool in Settings
- **THEN** it's accepted; for a view tool it's refused as before

### Requirement: A document can show an active tool

A document MAY name one of its tools as active, such as a tool waiting for its click, and SHALL tell the host when that changes. The host SHALL show the active tool's toolbar button as selected and check its menu item, and show none selected when the document names none. A document that never names one SHALL look as before.

#### Scenario: A tool becomes active

- **WHEN** a PDF document names Text Box as its active tool
- **THEN** the window's Text Box toolbar button shows as selected and Tools > Text Box is checked, until the document names none

### Requirement: The menu bar holds seven menus

The menu bar SHALL hold Peeker, File, Edit, View, Tools, Window and Help, in that order, whichever window is in front and whatever its plugin. A document's view tools SHALL be listed in View and its edit tools in Tools, with the shortcuts they have.

#### Scenario: An image in front
- **WHEN** an image document is in front
- **THEN** View lists Zoom In, Zoom Out, Zoom to Fit and Actual Size, and Tools lists Crop and Rotate & Resize

#### Scenario: Switching tabs
- **WHEN** the user switches from a PDF tab to a Markdown tab
- **THEN** the same seven menus stay in the menu bar, and View and Tools list the Markdown document's tools

### Requirement: The Tools menu lists edit tools

Tools SHALL list the front document's edit tools. When the document has none, or no Editor window is in front, Tools SHALL still be in the menu bar, showing a greyed-out No Tools item.

#### Scenario: A Markdown file
- **WHEN** a Markdown document is in front
- **THEN** Tools shows only No Tools, greyed out

### Requirement: A tool can show it's on

A document MAY report, for a tool, whether it's on, such as Wrap Lines. While a tool is on, its menu item SHALL be checked and its toolbar button SHALL look pressed; when it's off, neither. A tool whose document reports nothing SHALL look as before.

#### Scenario: Wrap Lines on
- **WHEN** a text file has Wrap Lines on
- **THEN** View > Wrap Lines is checked and the toolbar's Wrap Lines button looks pressed

### Requirement: The toolbar groups view tools and edit tools

An Editor window's toolbar SHALL show the plugin's view tools and its edit tools as separate groups, each on its own piece of glass, with the edit tools after the view tools.

#### Scenario: A PDF

- **WHEN** a PDF is open in the Editor
- **THEN** the toolbar shows the edit tools (Text Box, Sign, Highlight, Rotate Left, Rotate Right, Delete Page) as one group, apart from any view tools

### Requirement: A tool can stay out of the toolbar

A plugin SHALL be able to mark a tool as menu-only. Such a tool SHALL be listed in its menu with its shortcut and SHALL have no toolbar button. Every zoom tool (Zoom In, Zoom Out, Zoom to Fit, Actual Size) SHALL be menu-only.

#### Scenario: Zoom only in View

- **WHEN** an image is open
- **THEN** View lists Zoom In, Zoom Out, Zoom to Fit and Actual Size with their shortcuts, and the toolbar has no zoom buttons

#### Scenario: A PDF fits

- **WHEN** a PDF is open in an Editor window of the default size
- **THEN** every edit tool shows as a toolbar button, none in the overflow menu

### Requirement: Tool buttons don't delay the first paint

When a file opens in the Editor, its content SHALL show before the window adds the document's tool buttons to the toolbar. Open With and the sidebar button SHALL be in the toolbar from the start.

#### Scenario: Opening a PDF

- **WHEN** the user opens a PDF
- **THEN** its pages show, and its tools join the toolbar in the next frame
