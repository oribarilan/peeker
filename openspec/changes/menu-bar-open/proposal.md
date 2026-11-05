# Proposal

## Why

With no window open, the menu bar icon is Peeker's only menu, and it has no Open… (design review finding M8): opening a file in Peeker without Finder means first opening Settings to get the app's menus. Opening a file is the most common thing to do there.

## What Changes

- The menu bar icon's menu starts with Open…, the same command as File > Open….
- While the Open panel shows, Peeker has its Dock icon and menus, so the panel comes up in front and takes the keyboard. Afterwards the usual rule applies: they go away after Cancel and stay with the window of the file opened.
- Hiding the menu bar icon, the other half of M8, stays a separate decision.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `app-presence`: the menu bar menu gains Open…, and the Open panel counts as a window for the Dock icon.

## Impact

- `Sources/Host/App/MenuBarItem.swift`, `AppDelegate.showOpenPanel(_:)`; `Tests/SettingsLogicTests.swift` (MenuBarMenu); `scripts/screen/record-flows.sh`; CHANGELOG. Minor version bump.
