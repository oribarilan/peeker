# Design

## Context

`MainMenu.make` builds Peeker, File, Edit, an empty Commands menu and Window, and sets `NSApp.windowsMenu` as a side effect. `AppDelegate` keeps the Commands submenu and refills it through `MainMenu.rebuildCommands` whenever a document window becomes key: Edit Mode first (when the document has an edit mode), then every plugin command, all targeting the window controller (`runCommand(_:)` by tag, `toggleEditMode(_:)`). `DocumentWindowController.validateMenuItem` greys out unavailable commands and checks the active one.

Settings refuses a plugin shortcut that a menu item uses: `menuShortcuts(in:)` (`KeyRecorder.swift`) walks the main menu and skips the Commands menu by its title. The config reader (`Config.swift`, `readCommands`) checks only the modifier rules, so a config can give a command Cmd+S today and AppKit decides at random which item fires.

The sidebar is an `NSSplitViewItem(sidebarWithViewController:)` that `DocumentViewController.installSidebar` removes and inserts again after every load, save, reload and replacement, which is why a collapsed sidebar comes back. It's inserted a frame after first paint, on purpose (about 6 ms off the open benchmark).

The toolbar is rebuilt per document (`rebuildToolbar`), with commands as image items whose selected look comes from the toolbar's single `selectedItemIdentifier`, used for the active command. Edit is a push-on-push-off button view.

Peeker isn't an `NSDocument` app. Every open already calls `NSDocumentController.shared.noteNewRecentDocumentURL`, but AppKit's own Open Recent items open through `NSDocumentController.openDocument(withContentsOf:…)`, which needs document types Peeker doesn't declare.

## Goals / Non-Goals

**Goals:**
- The menu bar, sidebar, Open With, Revert and command-state behavior in this change's specs.
- One list of fixed menu keys, used by both the config reader and Settings.
- No new work on the open path.

**Non-Goals:**
- Changing ⌘E, ⌥⌘W or ⌘R in images (M6, I2), zoom gaps between plugins (M7), the menu bar icon (M8), Settings polish.
- A user guide; Help opens the project page.
- Toolbar customization.

## Decisions

**Menus are built from one description.** `MainMenu.make(target:)` returns the whole bar (Peeker, File, Edit, View, Tools, Window, Help) and no longer sets `NSApp.windowsMenu` or `helpMenu`; `AppDelegate` does that after building it, so tests and the config can build a menu with no side effects. View holds its fixed items (Show/Hide Sidebar `toggleSidebar:` with Ctrl+Cmd+S, Show/Hide Toolbar `toggleToolbarShown:`, Enter Full Screen `toggleFullScreen:` with Ctrl+Cmd+F) and a separator; Tools holds Edit Mode. AppKit retitles all three fixed View items and validates them through the responder chain (the window and its split view controller). If AppKit also adds its own full-screen item to View, ours goes; a test checks there's exactly one.

**Plugin items are rebuilt into View and Tools.** `MainMenu.rebuildCommands(view:tools:for:)` removes the command items and the tagged separator before them (AppKit adds Show Tab Bar and Show All Tabs to View, so positions can't be trusted), then adds each command to View or Tools by `CommandSpec.isEditTool`, with the same titles, keys, tags and targets as today. Edit Mode is always present; with no document, or one whose `editMode` is `.none`, `validateMenuItem` greys it out (today it's left out of the menu). `AppDelegate` keeps both submenus instead of `commandsMenu`, and also rebuilds them when the last document window closes so stale commands don't linger.

**Settings and the config share the fixed keys.** `menuShortcuts(in:)` skips items whose action is `runCommand(_:)` instead of a menu by title, so View's and Tools' fixed items (and Edit Mode) count. `MainMenu.fixedShortcuts` builds the bar with no target and runs `menuShortcuts(in:)` on it; it's computed once. The config reader takes it as an input (default `MainMenu.fixedShortcuts`), and a command shortcut that matches one gets a problem, "“ctrl+cmd+s” is used by Show Sidebar." at `plugins.<id>.commands.<command>.shortcut`, and goes into `noShortcut`, so the command has none while the menu keeps its key. That's what the maintainer chose; the parse-failure path keeps the default instead, which is fine since a clash is a different mistake. A test checks no plugin's default key is in the fixed list.

