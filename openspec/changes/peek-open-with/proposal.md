# Proposal

## Why

The Peek panel can only send a file to Peeker's Editor. Finder's Quick Look offers every app that opens the file, so someone who peeks at a `.swift` file and wants it in Xcode has to close the panel, go back to Finder and use Open With there. The panel should offer the same choice and remember a preferred app per type.

## What Changes

- The panel's Open in Peeker button becomes a split button. Its main part opens the file with the panel's default app for that extension, named on the button ("Open in Xcode"); with no default, or when that app is gone, it stays Open in Peeker.
- Its arrow shows a menu of the installed apps that open the file, with icons, the macOS default first and the rest A to Z. Picking one opens the file there once and closes the panel.
- When another app is the panel's default for the type, the menu also lists Peeker and "Always Open in Peeker", which drops that default.
- Other… at the bottom shows an app picker in /Applications as a sheet on the panel, with an "Always open .ext files with this app" checkbox (unticked; hidden for files with no extension). Cancel leaves the panel showing.
- A new config key, `peekPanel.openWith`, maps extensions to app bundle IDs. It's checked like every other key, documented in `schema.json`, and kept when Settings rewrites the config. It only changes the panel; Finder's double-click and the macOS default app are untouched.
- The Editor's File > Open With is unchanged (out of scope; a backlog line).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `peek-panel`: the panel's button opens with the panel's default app for the type, offers other apps and Other…, and can set or drop a per-extension default; the config gains `peekPanel.openWith`.

## Impact

- `Sources/Host/PeekPanel/`: the split button, its menu, the app picker sheet, and opening in another app.
- `Sources/Host/App/Config.swift`, `ConfigRendering.swift`, `ConfigSchema.swift`: the new key, its checks, rendering and schema.
- `Sources/Host/App/AppDelegate.swift`: passes the config to the panel and saves defaults through `ConfigStore`.
- Tests in `Tests/PeekPanelTests.swift` and `Tests/ConfigTests.swift`; a step in a screen flow; a CHANGELOG line.
- No new dependency. Opening a file is unchanged; the app list is built only when the menu opens.
