# Tasks

## 1. Module and routing

- [x] 1.1 `PeekerData` target in `project.yml` (app, both test bundles, PeekerSyntax dependency); `scripts/check-plugin-imports.sh` lets `data` import PeekerSyntax; `DataPlugin` (id "data", name "Data", symbol `curlybraces`, `json`, `jsonc`) in `PluginCatalog.builtIn` after Table; `TextPlugin` drops `json` and `jsonc`; routing, extension and tool tests updated first.

## 2. JSON model

- [x] 2.1 Failing tests: the parser builds nodes with kinds, keys and exact key and value ranges; accepts comments and trailing commas; decodes string escapes for display; reports errors with line and column.
- [x] 2.2 Failing tests: each text change (set value as string or literal, rename, delete first/middle/last/only item with commas and lines, add after, add child into empty and non-empty containers, move) gives exactly the expected text, keeping comments and other formatting.
- [x] 2.3 Implement `JSONParser`, `JSONNode` and the edit functions.

## 3. Document and views

- [x] 3.1 Failing tests: open parses off the main thread; tree by default, text when remembered; Show Text toggles and is remembered; a bad file opens in text with the error and the tree unavailable; over 10 MB read-only; the Peek panel doesn't edit.
- [x] 3.2 Failing tests: tree edits through the document change the text, undo as one step, and mark it edited; save keeps the format and offers UTF-8; recovery and restore; revert and reload; the outline lists top-level children.
- [x] 3.3 Implement `DataDocument`, the outline view with light cells and an editing field, the text view with coloring, the error bar and the sidebar outline.
- [x] 3.4 Failing tests where the view can be checked off screen: tree rows and values, editing a value through the tree, drag-reorder reaching the text.

## 4. Checks and docs

- [x] 4.1 `bench/make-fixtures.swift` writes `small.json` and `large.json`; `bench/ppbench.py` times them (TextEdit, descriptions); run `scripts/bench-ab.sh` and `ppbench.py space`.
- [x] 4.2 Screen tests: routing cases for `json` and `jsonc`; a `data-edit` flow (Space shows the tree; open, edit a value through the tree, save and compare the file; Show Text and back; a file with a syntax error shows the bar); wired into `screen-test.sh`; `run-peeker` skill updated.
- [x] 4.3 `scripts/build.sh test` passes with no new warnings; review by the oracle before committing.
- [x] 4.4 README, CHANGELOG, backlog (YAML/XML/plist/TOML as the next change); `openspec validate --all --strict`.

## Workflow follow-up

- Commit the change, then bump the minor version in its own commit; run the screen flows; archive, push and install.
