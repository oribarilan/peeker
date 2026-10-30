# documents Specification

## Purpose

How open files behave in windows, whatever their format: edited state, saving, the prompts that protect unsaved edits, following changes made on disk, and bringing unsaved edits back after the app crashes.

## Requirements

### Requirement: One window per file, tabbed

Each open file SHALL get its own document window, and document windows SHALL join as tabs. Opening a file that is already open SHALL bring its window forward instead of opening a second copy.

#### Scenario: Opening an open file again

- **WHEN** the user opens a file that already has a window
- **THEN** that window comes to the front and no new window opens

### Requirement: Edits happen in windows and show as edited

Only document windows SHALL allow edits; the quick-look panel SHALL only view. A document with unsaved edits SHALL show the standard edited mark in its window's close button, and File > Save SHALL be enabled only while there are unsaved edits and no save is running.

#### Scenario: First edit

- **WHEN** the user types into a text file in a window
- **THEN** the close button shows the edited mark and File > Save becomes available

### Requirement: Saving is explicit and done by the owning plugin

Edits made in a document window SHALL reach the file only through Cmd+S; there SHALL be no autosave. (A plugin command that writes the file directly, such as ticking a Markdown task, is not an edit and is specified by its plugin.) The host SHALL send the edits to the plugin that opened the document, and that plugin SHALL write the file. Edits made while a save is running SHALL stay pending after it.

#### Scenario: Typing during a save

- **WHEN** the user keeps typing while a save is in flight
- **THEN** the save writes the text as it was when the save started, and the document stays marked edited for the newer typing

### Requirement: Writes never damage the file

Every save SHALL replace the file atomically: on any failure the original SHALL be left as it was. A save SHALL keep the file's permissions and, through a symlink, write the file the link points to. A save SHALL fail with a clear message, without writing, when the folder no longer exists, when a symlink's target is gone, or when the user lacks permission.

#### Scenario: Saving through a symlink

- **WHEN** the user saves a file opened through a symlink
- **THEN** the link's target gets the new content and the link stays a link

#### Scenario: Read-only file

- **WHEN** the user saves edits to a file they can't write
- **THEN** the save fails with a message saying they don't have permission, and the edits stay in the window

### Requirement: Saving asks before overwriting someone else's change

Before writing, a save SHALL check the file on disk. If it changed since it was opened or last saved, the save SHALL ask before replacing the newer version. If it was deleted or moved, the save SHALL ask before creating it again. Declining SHALL leave the edits pending.

#### Scenario: File changed by another app

- **WHEN** the user saves after another app modified the file
- **THEN** a sheet says the file changed on disk, offering Save Anyway or Cancel

#### Scenario: File deleted meanwhile

- **WHEN** the user saves after the file was deleted
- **THEN** a sheet says the file no longer exists, offering to save and create it again

### Requirement: A failed save keeps the edits

A save that fails for any reason, including the plugin crashing or timing out, SHALL show why in a sheet and leave the edits on screen and pending, so the user can retry or copy them out.

#### Scenario: Plugin crashes during save

- **WHEN** the plugin crashes while writing
- **THEN** the window shows the failure, the edits stay, and a later Cmd+S can still save them

### Requirement: Unsaved edits are never discarded without asking

Closing a tab or window, switching Open With, or quitting SHALL ask Save, Don't Save (Cmd+D) or Cancel for each document with unsaved edits. Quitting SHALL bring each such window forward in turn, and the first Cancel SHALL stop the quit. Don't Save SHALL return the document to its last loaded or saved state.

#### Scenario: Quit with two edited windows

- **WHEN** the user quits with unsaved edits in two windows and cancels at the second prompt
- **THEN** the first window is resolved and closed, the second stays open with its edits, and the app keeps running

### Requirement: Documents follow changes on disk

The host SHALL watch each open file, including through atomic replacements by other apps and a file that is deleted and created again. When the file changes and the document has no unsaved edits, it SHALL reload in place. A change on disk SHALL never replace unsaved edits; saving asks about it instead.

#### Scenario: A growing log

- **WHEN** another process appends to an open log with no unsaved edits
- **THEN** the tab reloads and shows the new lines

#### Scenario: Change while editing

- **WHEN** the file changes on disk while the document has unsaved edits
- **THEN** the edits stay on screen, and the next save asks before overwriting the newer file

### Requirement: Unsaved edits survive a crash of the app

About 2 seconds after the last edit, the host SHALL write a recovery copy of the document's unsaved edits to `~/Library/Application Support/<bundle id>/Recovery/`, readable only by the user, and never next to or over the real file. The copy SHALL be removed when the edits are saved or discarded, and a document closed without edits SHALL leave no copy.

#### Scenario: Save clears the recovery copy

- **WHEN** a document with a recovery copy is saved
- **THEN** its recovery copy is deleted

### Requirement: Recovered edits come back on the next launch

After the app stopped without quitting (crash or force quit), the next launch SHALL reopen each file that had a recovery copy in a window, with the edits applied and the document marked edited. Only the newest copy per file SHALL be used. If the file changed on disk since the edits were made, the window SHALL say so, and saving SHALL ask before replacing the newer version.

#### Scenario: Force quit with unsaved text

- **WHEN** the app is force-quit with unsaved edits and launched again
- **THEN** the file reopens with the edits in place, marked edited, and nothing was written to the file

### Requirement: Recovered edits that can't go back into a window aren't silently lost

When recovered text can't be reopened (its file is gone, no enabled plugin opens it, or the file now opens read-only), the text SHALL go to the clipboard, several texts together under their file paths, with an alert saying why. Its recovery copy SHALL be removed only once the clipboard accepted it. Recovered highlights whose file is gone or has no enabled plugin SHALL be reported in an alert and dropped. Recovered highlights the current view can't show SHALL be kept for a later open.

#### Scenario: File deleted before relaunch

- **WHEN** the app relaunches with recovered text for a file that no longer exists
- **THEN** the text is on the clipboard and an alert says the file no longer exists
