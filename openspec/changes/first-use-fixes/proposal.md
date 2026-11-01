# Proposal

## Why

The maintainer started using Peeker day to day on 2026-11-01 and hit three gaps at once. Highlight only works on text selected beforehand, while people expect a highlighter they turn on and drag over text, as in Preview. A command's shortcut can be changed but never removed. And opening Peeker from Launchpad, Spotlight or Finder shows nothing but a menu bar icon, so it looks as if it didn't start. Decided on 2026-11-01.

## What Changes

- **Highlight becomes a highlighter for one drag.** Clicking Highlight (or its shortcut) arms it; the next drag over text highlights that text and disarms it. Escape, another tool or leaving Edit mode also disarm it. Text already selected is highlighted at once, and the highlighter stays armed for one more drag. The command's name becomes "Highlight"; its config id stays `highlight`.
- **A shortcut can be cleared.** Each shortcut recorder in Settings gets a clear button that leaves the command without a shortcut; Reset brings the default back. The config says so with `"shortcut": "off"`, and the menu item shows no shortcut.
- **Opening Peeker by hand shows Settings.** A launch with no file to open (from Launchpad, Spotlight or Finder) and reopening Peeker while it runs bring up the Settings window. A launch at login stays quiet.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `pdf`: Highlight works as a one-drag highlighter instead of acting only on a selection made first.
- `routing-and-config`: a command's shortcut can be set to `off`.
- `settings`: each shortcut can be cleared from Settings; launching or reopening Peeker by hand opens Settings.

## Impact

- `Plugins/pdf`: `EditController` (the armed highlighter), `PDFPluginDocument` (the highlight command), `PDFPlugin` (the command's title).
- `Sources/Host/App`: `Config` reading, rendering and schema for `off`, `MainMenu` and the window's command lookup for a command without a shortcut, and `AppDelegate` (launch and reopen).
- `Sources/Host/Settings`: the clear button beside each recorder.
- `scripts/screen/record-flows.sh`: clearing a shortcut, and the Settings window a launch with no file now shows.
- The `settings` delta adds to the plugin pane requirement from `settings-window`, which should be archived first.
