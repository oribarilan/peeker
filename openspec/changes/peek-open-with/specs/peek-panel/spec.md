## MODIFIED Requirements

### Requirement: The Peek panel views; Open in Peeker moves the file to the Editor

The Peek panel SHALL only view, never edit. Its button SHALL read Open in Peeker unless the config gives the file's extension another app (see "The panel can open a type in another app by default"), so the panel can be told apart from Quick Look. Open in Peeker SHALL close the panel and open the file in the Editor, in front of Finder, ready to edit.

#### Scenario: Editing from the Peek panel

- **WHEN** the user clicks Open in Peeker in the Peek panel on a PDF
- **THEN** the panel closes and the PDF opens in the Editor with its edit tools in the toolbar

## ADDED Requirements

### Requirement: The Peek panel offers the other apps that open the file

The panel's button SHALL have an arrow showing a menu of the installed apps macOS says open the file, with icons: the Mac's default app for the file first, then the rest A to Z, leaving out Peeker and the app the button opens, and ending with Other…. Picking an app SHALL close the panel and open the file in that app, in front, without changing any default. The list SHALL be worked out only when the menu opens.

#### Scenario: Opening a Swift file in Xcode once

- **WHEN** the Peek panel shows `main.swift`, Xcode and TextEdit are installed, and the user picks Xcode from the button's menu
- **THEN** the panel closes, `main.swift` opens in Xcode in front of Finder, and the next `.swift` file still shows Open in Peeker

#### Scenario: The list

- **WHEN** the Peek panel shows a PNG and the user opens the button's menu
- **THEN** it lists the Mac's default app for PNGs first, then the other apps that open PNGs A to Z, without Peeker, then Other…

### Requirement: Other… opens the file with any app

Other… SHALL show a picker of apps in `/Applications` as a sheet on the panel, with an "Always open .ext files with this app" checkbox naming the file's extension, unticked, and absent for a file with no extension. Picking an app SHALL close the panel and open the file in it, and with the box ticked SHALL make it the panel's default for the extension. Cancel SHALL leave the panel showing the file, with Finder in front so the arrow keys keep browsing.

#### Scenario: Choosing a default

- **WHEN** the Peek panel shows `notes.txt`, the user chooses Other…, ticks "Always open .txt files with this app" and picks BBEdit
- **THEN** `notes.txt` opens in BBEdit, the config gains `"peekPanel": {"openWith": {"txt": "com.barebones.bbedit"}}`, and the next `.txt` file's button reads Open in BBEdit

#### Scenario: Cancel

- **WHEN** the user chooses Other… and then Cancel
- **THEN** the panel still shows the file and the down arrow in Finder moves to the next file

#### Scenario: A file without an extension

- **WHEN** the Peek panel shows `Makefile` and the user chooses Other…
- **THEN** the picker has no Always checkbox

### Requirement: The panel can open a type in another app by default

The config's `peekPanel.openWith` SHALL map extensions (lowercase, no dot) to app bundle IDs. For a file with such an extension, when that app is installed, the button SHALL read "Open in <app name>" and SHALL close the panel and open the file in that app. When the app isn't installed, the button SHALL read Open in Peeker and act as it, and the entry SHALL stay in the config. The setting SHALL change only the Peek panel, never the Mac's default app or Finder's double-click.

#### Scenario: The app was removed

- **WHEN** `peekPanel.openWith` gives `swift` to an app that is no longer installed and the Peek panel shows a `.swift` file
- **THEN** the button reads Open in Peeker and opens the Editor, and the config still lists `swift`

#### Scenario: A wrong entry

- **WHEN** the config holds `"peekPanel": {"openWith": {".SWIFT": "com.apple.dt.Xcode", "md": 3}}`
- **THEN** `swift` opens with Xcode from the panel, and Settings lists a problem at `peekPanel.openWith.md` saying it should be an app's bundle ID in quotes

#### Scenario: Settings keeps it

- **WHEN** `peekPanel.openWith` gives `swift` to Xcode and the user changes the Peek panel key in Settings
- **THEN** the rewritten config still gives `swift` to Xcode

### Requirement: Always Open in Peeker drops a default

While another app is the panel's default for the file's extension, the button's menu SHALL also list Peeker, which opens the file in the Editor once, and Always Open in Peeker, which opens it in the Editor and removes the extension from `peekPanel.openWith`. The panel SHALL write a default it sets or drops as Settings writes the config; when the config file can't be used, it SHALL say so in an alert and still open the file, leaving the config unchanged.

#### Scenario: Going back to Peeker

- **WHEN** `peekPanel.openWith` gives `txt` to BBEdit, the Peek panel shows `notes.txt` and the user picks Always Open in Peeker from the button's menu
- **THEN** `notes.txt` opens in the Editor, `txt` is gone from `peekPanel.openWith`, and the next `.txt` file's button reads Open in Peeker
