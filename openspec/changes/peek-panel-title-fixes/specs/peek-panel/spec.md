# Spec Delta

## ADDED Requirements

### Requirement: The Peek panel's title fits beside its buttons

The panel's title bar SHALL show the file's name ending before the title bar's buttons, never under them. A name too long to fit SHALL be cut in the middle with an ellipsis, so its start and its extension stay visible. The window's title SHALL stay the full name, for VoiceOver and the Window menu.

#### Scenario: A long name

- **WHEN** the Peek panel shows `Quarterly report for the board meeting, final draft with comments.pdf` at its first size
- **THEN** the name ends before the buttons, reads with an ellipsis in the middle and ends in `.pdf`

#### Scenario: A short name

- **WHEN** the Peek panel shows `notes.md`
- **THEN** the title bar shows `notes.md` whole

## MODIFIED Requirements

### Requirement: The Peek panel offers the other apps that open the file

The panel's button SHALL have an arrow showing a menu of the installed apps macOS says open the file, with icons: the Mac's default app for the file first, then the rest A to Z, leaving out Peeker and the app the button opens, and ending with Other…. Picking an app SHALL close the panel and open the file in that app, in front, without changing any default. The list SHALL be worked out only when the menu opens.

#### Scenario: Opening a Swift file in Xcode once

- **WHEN** the Peek panel shows `main.swift`, Xcode and TextEdit are installed, and the user picks Xcode from the button's menu
- **THEN** the panel closes, `main.swift` opens in Xcode in front of Finder, and the next `.swift` file still shows Open in Peeker

#### Scenario: The list

- **WHEN** the Peek panel shows a PNG and the user opens the button's menu
- **THEN** it lists the Mac's default app for PNGs first, then the other apps that open PNGs A to Z, without Peeker, then Other…

#### Scenario: Each app shows its icon

- **WHEN** the user opens the button's menu
- **THEN** every app in it shows its icon beside its name, on macOS 27 as on macOS 26
