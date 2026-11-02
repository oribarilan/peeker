## Purpose

Pressing Space on a file in Finder shows it in Peeker's floating Peek panel instead of Finder's Quick Look, quickly and without taking focus from Finder, for every file type an enabled plugin supports.

## ADDED Requirements

### Requirement: Space in Finder opens the Peek panel

While the app runs, the Peek panel key (Space unless the config's `peekPanel.key` says otherwise) SHALL show Finder's selected file in a floating panel when an enabled plugin supports it. A bare key SHALL work only while Finder is frontmost and no text field has focus, so typing a space anywhere else is untouched. A key with modifiers SHALL work from any app. `"off"` SHALL turn the Peek panel off. A changed key SHALL take effect as soon as the config is saved.

#### Scenario: Space on a PDF

- **WHEN** the user selects a PDF in Finder and presses Space
- **THEN** the Peek panel shows the PDF and Finder's Quick Look doesn't open

#### Scenario: Renaming a file

- **WHEN** the user presses Space while renaming a file in Finder
- **THEN** a space is typed into the name and no panel opens

#### Scenario: Changing the key

- **WHEN** the user saves `{"peekPanel": {"key": "opt+space"}}`
- **THEN** Option+Space opens the Peek panel from then on, and plain Space goes back to Finder's Quick Look

### Requirement: Unsupported files still get Quick Look

When no enabled plugin opens the selected file, the key SHALL go to Finder, so its own Quick Look works as usual.

#### Scenario: Space on a video

- **WHEN** the user presses Space on a video file, which no plugin supports
- **THEN** Finder's Quick Look opens it

### Requirement: The Peek panel never takes focus from Finder

The Peek panel SHALL float above other windows without activating the app, so Finder stays frontmost. While it shows, Escape or the same key SHALL close it, and the arrow keys SHALL move Finder's selection, with the panel following the new file. Moving to a file no plugin supports SHALL close the panel.

#### Scenario: Browsing with arrow keys

- **WHEN** the Peek panel shows a file and the user presses the down arrow
- **THEN** Finder selects the next file and the panel shows it

### Requirement: The Peek panel views; Open moves the file to a window

The Peek panel SHALL only view, never edit. Its Open button SHALL close the panel and open the file in a document window, where it can be edited.

#### Scenario: Edit from the Peek panel

- **WHEN** the user clicks Open in the Peek panel on a text file
- **THEN** the panel closes and the file opens in an editable window

### Requirement: The Peek panel is at least as fast as Quick Look

For every benchmark file, Space with Peeker running SHALL show the Peek panel no slower than Finder's Quick Look shows its own for the same file: faster, or within 10% (the benchmarks' "about the same"). Both SHALL be timed the same way by `bench/spacebench.swift`.

#### Scenario: A 12 MP photo

- **WHEN** spacebench presses Space on the 12 MP JPEG fixture, once with Quick Look and once with Peeker
- **THEN** Peeker's median is lower than Quick Look's, or at most 10% higher

### Requirement: The app asks for the permissions the Peek panel needs

The Peek panel needs Accessibility (to see the key system-wide) and Automation for Finder (to read the selection). Without Accessibility, the app SHALL ask once, then start watching the key as soon as it's granted, without a relaunch. The Permissions pane in Settings SHALL show both permissions' status and lead to where each is granted.

#### Scenario: Granting Accessibility later

- **WHEN** the user grants Accessibility after launching the app
- **THEN** the Peek panel starts working within a few seconds, without restarting Peeker

#### Scenario: Finding out why Space does nothing

- **WHEN** Space in Finder does nothing and the user opens the Permissions pane
- **THEN** the pane shows which permission is missing, with Grant Access next to it

### Requirement: The app can open at login

Open at Login, in the menu bar icon's menu and in Settings' General pane, SHALL register or unregister the app as a login item, because the Peek panel only works while the app runs. The app menu SHALL NOT have it. A failure SHALL be reported in an alert.

#### Scenario: Turning on Open at Login

- **WHEN** the user chooses Open at Login
- **THEN** Peeker starts at the next login and the Peek panel works without launching it by hand

#### Scenario: The app menu

- **WHEN** a document window is open and the user opens the Peeker menu
- **THEN** it has Settings… but no Open at Login
