# Proposal

## Why

Routing today ranks plugins by macOS file types: Markdown beats Plain Text on `.md` because it names the exact type, and config routes override that ranking under rules about typed and untyped files. That's hard to explain and hard to show in the coming Settings window, where it would need conflict handling. A fixed list of extensions per plugin, editable in the config, says plainly which plugin opens what.

## What Changes

- Each plugin declares a default list of the extensions it opens. A file goes to the enabled plugin whose list has its extension, compared without case. No macOS type matching, no ranking, no fallback.
- Plain Text's list includes files with no extension, which covers dotfiles such as `.zshrc` and names like `Makefile`.
- `plugins.<id>.extensions` in `config.json` replaces that plugin's default list with the full list given. A missing key means the default list.
- An extension belongs to one plugin. If the config puts one extension in two lists, that's a problem: the extension stays with the plugin whose default list has it, or else the first plugin in sidebar order.
- **BREAKING**: the `open` section (extension → plugin routes) is removed. There's no migration; it's reported as an unknown key like any other.
- A plugin that's turned off opens nothing, and no other plugin takes its extensions. Space on such a file goes to Finder's Quick Look.
- Open With in a window lists every enabled plugin, the file's owner first, so `.md` can still be read in Plain Text for one tab. A plugin that can't read the file shows its usual error.
- Coverage changes slightly: Image opens the formats on its list instead of everything macOS calls an image, and Plain Text opens the text and source formats on its list instead of everything typed as plain text.
- The schema and README describe the new key. Editing the lists in the Settings window comes with the next change, settings-window.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `routing-and-config`: the JSON config loses `open` and gains `plugins.<id>.extensions`; type ranking, routes and untyped-file rules give way to one owner per extension; disabling and Open With change to match; the alternate-handler declaration follows the default lists.
- `plugin-host`: a plugin declares the extensions it opens by default instead of file types.
- `text`: Plain Text opens the files on its list, including files with no extension, instead of everything typed as text plus routed files.
- `image`: Image opens the formats on its list instead of all of `public.image`.

## Impact

- `Sources/PeekerKit/Plugin.swift`: `fileTypes: [UTType]` becomes a default extension list.
- `Plugins/*/…Plugin.swift`: each plugin's default list.
- `Sources/Host/Plugins/PluginCatalog.swift`: routing by extension; `candidates(for:)` and `defaultPlugin(for:)` change meaning; `contentType(of:)` goes.
- `Sources/Host/App/Config.swift`, `ConfigSchema.swift`: `open` and `routes` go; `plugins.<id>.extensions` and its problems arrive.
- `Sources/Host/Documents/DocumentWindowController.swift` (Open With), `AppDelegate.swift`, `BenchRunner.swift`: callers of the catalog.
- `project.yml`: `CFBundleDocumentTypes` covers the default lists.
- Tests: `RoutingTests`, `ConfigTests`, `ConfigStoreTests`, `ConfigSchemaTests`, `ReadmeConfigTests` and the stub plugins in `ModuleDocumentTests`.
- README Config section and plugin descriptions.
- Depends on `json-config`: its delta for `routing-and-config` must be archived first, since this change modifies requirements that change adds.
