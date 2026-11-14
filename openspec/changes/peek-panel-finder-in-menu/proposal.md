# Proposal

## Why

The Peek panel only opens on the file selected in Finder, and links in it open elsewhere, so the file it shows is nearly always already in front of the user. Its folder button, which shows that file in Finder, takes title-bar room that long file names need. Show in Finder still helps from Finder's search results, Recents and tag views, which don't show the file's folder, so it stays in the button's menu and on its key.

## What Changes

- **BREAKING (UI):** the folder button beside Open in Peeker goes. Show in Finder stays at the end of the button's menu, which now shows its key (Cmd+R by default), and Cmd+R still works while the panel is up.
- The file name gets the room the button took.
- Editor windows keep their folder button and File > Show in Finder.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `peek-panel`: Show in Finder is only in the button's menu; only the main button shows a key caption, and the menu item shows Show in Finder's key.
- `routing-and-config`: turning `peekPanel.showInFinderKey` off leaves the menu item without a key, instead of the folder button.

## Impact

- Changed: `Sources/Host/PeekPanel/PeekPanel.swift` and `OpenWith.swift`; comments in `Config.swift` and `HotkeyMonitor.swift`.
- Tests in `Tests/PeekPanelTests.swift`; `scripts/screen/record-flows.sh` drops the folder button's step (Cmd+R's step covers the reveal) and measures the long name against Open in Peeker. The two CHANGELOG lines about the panel's keys and Show in Finder change, since no release had the button.
- The config keeps `peekPanel.showInFinderKey`, so existing configs stay valid.
