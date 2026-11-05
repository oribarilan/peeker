# Tasks

## 1. The shared look

- [ ] 1.1 Write failing tests in a new `Tests/HoverTests.swift`: `HoverStyle`'s color is the accent at 22% and its fade is 0 with Reduce Motion (replaceable for the test); `HoverFill` is hidden at first, shows when hovered and hides when not.
- [ ] 1.2 Implement `HoverStyle` and `HoverFill` in `Sources/PeekerKit/`; verify the tests pass and the plugin import check still passes.

## 2. Each place

- [ ] 2.1 Toolbar: `toolbar-shortcuts-and-tips` kept the tools as native image items, so there's no `ToolbarButton` to track the pointer. First check on screen whether macOS 26 already shows a hover on toolbar capsules; if it does, leave the toolbar to it and update the design and spec; if not, bring the question back to the maintainer.
- [ ] 2.2 `HistoryTrail`: the same for its place buttons.
- [ ] 2.3 `OutlineList`: switch `OutlineRowView` to `HoverStyle`; update its test for the color; verify selected rows draw no hover.
- [ ] 2.4 `PageList`: hover tracking and the fill in its row views, skipping the selected page; test as for the outline.
- [ ] 2.5 `PageThumbnails`: the overlay `HoverFill` over the item under the pointer, skipping selected pages; test with synthetic mouse-moved events that the fill moves to page 2's frame and hides on exit.
- [ ] 2.6 Settings' `ThemeCard`: `.onHover` with `HoverStyle`'s color and radius, none on the selected card.

## 3. Checks and docs

- [ ] 3.1 Run `scripts/build.sh test`; verify everything passes with no new warnings.
- [ ] 3.2 Add a screen step to `scripts/screen/viewer-flow.sh` that moves the pointer over a PDF window's toolbar button and a page thumbnail and checks the captured pixels change (`drive pixel` on before and after shots); capture light and dark screenshots as evidence; run once the maintainer gives the go.
- [ ] 3.3 Add a CHANGELOG line under Unreleased and verify `openspec validate --all --strict`.

## Workflow follow-up

- Apply after `toolbar-shortcuts-and-tips`. Commit the change, then bump the minor version in its own commit, both when the maintainer asks; archive.