**One sidebar item, refilled, with remembered state.** `installSidebar` keeps the split item once it exists and swaps the view inside its holder (`HolderViewController.show`) instead of removing and inserting the item; with no panels it removes the item as today. When it first inserts the item it sets `isCollapsed` and the thickness from a small `SidebarMemory` value backed by `UserDefaults` (keys `sidebarHidden`, `sidebarWidth`; window state, not a setting, so it stays out of the config file). The split view controller saves them back from `splitViewDidResizeSubviews(_:)` when the change came from the user (collapse or drag), and every open window applies a change through a notification so all windows agree. `SidebarMemory` takes its `UserDefaults` in its initializer so tests use a throwaway suite. Considered: `splitView.autosaveName`. It saves divider positions per split view, misbehaves when items come and go, and doesn't sync open windows.

**The sidebar button is the system one.** The toolbar's default items start with `.toggleSidebar` when the document has a sidebar, then Open With. It targets `toggleSidebar(_:)` through the responder chain, the same as the menu item. Until the first open ends the window assumes a sidebar, so the first toolbar already has the button; rebuilding the toolbar mid-open forced a full layout before first paint, which cost a large Markdown file about 140 ms in the benchmark. A document that turns out to have none loses the button a frame after its content shows. Considered: a tracking separator over the sidebar; it makes the toolbar layout depend on the sidebar width and isn't needed here.

**File additions.** Open Recent is a submenu whose delegate fills it on open from `NSDocumentController.shared.recentDocumentURLs`, each item calling `AppDelegate.open(_:)` with its URL, then a separator and Clear Menu (`clearRecentDocuments:`). This avoids AppKit's built-in recent menu, which opens through `NSDocument` machinery Peeker doesn't use. Open With is a submenu the window controller fills on open from `catalog.openWithChoices(for:)`, current plugin checked, each item going through the same path as the toolbar control (`reopenWith` split into a menu and a pop-up entry point sharing one `reopen(with:)`); with no document window in front it's greyed out. The pop-up gets `toolTip = "Open With"`. Revert to Saved… (`revertDocument(_:)` on the window controller) is enabled while `current?.isEdited == true`, shows a sheet ("Revert to the last saved version?", "Your unsaved changes will be lost.", Revert / Cancel), and on Revert calls `finishTyping()` then `discardEdits()`.

**Standard items.** Peeker: Hide Others (`hideOtherApplications:`, Opt+Cmd+H) and Show All (`unhideAllApplications:`). Window: Minimize, Zoom (`performZoom:`), the tab items, a separator and Bring All to Front (`arrangeInFront:`). Help: Peeker Help (`AppDelegate.showHelp(_:)`, opening `https://github.com/oribarilan/peeker`), set as `NSApp.helpMenu`.

**Command state is one optional contract method.** `PluginDocument` gains `func isOn(_ command: String) -> Bool?`, default `nil` ("not a toggle"). The host builds a command whose document answers non-nil as a push-on-push-off toolbar button (like Edit) instead of an image item, sets its state after each run and on every toolbar rebuild, and sets the menu item's state in `validateMenuItem` (active command or on). Wrap Lines answers `wraps`. Considered: driving it through the toolbar's selected item; that's one item at a time and already belongs to the active command.

**Sign's default key goes.** `PDFPlugin` drops `shortcut: "ctrl+cmd+s"` from Sign. Settings shows Sign with no shortcut and Reset leaves it empty.

**Screen tests.** Every `menu Peeker Commands …` step becomes `menu Peeker Tools …`. New checks:
- In the image-edit flow: Tools has Crop and View has Zoom In, and there's no Commands menu.
- In the viewer flow: on a text file, View > Hide Sidebar hides the sidebar, an edit and Cmd+S keep it hidden, and the toolbar button shows it again.
- In the flows run: File > Open With > Plain Text on a Markdown file switches the tab; an edit then Revert to Saved… asks and restores the file.
- In the viewer flow: View > Wrap Lines is checked on a text file and unchecked after choosing it.

## Risks / Trade-offs

- [AppKit may add its own Enter Full Screen item to a menu titled View, giving two.] → The menu test and screen check count them; if AppKit adds one, drop ours.
- [`toggleSidebar:` validation when the window has no sidebar item: NSSplitViewController may leave it enabled and do nothing.] → `DocumentWindowController.validateMenuItem` greys it out when the document has no sidebar, and a test covers a document without panels.
- [Applying the remembered collapse on first insert could animate or flash.] → Set `isCollapsed` before inserting the item; the sidebar is added a frame after first paint either way, so the open benchmark doesn't move.
- [Removing Commands breaks muscle memory and the screen flows.] → Nothing is released yet; the flows move to Tools in this change.
- [A config written by Settings before this change saves Sign as `ctrl+cmd+s`.] → It now reports a problem and Sign has no key; the user clears it from Settings or the file. Nothing is released, so only test configs have it.
