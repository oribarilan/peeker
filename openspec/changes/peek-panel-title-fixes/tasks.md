# Tasks

## 1. Icons in menus

- [x] 1.1 Add the `NSMenuItem` helper that asks for its image to show (set by name when the item responds to `preferredImageVisibility`); use it for the Peek panel's app items in `OpenWith.swift` and for Open Recent's items in `RecentFiles.swift`. Verify with tests in `Tests/PeekPanelTests.swift` and `Tests/MainMenuTests.swift` that, on macOS 27, each app item and recent file item reads visible, and on macOS 26 the items are unchanged.

## 2. The title label

- [x] 2.1 Write failing tests in `Tests/PeekPanelTests.swift`: with a long file name, the title label's frame ends before the folder button and its line break mode is middle truncation; `panel.title` is the full name; with a short name the label shows the whole name; after the button's title changes or the panel narrows, the label still ends before the folder button.
- [x] 2.2 Hide AppKit's title, add the label to the title-bar accessory, and lay it out from the sidebar's edge (or after the window buttons) to the folder button, on file change, button title change and resize. Verify the 2.1 tests pass.
- [x] 2.3 Add a step to `scripts/screen/record-flows.sh`: Space on a file with a long name, a screenshot of the panel, and a check through Accessibility that the title label's frame ends left of the folder button. Run with the maintainer's go (queue it in `.local/screen-queue.md` otherwise).

## 3. Wrap-up

- [x] 3.1 CHANGELOG line under Unreleased; drop both backlog lines; `scripts/build.sh test` passes with no warnings; `openspec validate --all` passes.
