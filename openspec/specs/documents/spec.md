# documents Specification

## Purpose

How open files behave in windows, whatever their format: edited state, saving, the prompts that protect unsaved edits, following changes made on disk, and bringing unsaved edits back after the app crashes.

## Requirements

### Requirement: One window per file, tabbed

Each open file SHALL get its own Editor window, and Editor windows SHALL join as tabs. Opening a file that is already open SHALL bring its window forward instead of opening a second copy.

#### Scenario: Opening an open file again

- **WHEN** the user opens a file that already has a window
- **THEN** that window comes to the front and no new window opens

### Requirement: Saving is explicit and done by the owning plugin

Edits made in the Editor SHALL reach the file only through Cmd+S; there SHALL be no autosave. The host SHALL send the edits to the plugin that opened the document, and that plugin SHALL write the file. Edits made while a save is running SHALL stay pending after it.

#### Scenario: Typing during a save

- **WHEN** the user keeps typing while a save is in flight
- **THEN** the save writes the text as it was when the save started, and the document stays marked edited for the newer typing

#### Scenario: Ticking a Markdown task

- **WHEN** the user clicks a task box in a Markdown file in the Editor
- **THEN** the file on disk changes only when the user saves

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

### Requirement: Failed or unfinished saves keep the edits

A save that fails for any reason SHALL show why in a sheet and leave the edits on screen and pending, so the user can retry or copy them out. A save the user cancels partway, such as at a password the plugin asks for, SHALL show nothing more and SHALL also leave the edits pending. A save that hasn't finished SHALL NOT trap the window: closing it SHALL still ask about the unsaved edits, and the file SHALL end up either fully written or untouched.

#### Scenario: Write fails

- **WHEN** the save can't write because the file's folder was deleted
- **THEN** the window shows the failure, the edits stay, and a later Cmd+S can still save them once the folder is back

#### Scenario: Cancelled at a password

- **WHEN** a save asks for a password and the user clicks Cancel
- **THEN** no failure is shown, the file is unchanged, and the edits stay pending

#### Scenario: Closing during a slow save

- **WHEN** the user closes a window while its save is still writing to a slow network drive
- **THEN** the close asks Save, Don't Save or Cancel as usual, and the file is never left half written

### Requirement: Unsaved edits are never discarded without asking

Closing a tab or window, switching Open With, reverting to the saved version, or quitting SHALL ask before discarding each document's unsaved edits. Closing, switching and quitting SHALL ask Save, Don't Save (Cmd+D) or Cancel; Revert to Saved… SHALL ask Revert or Cancel. Quitting SHALL bring each such window forward in turn, and the first Cancel SHALL stop the quit. Don't Save and Revert SHALL return the document to its last loaded or saved state.

#### Scenario: Quit with two edited windows

- **WHEN** the user quits with unsaved edits in two windows and cancels at the second prompt
- **THEN** the first window is resolved and closed, the second stays open with its edits, and the app keeps running

#### Scenario: Cancelling a revert

- **WHEN** the user chooses Revert to Saved… and then Cancel
- **THEN** the document keeps its unsaved edits

### Requirement: Documents follow changes on disk

The host SHALL watch each open file, including through atomic replacements by other apps and a file that is deleted and created again. When the file changes and the document has no unsaved edits, it SHALL reload in place. A change on disk SHALL never replace unsaved edits; saving asks about it instead.

#### Scenario: A growing log

- **WHEN** another process appends to an open log with no unsaved edits
- **THEN** the tab reloads and shows the new lines

#### Scenario: Change while editing

- **WHEN** the file changes on disk while the document has unsaved edits
- **THEN** the edits stay on screen, and the next save asks before overwriting the newer file

### Requirement: Unsaved edits survive a crash of the app

About 2 seconds after the last edit, the host SHALL write a recovery copy of the document's unsaved edits to `~/Library/Application Support/<bundle id>/Recovery/`, or to the folder in `$PEEKER_RECOVERY` when that's set, readable only by the user, and never next to or over the real file. The next launch SHALL look for recovery copies in the same folder. The copy SHALL be removed when the edits are saved or discarded, and a document closed without edits SHALL leave no copy.

#### Scenario: Save clears the recovery copy

- **WHEN** a document with a recovery copy is saved
- **THEN** its recovery copy is deleted

#### Scenario: A test run keeps its recovery copies apart

- **WHEN** the app runs with `$PEEKER_RECOVERY` set to a folder, a document is edited, and the app is killed
- **THEN** the recovery copy is in that folder, nothing is written to the default folder, and a launch without `$PEEKER_RECOVERY` restores nothing from that run

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

### Requirement: Document windows have a minimum size

An Editor window SHALL NOT shrink below about 480 by 320 points.

#### Scenario: Shrinking a window

- **WHEN** the user drags an Editor window's corner inward as far as it goes
- **THEN** the window stops at its minimum size, with the toolbar and content still shown

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

### Requirement: A tab keeps a history of followed links

Each Editor tab SHALL keep a history of the places links took it: the file it opened at, then each heading or file a followed link reached. Back and Forward SHALL move through it, any number of steps, returning to each place at the scroll position it was left at and with the plugin it was shown with. Following a link after going Back SHALL drop the places ahead. The window's title, proxy icon and Open With SHALL follow the file shown.

#### Scenario: Back to the previous file

- **WHEN** the user scrolls halfway down `README.md`, follows a link to `other.md`, then goes Back
- **THEN** the tab shows `README.md` again, scrolled halfway down, titled `README.md`

#### Scenario: Several steps

- **WHEN** the user follows `#install`, then `other.md`, then goes Back twice and Forward once
- **THEN** the tab shows `README.md` at Install

