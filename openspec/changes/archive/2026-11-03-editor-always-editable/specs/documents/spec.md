## ADDED Requirements

### Requirement: The Editor is always editable

Opening a file in a window SHALL open it in the Editor, ready to edit: there SHALL be no read view, no Edit button, no Edit Mode menu item and no Cmd+E. The plugin's edit tools SHALL be in the toolbar and the Tools menu from the start. Nothing SHALL change the file until the user edits it and saves. The Peek panel SHALL only view.

#### Scenario: Opening a PDF

- **WHEN** the user double-clicks a PDF that Peeker opens
- **THEN** its window shows Text Box, Sign and Highlight in the toolbar, with no Edit button

#### Scenario: Peek's Open

- **WHEN** the user presses Open in Peeker in the Peek panel on an image
- **THEN** the image opens in the Editor with Crop and Rotate & Resize ready

### Requirement: A file can be read-only, with the reason

A document SHALL be able to say its file can't be edited, with the reason. The Editor SHALL then show the edit tools greyed out with the reason as their tooltip, show a one-line note under the toolbar giving the reason, and answer an edit tool's shortcut with the reason instead of running it.

#### Scenario: A digitally signed PDF

- **WHEN** the user opens a digitally signed PDF
- **THEN** the edit tools are greyed out, and a note under the toolbar says changing it would break the signature

#### Scenario: A tool's shortcut on a read-only file

- **WHEN** a file can't be edited and the user presses Ctrl+Cmd+T
- **THEN** a message gives the reason and nothing changes

### Requirement: Edits happen in the Editor and show as edited

Only the Editor SHALL allow edits; the Peek panel SHALL only view. A document with unsaved edits SHALL show the standard edited mark in its window's close button, and File > Save SHALL be enabled only while there are unsaved edits and no save is running.

#### Scenario: First edit

- **WHEN** the user types into a text file in the Editor
- **THEN** the close button shows the edited mark and File > Save becomes available

#### Scenario: Filling a form field

- **WHEN** a PDF form is open in the Editor and the user types into a field
- **THEN** the field changes and the document is marked edited

## REMOVED Requirements

### Requirement: Edits happen in windows and show as edited
**Reason**: Restated for the always-editable Editor, without the read view.
**Migration**: See "Edits happen in the Editor and show as edited".

### Requirement: Documents with an edit mode open in a read view
**Reason**: There is no read view or Edit mode any more; the Peek panel is the view.
**Migration**: See "The Editor is always editable".

### Requirement: Leaving Edit mode asks about unsaved changes
**Reason**: There is no Edit mode to leave. Closing with unsaved edits still asks (see "Unsaved edits are never discarded without asking").
**Migration**: None.

### Requirement: Edit mode can be unavailable, with the reason
**Reason**: With no Edit button, a file that can't be edited shows greyed tools and a note instead.
**Migration**: See "A file can be read-only, with the reason".

### Requirement: A tool's shortcut switches to Edit mode
**Reason**: Edit tools always work in the Editor, so their shortcuts just run.
**Migration**: None.

### Requirement: Recovered edits reopen in Edit mode
**Reason**: Every file opens editable, so recovered edits reopen like any file (see "Recovered edits come back on the next launch").
**Migration**: None.

## MODIFIED Requirements

### Requirement: One window per file, tabbed

Each open file SHALL get its own Editor window, and Editor windows SHALL join as tabs. Opening a file that is already open SHALL bring its window forward instead of opening a second copy.

#### Scenario: Opening an open file again

- **WHEN** the user opens a file that already has a window
- **THEN** that window comes to the front and no new window opens

### Requirement: Saving is explicit and done by the owning plugin

Edits made in the Editor SHALL reach the file only through Cmd+S; there SHALL be no autosave. (A plugin tool that writes the file directly, such as ticking a Markdown task, is not an edit and is specified by its plugin.) The host SHALL send the edits to the plugin that opened the document, and that plugin SHALL write the file. Edits made while a save is running SHALL stay pending after it.

#### Scenario: Typing during a save

- **WHEN** the user keeps typing while a save is in flight
- **THEN** the save writes the text as it was when the save started, and the document stays marked edited for the newer typing

### Requirement: Document windows have a minimum size

An Editor window SHALL NOT shrink below about 480 by 320 points.

#### Scenario: Shrinking a window

- **WHEN** the user drags an Editor window's corner inward as far as it goes
- **THEN** the window stops at its minimum size, with the toolbar and content still shown
