# Proposal

## Why

Peeker's tools are hard to learn by looking: the toolbar shows icons only, a tooltip gives just the name, and the keys are visible only in the menus. The PDF tools also sit on two-modifier keys (⌃⌘T, ⌃⌘H) where a single letter would do, as in Shottr and in Peeker's own Crop (C). And the tools that wait for a next step (select, click or drag) don't say what that step is.

## What Changes

- **New default keys for PDF tools:** Text Box T, Sign S, Highlight H. Rotate Left and Rotate Right lose ⌘L and ⌘R and, like Delete Page, have no default key. A key set in the config still wins.
- **Key captions in the toolbar:** each toolbar button with a shortcut shows its key beside the icon ("icon | key"), each tool on a capsule of its own. `showShortcuts` (true by default) in the config and "Show shortcuts in the toolbar" in Settings > Appearance turn the captions off; the key then shows only in tooltips and Settings.
- **Tooltips:** every toolbar button, and every button that shows only an icon, has a tooltip with its name and key, such as "Highlight (H)". A greyed-out tool keeps showing why it's off.
- **First-use tips:** the first time Highlight, Text Box, Sign or Crop runs, a bubble from its toolbar button says what to do next. It closes on the next click and doesn't come back; "Show Tips Again" in Settings > General brings them all back.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `plugin-host`: toolbar buttons with key captions and tooltips, and first-use tips for tools that declare one.
- `pdf`: the PDF tools' default keys.
- `routing-and-config`: the config file gains `showShortcuts`.
- `settings`: Appearance gets the captions checkbox; General gets Show Tips Again.

## Impact

- `Sources/PeekerKit/Plugin.swift`: `ToolSpec` gains an optional `tip`.
- `Sources/Host/Documents/DocumentWindowController.swift` and a small helper that draws a tool's icon and key as one image for its toolbar item; the active tool's capsule filled with the accent; tooltips on the navigation items (Sidebar, Back, Forward) too.
- A small tips store in the host (seen tips in the app's preferences) and the popover.
- `Config.swift`, `ConfigRendering.swift`, `ConfigSchema.swift`; `AppearancePane.swift`, `GeneralPane.swift`, `SettingsWindowController.swift`; Settings' icon-only buttons get `.help`.
- `Plugins/pdf/PDFPlugin.swift` (keys, tips), `Plugins/image/ImagePlugin.swift` (Crop's tip).
- Tests across toolbar, menu, config, schema and Settings; screen flows that press tools by name or use ⌃⌘H (`record-flows.sh`, `pdf-edit-flow.sh`, `pdf-pages-flow.sh`).
- CHANGELOG; minor version bump.
