# Tasks

## 1. Open… in the menu

- [x] 1.1 Update the `MenuBarMenu` test in `Tests/SettingsLogicTests.swift` to expect Open… first (action `showOpenPanel(_:)`), and add it to `MenuBarItem.menu(target:lines:)`; verify the test passes.
- [x] 1.2 In `showOpenPanel(_:)`, make the app regular and activate it before the panel and call `updatePresence()` when it closes; verify with real clicks that the panel is in front, that Cancel leaves no Dock icon and that an opened file keeps it.

## 2. Screen flow and docs

- [x] 2.1 In `scripts/screen/record-flows.sh`, choose Open… from the menu bar icon with no window open, check the Open panel is in front, Cancel it and check Peeker has no Dock icon again; verify with the flows screen test.
- [x] 2.2 Add a CHANGELOG line under Unreleased, update the M8 line in `openspec/backlog.md` to the icon-hiding half only, and verify `openspec validate --all --strict`.

## Workflow follow-up

- Commit the change, then bump the minor version in its own commit, both when the maintainer asks; archive.
