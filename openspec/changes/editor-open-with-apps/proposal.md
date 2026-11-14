# Proposal

## Why

The Peek panel's button can open a file in any app that reads it, but an Editor window can't: its File > Open With only switches between Peeker's own plugins. Opening the file in Xcode or Numbers means going back to Finder for it.

## What Changes

- File > Open With lists Peeker's plugins as today, then a separator, then the other apps macOS says open the file, each with its icon (the Mac's default app first, then A to Z, without Peeker), then Other…, a picker of any app. Choosing an app opens the file in it, in front; the Editor window stays open. Nothing changes a default: Other… has no Always checkbox, since Settings sets default apps.
- With unsaved edits, choosing an app asks first: Save (then open the saved file), Open Without Saving (the other app gets the file as it is on disk; the edits stay in Peeker), or Cancel.
- File > Open With is enabled whenever a file is open, since some app other than Peeker reads almost every file; a file only one plugin reads shows that plugin, checked, above the apps.
- The toolbar's Open With control is unchanged: it switches plugins and shows only when more than one plugin reads the file.
- The panel's list of apps and its Other… picker become shared code for both.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `plugin-host`: File menu additions (Open With lists other apps and Other…, and is no longer greyed out for a file one plugin reads).

## Impact

- Changed: `Sources/Host/Documents/DocumentWindowController.swift` (Open With moves to a new `DocumentWindowController+OpenWith.swift`, which keeps the file under its line ceiling), `Sources/Host/PeekPanel/OpenWith.swift` and `PeekPanel.swift` (the app list and picker move to shared code in `Sources/Host/App/AppChoices.swift`).
- Tests in `Tests/FileMenuTests.swift` and `Tests/PeekPanelTests.swift`; the screen flow's Open With steps in `scripts/screen/record-flows.sh`. A CHANGELOG line, and the backlog line goes.
- No work on the open path: the apps are listed only when the File menu opens.
