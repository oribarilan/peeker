# Tasks

## 1. Reduce Motion and Play Animation

- [x] 1.1 Write failing tests in `Tests/ImageDocumentTests.swift`: with Reduce Motion (the player's `reducesMotion` replaced) a GIF opens paused on frame 0 and a toggle plays it; Play Animation is a tool only for animated images, `isOn` follows playing, and running it pauses.
- [x] 1.2 Implement them in `AnimationPlayer`, `ImagePlugin.tools` and `ImageDocument` (`tools`, `isOn`, `perform`); update the exact tool lists in `PluginToolsTests` and `ToolbarTests`; verify the full suite passes.

## 2. Screen flow and docs

- [x] 2.1 In `scripts/screen/viewer-flow.sh`, after the GIF's click checks, choose View > Play Animation and check the menu item loses its checkmark and the frames stop, then choose it again and check they play; verify with the viewer flow.
- [x] 2.2 Add a CHANGELOG line under Unreleased, drop I4 from `openspec/backlog.md`, and verify `openspec validate --all --strict`.

## Workflow follow-up

- Commit the change, then bump the minor version in its own commit, both when the maintainer asks; mark I4 fixed in `docs/design-review-2026-11-01.md` with the commit hash; archive.
