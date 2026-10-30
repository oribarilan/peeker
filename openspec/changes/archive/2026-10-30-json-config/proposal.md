# Proposal: JSON config, first Settings window, menu bar presence

## Why

The config is a `key = value` dotfile that only applies after Reload Config, and its mistakes only reach the system log, so a typo silently does nothing. A JSON file with a generated schema gets autocomplete in any editor, applies the moment it's saved, and can report its problems where the user will see them. Peeker also needs a home while no file is open: Space in Finder only works while it runs, yet today it keeps a Dock icon and full menus for nothing.

## What Changes

- **BREAKING**: settings move to `~/.config/peeker/config.json` (or `$PEEKER_CONFIG`). The old `~/.config/peeker/config` dotfile is no longer read and is left alone.
- The JSON has sections: `quickLook.key`, `plugins.<id>.enabled`, `plugins.<id>.commands.<command>.shortcut`, `open.<extension>` and `open.noExtension`. Missing keys keep their defaults. Only these host-owned keys exist; plugins can't declare their own keys yet.
- The app writes `schema.json` next to the config at launch whenever its content changed, and a config can point to it with `"$schema": "schema.json"` for editor autocomplete.
- Saving the file applies it at once, everywhere, including open windows, and also when an editor saves by renaming. A symlinked config stays a symlink. **BREAKING**: Peeker > Reload Config goes away.
- Invalid JSON applies nothing; an unknown key is skipped; a bad value keeps the setting as it was. Each problem is listed.
- A first Settings window with one pane, Config file: where the file is, Open in Editor (creating a starter file when there is none), and the current problems. The next change grows this into the full settings window.
- A menu bar icon, always present while Peeker runs, with Settings…, Open at Login and Quit, and a red dot while the config has problems.
- Peeker shows a Dock icon, the app menus and a place in Cmd+Tab only while a document window is open; otherwise it lives in the menu bar alone.

## Capabilities

### New Capabilities

- `settings`: the Settings window and its panes; in this change, the Config file pane with the config's location and problems.
- `app-presence`: how Peeker shows itself: the menu bar icon and its menu, the problems dot, and the Dock icon and menus that appear only while documents are open.

### Modified Capabilities

- `routing-and-config`: the config becomes a JSON file with a schema, applied live, with problems reported instead of only logged; Reload Config is removed; the keys for turning plugins off, routing and shortcuts change shape.
- `quick-look-panel`: the Space key setting moves to `quickLook.key` and changes live; Open at Login is also in the menu bar icon's menu.

## Impact

- Code: `Sources/Host/App/Config.swift` (new parser and problems), `AppDelegate.swift` (watching the config, applying it live, activation policy), `MainMenu.swift` (Reload Config removed), a new status item and Settings window under `Sources/Host/App/` or a new `Sources/Host/Settings/`, `DocumentViewController` and `DocumentWindowController` (shortcuts updated live), `PluginCatalog` (config changes).
- Reuse: `FileWatcher` for the config file, `FileReplacement` for writing the starter file and `schema.json`.
- Benchmarks: `bench/ppbench.py` writes its "no hotkey" config as JSON.
- Docs: README Config section, `openspec/config.yaml` roadmap.
- No new dependencies: JSON and the schema use Foundation only.
