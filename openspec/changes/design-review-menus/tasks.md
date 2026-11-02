# Tasks

## 1. Menu bar (M1, M2, M4)

- [x] 1.1 Write failing tests in `Tests/MainMenuTests.swift`: the bar is Peeker, File, Edit, View, Tools, Window, Help; View has Show Sidebar (Ctrl+Cmd+S), Show Toolbar and exactly one full-screen item; Tools starts with Edit Mode (Cmd+E); Peeker has Hide Others (Opt+Cmd+H) and Show All; Window has Minimize, Zoom and Bring All to Front; Help has Peeker Help; `make` sets neither `NSApp.windowsMenu` nor `helpMenu`. Then change `MainMenu.make` and set both menus in `AppDelegate`; verify the tests pass
- [x] 1.2 Write failing tests (update `EditModeTests` and `SingleKeyShortcutTests`): rebuilding for an image puts zoom commands in View after its fixed items and Crop and Rotate & Resize in Tools after Edit Mode; for Markdown, Tools holds only Edit Mode, greyed out; rebuilding twice leaves no duplicates. Then replace `rebuildCommands` and `commandsMenu` with View and Tools, rebuilt on key-window change and when the last document window closes; verify the tests pass
- [x] 1.3 Add `showHelp(_:)` to `AppDelegate` opening the project page; verify with a test that the Help item targets it and the URL is the project's

## 2. Fixed menu keys (config and Settings)

- [x] 2.1 Write failing tests: `menuShortcuts(in:)` counts View's and Tools' fixed items and Edit Mode and skips plugin command items; `MainMenu.fixedShortcuts` contains Ctrl+Cmd+S (Show Sidebar) and Cmd+S; no plugin's default shortcut is in it. Then skip by action instead of menu title in `KeyRecorder.swift` and add `fixedShortcuts`; verify the tests pass
- [x] 2.2 Write failing config tests: `plugins.pdf.commands.sign.shortcut` = `ctrl+cmd+s` gives a problem at that path naming Show Sidebar and leaves Sign with no shortcut; `cmd+s` for a command names Save. Then check against the fixed keys in `ConfigReader.readCommands`; verify the tests and the existing config tests pass
- [x] 2.3 Drop Sign's default `ctrl+cmd+s` in `Plugins/pdf/PDFPlugin.swift`; verify the default-shortcut test from 2.1 and the Settings shortcut tests pass, and Sign shows no shortcut in a plugin pane test

## 3. Sidebar (W2)

- [x] 3.1 Write failing tests in a new `Tests/SidebarMemoryTests.swift` with a throwaway `UserDefaults` suite: a new window opens with the remembered collapse and width; collapsing in one window collapses the others; a save and a reload keep the same split item and its collapse; a document without panels has no sidebar item and its Show Sidebar item is greyed out. Then add `SidebarMemory`, refill the existing item in `installSidebar`, and save and broadcast user changes from the split view; verify the tests pass
- [x] 3.2 Add `.toggleSidebar` at the start of the toolbar for documents with a sidebar; verify with a test of `toolbarDefaultItemIdentifiers` for a PDF and for a document without panels

## 4. File menu (M3, M5)

- [x] 4.1 Write failing tests: Open Recent lists `recentDocumentURLs` with Clear Menu last, and an item opens its URL through `AppDelegate.open`. Then add the Open Recent submenu and its delegate; verify the tests pass
- [x] 4.2 Write failing tests: File > Open With lists `openWithChoices` with the current plugin checked; choosing Plain Text on a Markdown document reopens it in the text plugin; it's greyed out with no document window. Then add the submenu, share `reopen(with:)` between it and the pop-up, and give the pop-up its tooltip; verify the tests and the existing Open With tests pass
- [x] 4.3 Write failing tests: Revert to Saved… is greyed out without unsaved edits; with edits, confirming restores the saved text and clears the edited state, and Cancel keeps the edits. Then add `revertDocument(_:)` with its sheet (the confirm made replaceable for tests, like `askToSave`); verify the tests pass

## 5. Command state (T1)

- [x] 5.1 Write failing tests: a text document reports Wrap Lines on, then off after running it; View > Wrap Lines is checked accordingly; its toolbar item is a push-on-push-off button whose state follows; a command whose document reports nil stays an image item. Then add `isOn(_:)` to `PluginDocument` with a nil default, implement it in `TextDocument`, and use it in `validateMenuItem` and the toolbar; verify the tests pass

## 6. Screen tests

- [x] 6.1 Change every `menu Peeker Commands …` step in `scripts/screen/*.sh` to `menu Peeker Tools …`, and the comments that name the Commands menu; verify `bash -n` on each script and `grep -n Commands scripts/screen` finds none
- [x] 6.2 Add the checks: image-edit flow, Tools has Crop, View has Zoom In and there's no Commands menu; viewer flow, on a text file Hide Sidebar hides it, an edit and Cmd+S keep it hidden and the toolbar button shows it again, and View > Wrap Lines is checked then unchecked; flows run, File > Open With > Plain Text switches a Markdown tab and Revert to Saved… after an edit asks and restores the file. Add any driver command needed (such as reading a menu item's checkmark) to `drive.swift`. Update the `run-peeker` skill's flow descriptions; verify `bash -n` and that the driver builds

## 7. Specs, docs and wrap-up

- [x] 7.1 Add Unreleased lines to `CHANGELOG.md` (View and Tools menus replace Commands, File's Open Recent, Open With and Revert, the sidebar button and memory, Wrap Lines state, Sign without a default key) and mark W2, M1, M2, M3, M4, M5, T1 and M9 in progress in `docs/design-review-2026-11-01.md`; verify `openspec validate --all --strict`
- [x] 7.2 Run `scripts/build.sh` and `scripts/build.sh test`; verify all tests pass with no new warnings
- [x] 7.3 With the maintainer's go, run `scripts/screen-test.sh`; verify every flow passes and look at the new captures
- [x] 7.4 With the maintainer's go, run `scripts/bench-ab.sh main` once; verify no regression on the open benchmarks

## Workflow follow-up

- Once committed (on the maintainer's request), set W2, M1, M2, M3, M4, M5, T1 and M9 to fixed with the commit hash in the design review.
- Archive the change with `/opsx:archive`.
