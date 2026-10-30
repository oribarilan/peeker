# Design

## Context

See proposal.md for why. Today `Config` (in `Sources/Host/App/Config.swift`) parses `key = value` lines into `disabled`, `routes`, `keys` and `quickLookKey`, logs bad lines, and records `unknownKeys`. `AppDelegate` loads it once at launch and again on Reload Config, then hands it to `PluginCatalog.reload(config:)` and restarts the hotkey when the key changed. Each `DocumentViewController` and `DocumentWindowController` keeps the `Config` it was created with, which is why a reload only reaches documents opened afterwards. `FileWatcher` already follows a path through atomic replaces and a file that disappears and comes back. Plugins list their commands only on an open document (`PluginDocument.commands`). The app is a regular Dock app with no status item.

Constraints: no new dependencies, Swift 6 with main-actor default isolation, the open path's speed (the benchmark gate), and the decisions in proposal.md.

## Goals / Non-Goals

**Goals:**
- One place owns the current config, its problems and the file watching, and everything else reacts to it.
- Problems carry a key path and a message, readable by the Settings pane and the menu bar icon alike.
- The schema comes from the same knowledge the parser checks against, so the two can't drift.

**Non-Goals:**
- Writing settings back from the UI (next change, the full settings window).
- Plugin-declared settings keys.
- Migrating the old dotfile.

## Decisions

### 1. A `ConfigStore` owns the config

`ConfigStore` (main actor, `Sources/Host/App/`) holds the current `Config`, the current `[ConfigProblem]` and a `FileWatcher` on the config path, and calls `onChange` after each read. `AppDelegate` creates it at launch and is its only subscriber; it fans the change out to the catalog, the hotkey, open document windows, the Settings window and the status item. A read that finds invalid JSON keeps the previous `Config` and replaces only the problems.

*Over keeping `Config` in AppDelegate:* three things now read problems (status item, Settings pane, tests), and watching plus re-reading is a job of its own.

### 2. Parsing walks a JSON value with paths

The file decodes into `JSONValue` (moved out of `RecoveryStore.swift` into its own file, now its second user), and a small walker visits the known sections, carrying the key path for problem messages. Unknown keys and wrong-kind values become `ConfigProblem(path:message:)`; the walker never throws past "not valid JSON". Extensions in `open` are lowercased; `noExtension` maps to the empty extension the catalog already uses.

*Over `Codable` structs with `decodeIfPresent`:* they either fail the whole file on one bad value or silently drop unknown keys, and they can't say where a problem is.

### 3. Plugins declare their commands statically

`Plugin` gains `static var commands: [CommandSpec]`, the full list a plugin can offer. Documents keep returning the commands they offer now, a subset (the PDF plugin drops Highlight when view-only), and reuse the static specs instead of repeating them. The config checks `plugins.<id>.commands.<command>` against it, and the schema lists the names, so a typo in a command name is a problem and editors autocomplete the real ones.

*Over accepting any command name:* a misspelled command would silently do nothing, which is exactly what this change sets out to end.

### 4. Schema generated from the same tables

`ConfigSchema` builds the JSON Schema (draft 2020-12) from the catalog's plugin ids and their static commands, plus the fixed `quickLook` and `open` sections, with a description on each key. At launch it serializes with sorted keys and pretty printing, compares the bytes with `schema.json` next to the config path the app reads, and writes through `FileReplacement` only when they differ. `additionalProperties: false` in the schema matches the parser's unknown-key problems.

The schema goes next to the path the app reads (`~/.config/peeker/` by default). When that path is a symlink, a relative `"$schema"` resolves for editors that open the link, which is how the app's own Open in Editor opens it.

### 5. Applying a config live

`PluginCatalog.reload(config:)` already swaps routing and enabled plugins. Documents get `apply(config:)`, which recomputes the shortcut table and fires `onCommandsChanged`, so their window rebuilds the toolbar and the Commands menu. The hotkey restarts only when the key changed, as today. Open documents of a newly disabled plugin are left as they are. Reload Config and its menu item go away.

### 6. Settings window in SwiftUI

The Settings window is an `NSWindowController` hosting SwiftUI (`NSHostingController`), with the Config file pane as a grouped `Form`: path, Open in Editor, and the problems list (or "No problems"). It observes `ConfigStore`. The next change builds a Tinycast-style sidebar of panes on the same base, which SwiftUI's `NavigationSplitView` and `Form` cover well; Settings isn't on the open path, so SwiftUI's cost doesn't touch the benchmarks.

Open in Editor creates the file with `{"$schema": "schema.json"}` only when none exists (creating `~/.config/peeker/` if needed), then opens it with the default app for JSON through `NSWorkspace`.

### 7. Menu bar icon

An `NSStatusItem` with a template SF Symbol (`eye`, adjustable later). The red dot is a small non-template layer on the status button, so the symbol still follows the menu bar's appearance. The menu: "Config has N problems" (only when there are any, opening the Config file pane), Settings…, Open at Login with its checkmark, a separator, Quit Peeker.

### 8. Dock icon only while windows are open

`LSUIElement` is set in Info.plist, so Peeker launches as a menu bar utility with no Dock flash. `AppDelegate.updatePresence()` runs whenever a document window or the Settings window opens or closes: with any open it sets `.regular` and activates the app (switching from accessory doesn't always bring up the menu bar until the app reactivates), otherwise `.accessory`. The quick-look panel never counts. The policy decision itself is a small pure function, `presence(documentWindows:settingsOpen:)`, so tests cover it without AppKit state.

### 9. Benchmarks and tests

`bench/ppbench.py` writes its no-hotkey config as JSON. A base build from before this change reads the same file as a dotfile and only logs a bad line, which is harmless because bench mode never starts the hotkey anyway.

Tests: `ConfigTests` rewritten for JSON (defaults, each section, problem paths, invalid JSON keeps the old config), `ConfigSchemaTests` (schema lists plugin ids and command names, rewrites only on change), `ConfigStoreTests` against a temp file (live apply, atomic replace, symlink untouched), presence policy, and a document test that a config change updates its shortcuts.

## Risks / Trade-offs

- [Switching activation policy can leave the menu bar stale or steal focus] → Activate after switching to `.regular`, never switch while the quick-look panel is up, and check by hand with Space, open and close.
- [Activation policy work lands on the window-open path, which the benchmark gates] → Switch only when the count goes from zero to one or back; measure window opens with the A/B gate.
- [`LSUIElement` hides the menus at launch when opening files from Finder] → `updatePresence()` runs when the first window opens, before it's shown.
- [A config edited mid-save could be read half-written] → `FileWatcher` coalesces events for 200 ms, and invalid JSON keeps the previous config, so the worst case is one transient problem that clears on the next event.
- [Plugins must list commands twice: statically and on documents] → Documents reuse the static specs; a test checks every document command is in its plugin's static list.

## Migration Plan

Lands in one step on `main`. Users (the maintainer) rewrite their dotfile into `config.json` by hand, following the mapping in the routing-and-config delta. Rollback is reverting the commit; the old dotfile is never touched, so it still works with the previous build.

## Open Questions

- The menu bar symbol: `eye` until the maintainer picks another. Changing it touches one line.