#### Scenario: A new jump drops the places ahead

- **WHEN** the user goes from `README.md` to `a.md`, goes Back, then follows a link to `b.md`
- **THEN** Forward is unavailable and `a.md` is no longer in the history

#### Scenario: A place whose file is gone

- **WHEN** the user goes Back to a file that was deleted since
- **THEN** Peeker beeps and the tab stays where it was

### Requirement: History lasts as long as the tab

A tab's history SHALL end when the tab closes. It SHALL not be saved: after a quit or a crash, a reopened file and a window brought back by crash recovery SHALL start with no history.

#### Scenario: After a crash

- **WHEN** the user follows links in a tab, edits the file the tab shows, and the app is killed
- **THEN** on the next launch that file reopens with the edits and with Back unavailable

### Requirement: Back and Forward controls

An Editor window SHALL show Back and Forward as toolbar buttons at the leading end, after the sidebar button, while its document follows links or its tab has history. Go > Back (Cmd-[) and Go > Forward (Cmd-]) SHALL do the same. Each SHALL be greyed out, not hidden, when there's no place in its direction, and the Go items SHALL be greyed out when no Editor window is in front.

#### Scenario: A freshly opened file

- **WHEN** the user opens a Markdown file
- **THEN** the toolbar shows Back and Forward greyed out, and so are Go > Back and Go > Forward

#### Scenario: After a jump

- **WHEN** the user follows a heading link and presses Cmd-[
- **THEN** the view returns to where it was, and Forward becomes available

#### Scenario: A document that doesn't follow links

- **WHEN** a PDF is open in the Editor
- **THEN** its toolbar has no Back or Forward buttons, and Go > Back and Go > Forward are greyed out

### Requirement: The history trail

While a tab's history holds more than one place, a one-line trail SHALL show under the toolbar listing every place in order, the current one marked: a heading by its title, a file by its name. Clicking a crumb SHALL go to that place as Back or Forward would. When the trail doesn't fit, the oldest crumbs SHALL be cut first; each crumb's tooltip SHALL give its file name and heading.

#### Scenario: The trail after two jumps

- **WHEN** the user follows `#install` in `README.md` and then a link to `other.md`
- **THEN** the trail reads `README.md › Install › other.md` with `other.md` marked

#### Scenario: Clicking a crumb

- **WHEN** the user clicks the `README.md` crumb in that trail
- **THEN** the tab shows `README.md` where it was left, and the trail still lists all three with `README.md` marked

#### Scenario: No history

- **WHEN** a file has just opened in a tab
- **THEN** no trail shows

### Requirement: Leaving a file through a link asks about unsaved edits

When a link, Back, Forward or a crumb would show another file in a tab whose document has unsaved edits, Peeker SHALL first ask Save, Don't Save (Cmd+D) or Cancel, with the sheet closing the tab shows. Cancel SHALL keep the file, its edits and the history as they were. Moving within the same file SHALL never ask.

#### Scenario: Cancel stays

- **WHEN** the user types in `README.md`, Cmd-clicks a link to `other.md`, and chooses Cancel
- **THEN** the tab still shows `README.md` with the typing, and Back is as it was

#### Scenario: Don't Save goes on

- **WHEN** the user chooses Don't Save at that prompt
- **THEN** the tab shows `other.md`, and going Back shows `README.md` as last saved

#### Scenario: A heading in the same file

- **WHEN** the user has unsaved edits and follows a `#install` link
- **THEN** the view moves to Install without asking

### Requirement: A file open elsewhere comes forward

When a link, Back, Forward or a crumb would show a file in a tab while another Editor window already has that file open, that window SHALL come forward instead, and the tab and its history SHALL stay as they were.

#### Scenario: Linked file already open

- **WHEN** `other.md` is open in one tab and the user follows a link to it from `README.md` in another
- **THEN** the `other.md` tab comes forward and the `README.md` tab is unchanged

### Requirement: Save As writes a copy and the window follows it

File > Save As… (Shift+Cmd+S) SHALL ask, in a sheet, for a name and folder, write the file there with its unsaved edits, and then show the new file in the same window, keeping its scroll position and zoom. The original file SHALL stay as it was on disk. The new file SHALL keep the original's format and extension. The window's title, Open Recent, watching for changes on disk and crash recovery SHALL follow the new file. The Peek panel SHALL NOT offer Save As.

#### Scenario: Keeping the original

- **WHEN** the user adds a text box to `form.pdf` and chooses Save As… with the name `form filled.pdf`
- **THEN** `form filled.pdf` holds the text box, `form.pdf` is unchanged on disk, and the window's title reads `form filled.pdf`

#### Scenario: Working on after Save As

- **WHEN** the user saves `notes.txt` as `draft.txt` and then types and presses Cmd+S
- **THEN** `draft.txt` gets the typing and `notes.txt` stays as it was

#### Scenario: Undo after Save As

- **WHEN** the user types in `notes.txt`, saves it as `draft.txt` and chooses Undo
- **THEN** the typing is undone in the window, and `draft.txt` shows as edited

### Requirement: Save As copies read-only files and leaves open ones alone

A file with no unsaved edits, or a read-only one, SHALL be copied as it is. Saving over a file that's open in another Peeker window SHALL be refused with the reason.

#### Scenario: A read-only file

- **WHEN** the user chooses Save As… on a digitally signed PDF
- **THEN** the copy is the same bytes as the original

#### Scenario: The destination is open elsewhere

- **WHEN** the user picks a file that another Peeker window shows
- **THEN** nothing is written and Peeker says the file is open in another window
