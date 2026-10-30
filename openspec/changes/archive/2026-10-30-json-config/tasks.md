# Tasks

## 1. Plugins declare their commands

- [x] 1.1 Add `static var commands: [CommandSpec]` to `Plugin` in PeekerKit, give each plugin its full list (image: zoom-in, zoom-out, zoom-fit; PDF: zoom-in, zoom-out, highlight; text: zoom-in, zoom-out, toggle-wrap; Markdown: none), and make documents reuse those specs; verify with a test that every document's commands appear in its plugin's static list, and that `scripts/build.sh test` passes

## 2. JSON config with problems

- [x] 2.1 Move `JSONValue` out of `RecoveryStore.swift` into its own file; verify `RecoveryStoreTests` still pass
- [x] 2.2 Rewrite `Config` to parse `config.json` (or `$PEEKER_CONFIG`) into the same settings plus `[ConfigProblem]` with key paths: `quickLook.key`, `plugins.<id>.enabled`, `plugins.<id>.commands.<command>.shortcut`, `open.<ext>`, `open.noExtension`, `$schema` ignored; unknown keys, wrong kinds, unparseable shortcuts, unknown command names and routes to plugins that can't open the type become problems; invalid JSON is one problem and no settings; verify with rewritten `ConfigTests` covering defaults, each section, each problem with its path, and the old dotfile not being read
- [x] 2.3 Generate `schema.json` from the catalog's plugin ids and static commands plus the fixed sections, with descriptions, and write it next to the config at launch only when its bytes differ; verify with `ConfigSchemaTests` (plugin ids and command names listed, `additionalProperties: false`, no rewrite when unchanged, `config.json` never touched)

## 3. Applying the config live

- [x] 3.1 Add `ConfigStore`: holds the current config and problems, watches the config path with `FileWatcher`, keeps the previous config on invalid JSON, and calls `onChange`; verify with `ConfigStoreTests` on a temp file (a save applies, an atomic replace applies, a symlinked config applies and stays a symlink, broken JSON keeps the old settings and reports one problem)
- [x] 3.2 Wire `ConfigStore` into `AppDelegate`: catalog reload, hotkey restart when the key changed, and `apply(config:)` on every open document so shortcuts update in place; remove Reload Config and its menu item; verify with a test that a document's command shortcuts change after `apply(config:)`, and by hand that a saved shortcut works in an open window
- [x] 3.3 Write the benchmark's no-hotkey config as JSON in `bench/ppbench.py`; verify a bench run of one file in panel and window mode still records results

## 4. Settings window

- [x] 4.1 Add the Settings window (SwiftUI in an `NSWindowController`) with the Config file pane: the path, Open in Editor, and the problems list or "No problems", updating on every config change; open it from the app menu with Cmd+, and bring it forward when already open; verify by hand with a typo that appears and clears on save
- [x] 4.2 Make Open in Editor create `{"$schema": "schema.json"}` (and its folder) only when no config exists, then open it with the default JSON app; verify with a test that it creates the file when missing and leaves an existing one byte for byte

## 5. Menu bar icon and Dock presence

- [x] 5.1 Add the menu bar icon (`NSStatusItem`, template `eye` symbol) with Settings…, Open at Login with its checkmark, and Quit; add a red dot and a "Config has N problems" item while there are problems; verify by hand that the dot appears and clears with a bad and a fixed config
- [x] 5.2 Set `LSUIElement` and switch the activation policy: regular (and activate) while any document window or Settings is open, accessory otherwise, never for the quick-look panel; verify with a test of the policy function and by hand: launch with no files (menu bar only), open and close a PDF (Dock icon comes and goes), press Space in Finder (no Dock icon)

## 6. Docs and integration

- [x] 6.1 Rewrite the README's Config section for `config.json` (example, keys, schema, live apply, Settings and the menu bar icon) and update `openspec/config.yaml`'s roadmap; verify the README example parses with no problems in a test
- [x] 6.2 Run `scripts/build.sh test`, `openspec validate --all --strict` and `scripts/check-plugin-imports.sh`; verify all pass with no new warnings

## Workflow follow-up

- Run the A/B benchmark against the previous commit when benchmarking comes off the back burner; window opens now include the activation policy switch.
- Archive the change with `/opsx:archive` after review.
