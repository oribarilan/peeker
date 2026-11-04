# Proposal

## Why

Open With lists every enabled plugin for every file, so a Markdown tab offers Image and PDF, and a photo offers Plain Text and Markdown. Picking one of those only shows an error in the tab. The picker should offer only what can show the file, and stay out of the way when nothing else can.

## What Changes

- Each plugin names the file types it reads: Plain Text reads any text, Markdown reads Markdown files, Image reads the types the system image decoder opens (not SVG or PDF), PDF reads PDF.
- Open With (the toolbar control and File > Open With) lists the file's owner first, then the other enabled plugins that read the file's type. The plugin the tab shows now is always listed, so the menu's check mark always has an item.
- The file's type comes from macOS, which also types files with no extension by their contents: an extensionless README counts as plain text.
- When only one plugin is listed, the toolbar control is hidden and File > Open With stays in the menu, greyed out.
- No new config setting: the types are fixed in each plugin. Extension lists still decide the owner, and the owner is always listed.
- The "pick Image on a Markdown tab" behavior goes away: Image is no longer offered there.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `routing-and-config`: "Open With switches the plugin for one tab" lists only plugins that read the file and hides when there's one; the "Disabling Markdown" scenario says which plugins Open With offers then.
- `plugin-host`: "File menu additions" greys out File > Open With when the toolbar control is hidden.

## Impact

- `Sources/PeekerKit/Plugin.swift`: the plugin contract gains the types a plugin reads.
- `Plugins/*/…Plugin.swift`: each built-in plugin declares its types.
- `Sources/Host/Plugins/PluginCatalog.swift`: `openWithChoices` filters by type and always keeps the current plugin.
- `Sources/Host/Documents/DocumentWindowController.swift`: the toolbar leaves out Open With when there's one choice; File > Open With greys out.
- Tests: `RoutingTests`, `FileMenuTests`, `ToolbarLayoutTests`, `NavigationControlsTests`, `LinkNavigationTests`.
- Screen flow `scripts/screen/record-flows.sh`: the step that picks Image on a Markdown tab changes.
- `CHANGELOG.md`, `MARKETING_VERSION` (0.8.0-dev), `openspec/backlog.md`.
