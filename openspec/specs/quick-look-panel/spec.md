# quick-look-panel Specification

## Purpose

Pressing Space on a file in Finder shows it in Peeker's floating panel instead of Quick Look, quickly and without taking focus from Finder, for every file type an enabled plugin supports.

## Requirements

### Requirement: Space in Finder opens the panel

While the app runs, the quick-look key (Space unless the config's `quicklook.key` says otherwise) SHALL show Finder's selected file in a floating panel when an enabled plugin supports it. A bare key SHALL work only while Finder is frontmost and no text field has focus, so typing a space anywhere else is untouched. A key with modifiers SHALL work from any app. `quicklook.key = off` SHALL turn the panel off.

#### Scenario: Space on a PDF

- **WHEN** the user selects a PDF in Finder and presses Space
- **THEN** Peeker's panel shows the PDF and Finder's Quick Look doesn't open

#### Scenario: Renaming a file

- **WHEN** the user presses Space while renaming a file in Finder
- **THEN** a space is typed into the name and no panel opens

### Requirement: Unsupported files still get Quick Look

When no enabled plugin opens the selected file, the key SHALL go to Finder, so its own Quick Look works as usual.

#### Scenario: Space on a video

- **WHEN** the user presses Space on a video file, which no plugin supports
- **THEN** Finder's Quick Look opens it

### Requirement: The panel never takes focus from Finder

The panel SHALL float above other windows without activating the app, so Finder stays frontmost. While it shows, Escape or the same key SHALL close it, and the arrow keys SHALL move Finder's selection, with the panel following the new file. Moving to a file no plugin supports SHALL close the panel.

#### Scenario: Browsing with arrow keys

- **WHEN** the panel shows a file and the user presses the down arrow
- **THEN** Finder selects the next file and the panel shows it

### Requirement: The panel views; Open moves the file to a window

The panel SHALL only view, never edit. Its Open button SHALL close the panel and open the file in a document window, where it can be edited.

#### Scenario: Edit from the panel

- **WHEN** the user clicks Open in the panel on a text file
- **THEN** the panel closes and the file opens in an editable window

### Requirement: The panel is at least as fast as Quick Look

For every benchmark file, Space with Peeker running SHALL show the panel no slower than Finder's Quick Look shows its own for the same file: faster, or within 10% (the benchmarks' "about the same"). Both SHALL be timed the same way by `bench/spacebench.swift`.

#### Scenario: A 12 MP photo

- **WHEN** spacebench presses Space on the 12 MP JPEG fixture, once with Quick Look and once with Peeker
- **THEN** Peeker's median is lower than Quick Look's, or at most 10% higher

### Requirement: The app asks for the permissions the panel needs

The panel needs Accessibility (to see the key system-wide) and Automation for Finder (to read the selection). Without Accessibility, the app SHALL ask once, then start watching the key as soon as it's granted, without a relaunch.

#### Scenario: Granting Accessibility later

- **WHEN** the user grants Accessibility after launching the app
- **THEN** Space in Finder starts working within a few seconds, without restarting Peeker

### Requirement: The app can open at login

Peeker > Open at Login SHALL register or unregister the app as a login item, because the panel only works while the app runs. A failure SHALL be reported in an alert.

#### Scenario: Turning on Open at Login

- **WHEN** the user chooses Open at Login
- **THEN** Peeker starts at the next login and the panel works without launching it by hand
