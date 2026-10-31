# Tasks

## 1. Plugins declare default extension lists

- [x] 1.1 Replace `fileTypes: [UTType]` with `defaultExtensions: [String]` in `Plugin` (PeekerKit), add the `noExtension` constant, and give each plugin its list from design decision 6; update the stub plugins in the tests; verify with a new test that every default list is lowercase with no dots or spaces, that no two lists share an entry, and that `scripts/build.sh test` builds
- [x] 1.2 Add a test that each non-dynamic default extension's `UTType(filenameExtension:)` conforms to a type in the app's `CFBundleDocumentTypes`, and adjust `project.yml` if one isn't covered; verify the test passes against the built app's Info.plist

## 2. Config reads extension lists

- [x] 2.1 In `Config`, drop `routes` and the `open` section (so `open` becomes an unknown key) and read `plugins.<id>.extensions`: array of strings, strip one leading dot, lowercase, skip and report empty entries and ones with a dot, slash or whitespace; verify with `ConfigTests` for a replaced list, an empty list, a missing key keeping defaults, each bad entry with its path, and `open` reported as unknown
- [x] 2.2 Build `Config.owners` (extension → plugin id) from every plugin's configured or default list, in catalog order; on a duplicate the default owner keeps it, otherwise the first plugin, and each loser gets a problem at `plugins.<id>.extensions` naming the winner; verify with `ConfigTests` for md added to Plain Text but left in Markdown, md moved from Markdown to Plain Text, and a new extension added to two plugins
- [x] 2.3 In `ConfigSchema`, remove `open` and add `plugins.<id>.extensions` (array of strings, default list in `default` and the description); verify with `ConfigSchemaTests` that each plugin's `extensions` default equals its list and `open` is gone
- [x] 2.4 Update `ConfigStoreTests` to watch a change to `plugins.text.extensions` instead of `open`; verify they pass

## 3. Routing by extension

- [x] 3.1 Reorder `PluginCatalog.builtIn` to Image, PDF, Markdown, Plain Text; replace `candidates(for:)`, `defaultPlugin(for:)` and `contentType(of:)` with `owner(for:)` (the enabled owner of the symlink-resolved file's extension, `noExtension` when empty) and `openWithChoices(for:)` (owner first, then every other enabled plugin in catalog order); verify with rewritten `RoutingTests`: `.md` → Markdown, `README.MD` → Markdown, `.zshrc` and `Makefile` → Plain Text, `.conf` → Plain Text, `.mp4` → none, a disabled owner → none and no other plugin takes it, a symlink uses its target's extension, and Open With lists every enabled plugin with the owner first
- [x] 3.2 Move the callers over: Space and window opens in `AppDelegate`, recovery reopening with the recorded plugin when it's enabled (else the owner), Open With in `DocumentWindowController`, and `BenchRunner`; verify that `scripts/build.sh test` passes with no warnings, and that recovery tests still reopen with the recorded plugin

## 4. Docs

- [x] 4.1 Rewrite the README's Config section and plugin descriptions for `plugins.<id>.extensions` (no `open`, Plain Text owns files with no extension, defaults listed in `schema.json`); verify `ReadmeConfigTests` parses the new example with no problems

## 5. Integration

- [ ] 5.1 Run `scripts/build.sh test`, `scripts/check-plugin-imports.sh` and `openspec validate --all`; then check by hand in the built app: Space on a `.md`, `.conf`, `.zshrc` and `.mp4` in Finder (the last goes to Finder's Quick Look), and Open With on a Markdown tab switching to Plain Text and Image
  - 2026-10-30, with `.claude/skills/run-peeker`: the routing check passed all 30 cases; in the real app, Open With (Markdown, Plain Text, Image) and the config clash in the menu bar passed. Space in Finder couldn't be checked because this build has no Accessibility permission (no event tap), so every Space went to Finder's Quick Look. Archived with this open; settings-window task 8.1 repeats the check.

## Workflow follow-up

- Archive `json-config` before archiving this change, since this change modifies requirements that json-config adds.
- Then archive this change with `/opsx:archive`.
