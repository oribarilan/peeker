# Tasks

## 1. Config and rules

- [x] 1.1 `Shortcut.Rules.panelAction`; `Config.peekPanelOpenKey` and `peekPanelShowInFinderKey` read, rendered and in the schema, with problems for bare keys, unreadable keys and clashes. Tests in `ConfigTests` and `ConfigSchemaTests`.

## 2. Panel

- [x] 2.1 `HotkeyMonitor.decide` returns `.open` and `.showInFinder` for the configured keys while the panel is up, Finder is in front and the menu is closed; `AppDelegate` runs them on the panel. Tests in `HotkeyDecisionTests`.
- [x] 2.2 Captions and tooltips on both buttons, following Show shortcuts, laid out again when they change. Tests in `PeekPanelTests`.

## 3. Settings

- [x] 3.1 Two recorders in General with clear and Reset, refusing bare keys and clashes.

## 4. Checks and docs

- [x] 4.1 `scripts/build.sh test` passes with no warnings; `openspec validate --all` passes.
- [x] 4.2 Screen step in `record-flows.sh`: the captions show, Cmd+R closes the panel and selects the file, Cmd+O opens the Editor; check the General pane by eye.
- [x] 4.3 CHANGELOG line.
