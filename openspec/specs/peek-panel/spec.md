# peek-panel Specification

## Purpose
Pressing Space on a file in Finder shows it in Peeker's floating Peek panel instead of Finder's Quick Look, quickly and without taking focus from Finder, for every file type an enabled plugin supports.

## Requirements

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

- **WHEN** an Editor window is open and the user opens the Peeker menu
- **THEN** it has Settings… but no Open at Login

### Requirement: The Peek panel views; Open in Peeker moves the file to the Editor

The Peek panel SHALL only view, never edit. Its button SHALL read Open in Peeker, so the panel can be told apart from Quick Look, and SHALL close the panel and open the file in the Editor, ready to edit.

#### Scenario: Editing from the Peek panel

- **WHEN** the user clicks Open in Peeker in the Peek panel on a PDF
- **THEN** the panel closes and the PDF opens in the Editor with its edit tools in the toolbar

### Requirement: A busy Finder doesn't hold up the Peek panel

Reading Finder's selection for the Peek panel key or an arrow key SHALL give up after half a second. When it gives up on the Peek panel key, the key SHALL go on to Finder, as for a file no plugin opens. When it gives up on an arrow key while the panel shows, the panel SHALL keep showing the file it shows.

#### Scenario: Space while Finder is busy

- **WHEN** Finder takes longer than half a second to answer and the user presses Space on a file
- **THEN** within about half a second the key goes to Finder and its Quick Look handles it

#### Scenario: An arrow while Finder is busy

- **WHEN** the Peek panel shows a file, Finder takes longer than half a second to answer, and the user presses the down arrow
- **THEN** the panel keeps showing the same file and Peeker stays responsive

### Requirement: The Peek panel opens at a remembered size

Once the user has moved or resized the Peek panel, it SHALL open with that size and position, also after Peeker quits and starts again. Until then it SHALL open at 55% of the screen's visible width and 75% of its height, at most 900 × 700 points, centered. The user SHALL NOT be able to make it smaller than 400 × 300 points. Every file SHALL open in the same frame.

#### Scenario: A first Space on a portrait display

- **WHEN** the user presses Space on a file for the first time on a 1440 × 2560 point display
- **THEN** the panel is 792 × 700 points, centered on the display

#### Scenario: After a resize and a relaunch

- **WHEN** the user drags the panel to the top left, makes it 600 × 500 points, quits Peeker, starts it and presses Space on another file
- **THEN** the panel opens 600 × 500 points at the top left

#### Scenario: Too small

- **WHEN** the user drags the panel's corner inward as far as it goes
- **THEN** the panel stops at 400 × 300 points

### Requirement: The Peek panel opens on the display with the pointer

The Peek panel SHALL open on the display that has the pointer. When its saved frame lies on that display, it SHALL open there as saved. Otherwise it SHALL keep its saved size centered on that display, or open at the default size centered there when the saved size doesn't fit that display.

#### Scenario: Working on the second display

- **WHEN** the panel was last left on the main display and the user presses Space in a Finder window on the second display, with the pointer there
- **THEN** the panel opens on the second display at its saved size, centered

#### Scenario: A display that's gone

- **WHEN** the panel was last left on a large external display that's no longer connected, and it's bigger than the laptop's screen
- **THEN** it opens on the laptop's screen at the default size, centered
