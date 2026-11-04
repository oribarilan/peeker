# Tasks

## 1. The toolbar button

- [x] 1.1 Spike: make one PDF tool a `ToolbarButton` (image above, key below, bezel `.toolbar`, push on/push off) and screenshot the PDF window's toolbar next to the current one; verify the edit tools still sit on one piece of glass. If not, switch to the bordered-item fallback in the design and screenshot again. Keep the screenshots in `build/evidence/`. Done: neither kept the glass, so the tools stay image items with "icon | key" drawn as one image, each on its own capsule, the active one `.prominent` (see design).
- [x] 1.2 Write failing tests in `Tests/ToolbarTests.swift`: a tool with a key gets a button whose title is the key and whose Accessibility label is the tool's title; a tool without a key gets an empty title while captions are on; with captions off every title is empty; the item's `label`, `paletteLabel` and `menuFormRepresentation` title are the tool's title, and the menu form runs the tool; the active tool's button is `.on` and the others `.off`.
- [x] 1.3 Implement `ToolbarButton` and use it for every tool item, the sidebar item (replacing `.toggleSidebar`, before the tracking separator, caption from the main menu's key) and Back and Forward; move the active tool's look from `selectedItemIdentifier` to button state. Verify 1.2 and the existing toolbar, navigation and layout tests pass (update the ones that read `selectedItemIdentifier` or the `.toggleSidebar` identifier).

## 2. Tooltips

- [x] 2.1 Write failing tests: `Shortcut.tooltip(title:shortcut:)` gives "Highlight Selection (H)" and "Sign" without a key; a toolbar tool's tooltip has its key; a greyed tool's tooltip is its reason.
- [x] 2.2 Implement them, give the sidebar, Back and Forward items key tooltips, and add `.help` to Settings' icon-only buttons (the shortcut clear button, the extension token remove button); verify the tests pass.

## 3. Config and Settings

- [x] 3.1 Write failing tests in `ConfigTests`, `ConfigSchemaTests` and `SettingsLogicTests`: `showShortcuts` defaults to true, reads `false`, refuses a non-boolean as a problem at `showShortcuts`, renders, is in the schema with its default; the Settings model's checkbox writes it.
- [x] 3.2 Implement it in `Config`, rendering, the schema, `SettingsModel` and a "Show shortcuts in the toolbar" checkbox in `AppearancePane`; rebuild open windows' toolbars when it changes. Verify the tests pass.

## 4. PDF keys

- [x] 4.1 Update the PDF expectations in `PluginToolsTests` (and any test that presses ⌃⌘H or ⌃⌘T) to T, S and H with no keys for the rotate tools; write a failing test that H with a selection highlights through `handleToolKey` and that "h" typed into a focused text view doesn't.
- [x] 4.2 Change `PDFPlugin.tools`; verify the tests pass, and that `Tools` shows "Highlight (H)".

## 5. First-use tips

- [x] 5.1 Write failing tests: `TipStore` with a throwaway `UserDefaults` says show once per `plugin.tool` and remembers; resetting forgets; a window running a tool with a tip asks the store and, when the button is in the window, shows a popover with the tip and marks it seen; when the button isn't showing it doesn't mark it.
- [x] 5.2 Add `tip` to `ToolSpec`, the tips for Highlight, Text Box, Sign (PDF) and Crop (image) with the wording from the proposal's interview, `TipStore`, the popover from `DocumentWindowController` after a run, and Show Tips Again in `GeneralPane` (enabled from `@AppStorage("seenTips")`). Verify the tests pass.

## 6. Screen flows and docs

- [x] 6.1 Add `seenTips` to `PREF_KEYS` in `scripts/screen/common.sh`. In `pdf-edit-flow.sh`, check the Text Box button's caption reads T and its tooltip "Text Box (T)" (`drive tree`), that the first Text Box shows the tip bubble and the second doesn't, and keep pressing tools by name. Update any flow step that used ⌃⌘H or ⌃⌘T. Verify with the screen tests once the maintainer gives the go.
- [x] 6.2 Add a CHANGELOG line under Unreleased, document `showShortcuts` and the new PDF keys in the README's config section, and verify `openspec validate --all --strict` and `scripts/build.sh test`.

## Workflow follow-up

- Commit the change, then bump the minor version in its own commit, both when the maintainer asks; archive.
