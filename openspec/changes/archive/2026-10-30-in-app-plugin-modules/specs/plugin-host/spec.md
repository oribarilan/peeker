# Spec Delta

## ADDED Requirements

### Requirement: Plugins are built into the app

Each plugin SHALL be code built into the app that declares an id, a display name and the file types it supports. A plugin SHALL do no work until the first file routed to it opens.

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

## REMOVED Requirements

### Requirement: Plugins ship inside the app

**Reason**: Plugins are no longer separate executables described by manifest files, so there's no manifest to break. Replaced by "Plugins are built into the app".

**Migration**: None for users.

### Requirement: Each plugin runs in its own process, started on demand

**Reason**: Plugins are now modules built into the app, not processes.

**Migration**: The `plugin.idle` config key no longer does anything; a config that still has it gets the usual unknown-key log line and works otherwise.

### Requirement: Plugins describe content and the host draws it

**Reason**: Plugins now draw their own content (see "Plugins draw their own content").

**Migration**: None for users. The host's per-format views move into their plugins.

### Requirement: Large content travels outside the message pipe

**Reason**: Without a process boundary there's no pipe; plugins hand the host views, not data.

**Migration**: None for users.

### Requirement: A failing plugin never takes the app down

**Reason**: Plugin code runs in the app, so a crash in it can quit the app, and a stuck plugin can't be killed. Errors and slow work are covered by "A plugin error stays in its tab", "Slow file work never freezes the app" and "Closing cancels pending work".

**Migration**: None for users; crash recovery brings back unsaved edits.

### Requirement: A plugin failure never loses unsaved edits

**Reason**: There is no separate plugin process to fail while the document stays open. A failed save keeps edits (documents), and a crash is covered by crash recovery (documents).

**Migration**: None for users.

### Requirement: Plugin output is logged

**Reason**: There's no plugin process output to capture. Plugins log through the unified system log like the rest of the app.

**Migration**: None for users.
