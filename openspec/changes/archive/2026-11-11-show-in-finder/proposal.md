# Proposal

## Why

Nothing in Peeker shows where an open file lives. Finding it in Finder means Cmd-clicking the window title and picking a folder, then finding the file in it; from the Peek panel, opened with a modifier key from another app, there's no way at all.

## What Changes

- File > Show in Finder, after Open With, opens a Finder window with the tab's file selected. No default key, as it's an uncommon action; users can set one in System Settings > Keyboard.
- The Editor toolbar gets a Show in Finder button (a folder) in the host's group on the left, after Back, Forward and Open With, before the plugin tools. It's always there, so the tools keep their place.
- The Peek panel gets a small folder button left of Open in Peeker in its title bar, and Show in Finder at the end of that button's menu. Both close the panel and select the file in Finder.
- A tab's right-click menu doesn't get it: macOS offers no supported way to add items there. A backlog line keeps the idea.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `plugin-host`: File > Show in Finder and the toolbar button.
- `peek-panel`: the folder button and the menu item.

## Impact

- Changed: `Sources/Host/App/MainMenu.swift`, `Sources/Host/Documents/DocumentWindowController.swift` and `+Navigation.swift`, `Sources/Host/PeekPanel/PeekPanel.swift` and `OpenWith.swift`.
- Tests in `Tests/FileMenuTests.swift`, `Tests/ToolbarLayoutTests.swift`, `Tests/NavigationControlsTests.swift`, `Tests/PeekPanelTests.swift`. A CHANGELOG line and a backlog line.
- No new dependency and no work on the open path: the button calls `NSWorkspace.activateFileViewerSelecting` only when pressed.
