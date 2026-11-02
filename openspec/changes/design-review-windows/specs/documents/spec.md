## ADDED Requirements

### Requirement: Windows come back after a relaunch

When Peeker is launched by hand, the document windows open when it last quit SHALL come back, each with its file, the plugin it used, its place on screen and its tabs, showing the read view. None SHALL come back when the system's "Close windows when quitting an application" setting is on, or when Peeker starts at login. A moved or renamed file SHALL reopen from its new place; a deleted one SHALL NOT come back, without an alert. A file crash recovery reopens SHALL NOT get a second window.

#### Scenario: Two windows, one switched with Open With

- **WHEN** `notes.md` and `photo.png` are open, `notes.md` switched to Plain Text, and the user quits and opens Peeker again
- **THEN** both windows come back where they were, `notes.md` in Plain Text

#### Scenario: At login

- **WHEN** Peeker starts at login after quitting with windows open
- **THEN** no window comes back, and only the menu bar icon appears

#### Scenario: A deleted file

- **WHEN** a file that was open is deleted before the relaunch
- **THEN** its window doesn't come back and nothing is said about it

### Requirement: Document windows have a minimum size

A document window SHALL NOT shrink below about 480 by 320 points.

#### Scenario: Shrinking a window

- **WHEN** the user drags a document window's corner inward as far as it goes
- **THEN** the window stops at its minimum size, with the toolbar and content still shown
