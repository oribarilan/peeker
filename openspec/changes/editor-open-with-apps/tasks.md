# Tasks

## 1. Shared app code

- [x] 1.1 Move `AppChoice` and the app ordering to `Sources/Host/App/AppChoices.swift` with `list`, `open` and `pickOther`; `PeekOpenWithMenu.items` and the panel's closures and Other… use them. Verify the existing `Tests/PeekPanelTests.swift` suites pass unchanged, plus a test of `AppChoices.sorted` (default first, A to Z, excluded IDs dropped, duplicates dropped).

## 2. Open With in the Editor

- [x] 2.1 Move `fillOpenWith` and `reopenWithMenu` to `DocumentWindowController+OpenWith.swift` and lower the ceiling in `scripts/long-files.txt`. Verify `scripts/lint.sh` and `Tests/FileMenuTests.swift` pass.
- [x] 2.2 Write failing tests in `Tests/FileMenuTests.swift` with the app list and the opener stubbed: the submenu lists the plugins, a separator, the apps with the default first, then Other…; it's enabled for a file one plugin reads; choosing an app opens the file in it once and keeps the window; with unsaved edits, Save saves then opens, Open Without Saving opens and keeps the edits, Cancel opens nothing.
- [x] 2.3 Fill the submenu with the apps and Other…, add the actions and the unsaved-edits sheet, and enable the submenu whenever a document shows. Verify the 2.2 tests pass.
- [ ] 2.4 Update `scripts/screen/record-flows.sh`: the Editor's Open With list for a `.md` now starts with Markdown, Plain Text, then apps; the photo step's comment says only the toolbar control is hidden. Run with the maintainer's go (queue it in `.local/screen-queue.md` otherwise).

## 3. Wrap-up

- [x] 3.1 CHANGELOG line under Unreleased; drop the backlog line; `scripts/build.sh test` passes with no warnings; `openspec validate --all` passes.
