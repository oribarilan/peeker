# Tasks

## 1. The Peek panel rename (S5)

- [x] 1.1 Update the config tests first (`ConfigTests`, `ConfigSchemaTests`, `ConfigStoreTests`, `SettingsLogicTests`, `HotkeyDecisionTests`, `TestSupport`): `{"peekPanel": {"key": ...}}` sets the key, `quickLook` is reported as an unknown key and leaves the default, rendering writes `peekPanel`, the schema has `peekPanel` and no `quickLook`; watch them fail. Then rename the config section, `Config.peekPanelKey`, `readPeekPanel`, the schema and rendering; verify the tests pass
- [x] 1.2 Rename the code: `Shortcut.Rules.peekPanel`, the recorder id, `peekFinderSelection`, `git mv Sources/Host/QuickLook Sources/Host/PeekPanel` with `QuickLookPanel.swift` → `PeekPanel.swift` and class `PeekPanel`, the log category, comments; verify `scripts/build.sh` has no warnings and `scripts/build.sh test` passes
- [x] 1.3 Rename the user text: General's toggle and footer, Permissions' header and Accessibility detail, the menu bar icon's Accessibility line ("The Peek panel needs Accessibility…"), the Apple Events usage string in `project.yml`, alerts; add a test that the menu bar line's title names the Peek panel; verify the tests pass
- [x] 1.4 Rename the docs and agent files: README, BENCHMARKS.md prose, AGENTS.md, `.claude/skills/run-peeker/SKILL.md`, `openspec/config.yaml`, `openspec/gaps.md` (capability references included), comments in `scripts/` and `bench/`; make the space harness in `bench/ppbench.py` write `{"peekPanel": {"key": "space"}}` to `config.json`; verify `python3 -m py_compile bench/ppbench.py` and that `grep -rniE "quick.?look|space panel|space in finder"` over current files (archived changes, dated reviews, `decisions/`, `research/`, `REPORT.md` excluded) finds only Finder's Quick Look

## 2. Settings window (S1, S2, S4)

- [x] 2.1 Write failing tests: `SettingsPane` round-trips through its storage key, an unknown key gives nil; a `SettingsModel` with in-memory defaults starts on General, remembers a selection, and a new model with the same defaults starts on it; a stored pane for a plugin that's gone gives General. Then add the storage key and the model's memory, passing `.standard` from `AppDelegate`; verify the tests pass
- [x] 2.2 Write a failing test that the Settings window's zoom button is disabled and the window is still resizable; then disable it in `SettingsWindowController`; verify the test passes
- [x] 2.3 Write failing tests: built-in plugins name `photo`, `doc.richtext`, `number`, `doc.plaintext`, a plugin naming none gets `puzzlepiece.extension`, and `PluginEntry` carries the symbol. Then add `symbol` to `Plugin` with its default, to `PluginEntry`, to each built-in plugin, and use it in `SettingsView`; verify the tests pass and `scripts/build.sh test` still passes the plugin import check

## 3. Panes (S3, S6, A2)

- [x] 3.1 Give the add-extension field its prompt "Add an extension"; verify in the screen test (4.1)
- [x] 3.2 Move Open at Login into a `LoginSection` and the Default app list into a `DefaultAppSection`, both shown in General after the Peek panel section and before Updates and not disabled while the config is locked; Permissions keeps only the two permission rows under "Peek panel"; verify the build, `scripts/build.sh test`, and the screen test (4.1)
- [x] 3.3 Write failing tests: a refusal posts an announcement with its reason (through a replaceable `announce`), and the reason is still there after 3.5 s and gone once recording starts again; then change `refuse`; verify the tests pass

## 4. Screen tests

- [x] 4.1 In `record-flows.sh`: write `peekPanel` instead of `quickLook` and read it in `cfg`; check the General toggle reads "Peek panel"; choose the PDF pane, close Settings, reopen it and check the PDF pane shows; check General has Open at Login and Default app and Permissions doesn't; check the add-extension field's placeholder (`AXPlaceholderValue`, adding a driver command if needed); update the run-peeker skill's description of the flow; verify `bash -n` and that the driver builds

## 5. Wrap-up

- [x] 5.1 Add Unreleased lines to `CHANGELOG.md` (the Peek panel name and config key, Settings remembering its pane, plugin icons, Open at Login and Default app in General, the placeholder, the recorder's announced reason) and mark S1 to S6 and A2 in progress in `docs/design-review-2026-11-01.md`; verify `openspec validate --all --strict`
- [x] 5.2 Run `scripts/build.sh` and `scripts/build.sh test`; verify all tests pass with no new warnings
- [ ] 5.3 With the maintainer's go, run `scripts/screen-test.sh`; verify every flow passes and look at the Settings captures
- [ ] 5.4 With the maintainer's go, run `scripts/bench-ab.sh main` once; verify no regression on the open benchmarks

## Workflow follow-up

- Once committed (on the maintainer's request), set S1 to S6 and A2 to fixed with the commit hash in the design review.
- Archive with `/opsx:archive`, then retitle the scenarios OpenSpec couldn't rename ("Space panel" twice in `pdf`, "Moving the panel to Option-Space" and "Turning the panel off" in `settings`) and run `openspec validate --all --strict`.
