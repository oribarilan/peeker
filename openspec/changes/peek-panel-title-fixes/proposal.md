# Proposal

## Why

Two things in the Peek panel's title bar look broken. A long file name runs under the folder button and Open in Peeker, so both the name and the buttons are hard to read. And the button's Open With menu lists apps without their icons, though the spec says it shows them and the code sets them.

## What Changes

- The file name in the panel's title bar stops before the folder button and is cut in the middle when it doesn't fit, as Finder cuts names, so its start and its extension stay visible. The window's title stays the full name for VoiceOver and the Window menu.
- Each app in the button's Open With menu shows its icon, as the spec already says. macOS 27 hides menu item images unless an item asks to show its image; File > Open Recent sets file icons the same way, so its items ask too.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `peek-panel`: a requirement for the title bar's file name; the Open With menu's requirement gets a scenario for the icons.

## Impact

- Changed: `Sources/Host/PeekPanel/PeekPanel.swift` and `OpenWith.swift`, `Sources/Host/App/RecentFiles.swift`, and a small shared helper for menu item images.
- Tests in `Tests/PeekPanelTests.swift`; a step in `scripts/screen/record-flows.sh` for a long name. A CHANGELOG line, and the two backlog lines go.
- No work on the open path beyond laying out one label when the file changes.
