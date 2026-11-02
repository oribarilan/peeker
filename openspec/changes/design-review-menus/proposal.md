# Proposal

## Why

The design review (`docs/design-review-2026-11-01.md`) found Peeker's menus thin and oddly organized: no View menu, a "Commands" menu that mixes zoom with edit tools, Open With only in the toolbar, no Open Recent or Revert, missing standard app and window items, a sidebar that can only be dragged shut and comes back after every save, and a Wrap Lines toggle that never shows its state. This change fixes findings W2, M1, M2, M3, M4, M5, T1 and M9, the menus theme agreed with the maintainer.

## What Changes

- The menu bar becomes Peeker, File, Edit, View, Tools, Window, Help in every window. **BREAKING** for anyone used to it: the Commands menu goes away.
- **View** holds Show/Hide Sidebar (Ctrl+Cmd+S), Show/Hide Toolbar and Enter Full Screen, then the document's commands that aren't edit tools (zoom, Actual Size, Wrap Lines).
- **Tools** holds Edit Mode (Cmd+E) and the edit tools (Crop, Rotate & Resize, Text Box, Sign, Highlight, page commands). It stays in the menu bar for documents without them, with Edit Mode greyed out.
- **File** gains Open Recent (with Clear Menu), an Open With submenu that switches plugins like the toolbar control, and Revert to Saved…, which asks first and is greyed out when there's nothing unsaved. The toolbar's Open With control gets a tooltip.
- **Peeker** gains Hide Others (Opt+Cmd+H) and Show All; **Window** gains Zoom and Bring All to Front; a new **Help** menu's Peeker Help opens the project page.
- The info sidebar gets the system sidebar button in the toolbar. Whether it's shown and its width are remembered for all windows, across saves, reloads and relaunches.
- A command that can be on or off (Wrap Lines) shows a checkmark in its menu and an on look on its toolbar button.
- PDF Sign loses its default shortcut, Ctrl+Cmd+S, which now belongs to the sidebar. A config that gives a plugin command a key a menu item already uses reports a problem, and the command runs without that key.
- The quick-look-panel spec stops claiming Open at Login is in the app menu (it's only in the menu bar icon's menu, as the code and its test have it).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `plugin-host`: the host's menus (new menu bar requirement, View, Tools, File additions, standard items, Help), the sidebar toggle, commands that show their on state, and the Commands menu renamed in existing requirements.
- `documents`: edit tools are listed in the Tools menu instead of Commands; Revert to Saved joins the ways edits are discarded, always asking.
- `pdf`: Sign has no default shortcut; page commands and waiting tools are in the Tools menu.
- `text`: Wrap Lines is in the View menu and shows whether it's on.
- `routing-and-config`: Open With is also in the File menu; a command shortcut that a menu item already uses is a config problem.
- `quick-look-panel`: Open at Login lives only in the menu bar icon's menu.

## Impact

- Host: `Sources/Host/App/MainMenu.swift` (menu bar), `AppDelegate.swift` (rebuilding the plugin parts of View and Tools, Open Recent, Help), `Sources/Host/Documents/DocumentWindowController.swift` (Open With submenu, Revert, toolbar sidebar button and toggle look), `DocumentViewController.swift` (one sidebar item kept and refilled, remembered state), `Sources/Host/App/Config.swift` (menu key clashes as problems), `Sources/Host/Settings/KeyRecorder.swift` (which menu items are plugin items).
- Plugin contract: one optional `PluginDocument` method reporting whether a command is on (`Sources/PeekerKit/Plugin.swift`); the text plugin implements it. `Plugins/pdf/PDFPlugin.swift` drops Sign's default key.
- Tests: `MainMenuTests`, `EditModeTests`, `SingleKeyShortcutTests` and config tests change; new tests for the menus, sidebar memory, Revert, Open With and command state.
- Screen flows: every `menu Peeker Commands …` step moves to Tools, and four new checks (sidebar after a save, menus' contents, Open With and Revert, Wrap Lines checkmark).
- No new dependencies. Opening speed is unaffected; the sidebar keeps being added after first paint.
