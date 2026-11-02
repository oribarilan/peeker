# Proposal

## Why

Every Peeker setting lives in `config.json`, and the Settings window can only show where that file is and what's wrong with it. Turning a plugin off, giving it an extension or rebinding a shortcut means hand-editing JSON. When Space in Finder doesn't work, nothing tells the user the cause, which is usually a missing Accessibility permission. This change makes Settings a real settings window, modeled on Tinycast's: a sidebar of panes that change the config for the user and show the permissions the app needs. The design decisions come from the maintainer interview of 2026-10-30, recorded in `openspec/config.yaml`.

## What Changes

- The Settings window gets a sidebar of panes: General, one pane per plugin (Image, PDF, Markdown, Plain Text, in sidebar order), Permissions, and Config File (today's pane).
- **General** sets the quick-look key with a key recorder that accepts a bare Space or a key with modifiers, plus Off.
- **Each plugin pane** has host-provided rows only:
  - an on/off switch
  - its extensions as removable tokens, with a free-text Add and a Reset to the default list; adding an extension another plugin opens offers to move it
  - a shortcut recorder for each command, which refuses keys already taken by another command of the same plugin or by an app menu item, with a reset to the default
- **Permissions** shows:
  - live status for Accessibility and for automating Finder, with Grant Access or Open System Settings
  - Open at Login, with its status
  - whether Peeker is the default app for each plugin's extensions, expanding to one row per extension when it's only partly the default, with Make Default
- **Writing the config.** The config file stays the only store. Only a change made in Settings writes it, and a write replaces the whole file: every setting, defaults included, with sorted keys, through the existing safe-write path. Keys the app doesn't understand are dropped. While the file isn't valid JSON (or can't be read), every control is locked and the window says why.
- **BREAKING**: `config.json` is no longer read-only to the app. A change made in Settings rewrites it, so hand formatting, key order and unknown keys don't survive that write. Editing the file by hand keeps working as before, and the app never writes it on its own.
- Open at Login leaves the app menu. It stays in the menu bar icon's menu and gains a row in Permissions.
- When the quick-look key is on but Accessibility is missing, a red dot appears on the Permissions row in the sidebar and on the menu bar icon.

## Capabilities

### New Capabilities

None. The window's behavior belongs to the existing `settings` capability.

### Modified Capabilities

- `settings`: from one Config file pane to a sidebar of panes; adds the General, plugin and Permissions panes, writing the config from the window, and locking while the file is unusable.
- `app-presence`: the menu bar icon's red dot also shows a missing Accessibility permission, and its menu explains it.
- `quick-look-panel`: Open at Login moves from the app menu to the Permissions pane (it stays in the menu bar menu); the permission requirement gains the Permissions pane as the place to see and fix status.
- `routing-and-config`: the app may now write `config.json`, but only to save a change the user made in Settings.

## Impact

- **Code.** Host only; no plugin changes. Mainly in `Sources/Host/Settings/` (window, panes, key recorder, permission and default-app checks), `Sources/Host/App/` (`Config` gains a writer, `Shortcut` gains its config text, `ConfigStore` knows when the file is unusable and saves changes), `MenuBarItem`, `MainMenu` and `AppDelegate` (red dot for Accessibility, Open at Login out of the app menu).
- **APIs used.** SwiftUI inside the existing `NSWindow`, `AXIsProcessTrusted`, `AEDeterminePermissionToAutomateTarget`, `SMAppService`, `NSWorkspace.urlForApplication(toOpen:)` and `setDefaultApplication(at:toOpen:)`, and `x-apple.systempreferences:` links. No new dependencies.
- **Files.** `config.json` is written by the app for the first time, always through `FileReplacement`, so a symlinked config stays a symlink.
- **Docs.** README's Config section explains that Settings rewrites the file. The run-peeker skill gains a Settings check.
- **Not in scope:** settings that plugins add to their own panes (no plugin needs one yet), clearing a shortcut so a command has none (the config can't express it), and per-extension routing beyond the plugin lists.
