# Proposal

## Why

Peeker runs in the background with no Dock icon, so when its daily check finds an update, Sparkle's window opens behind whatever the user is doing and is easy to miss, and Sparkle warns about this for background apps. Users also can't let updates install by themselves, and after an update nothing says what changed. Other Mac apps that update through Sparkle (Ghostty, Tinycast) handle all three, and Peeker should before its first release reaches people.

## What Changes

- A scheduled check that finds an update while Peeker isn't the active app opens no window. The menu bar icon shows an indigo dot, and an "Update to 0.3.0…" item at the top of its menu opens the update window. While Peeker is active, and for Check for Updates…, the window opens at once as today. When the menu bar icon also has a problem to show, the red dot wins.
- **BREAKING** (config only, nothing released reads it): `updates.check` becomes `updates.automatic`, one of `"off"`, `"check"` (default, today's behavior) or `"download"`. A config that still says `check` reports it as an unknown key.
- With `"download"`, Peeker downloads an update in the background and installs it by relaunching quietly once no window or Peek panel is open; until then it waits, and quitting installs it.
- After an update, an "Updated to Peeker 0.3.0" window lists the notes of every version since the one last run, with a Done button. It opens right after an update the user installed from the update window; after a quiet install or a launch at login it waits for the first Peeker window. `updates.showWhatsNew` (default true) turns it off.
- Settings > General replaces the "Check for updates automatically" checkbox with an Automatic updates pop-up (Off, Check and Ask, Download and Install) and adds a "Show what's new after updating" checkbox.
- Release builds carry `CHANGELOG.md`, so the notes need no network request.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `updates`: the three automatic modes replace the on/off check, the gentle reminder for scheduled checks, quiet installs in download mode, and the what's-new window.
- `app-presence`: the menu bar icon shows an available update with an indigo dot and a menu item.
- `settings`: the General pane's update controls become a pop-up and a checkbox.
- `routing-and-config`: the `updates` section holds `automatic` and `showWhatsNew` instead of `check`.

## Impact

- `Sources/Host/App/Updater.swift`: Sparkle's updater and user-driver delegates, automatic download, quiet install.
- `Sources/Host/App/MenuBarItem.swift`, `AppDelegate.swift`: the update dot and menu item, telling the updater when windows close, the what's-new window at launch or first window.
- A new what's-new window and a changelog reader in `Sources/Host/App/`.
- Config: `Config.swift`, `ConfigRendering.swift`, `ConfigSchema.swift`; Settings: `GeneralPane.swift`, `SettingsWindowController.swift`.
- `project.yml`: `SUAllowsAutomaticUpdates` removed so automatic downloads can be turned on; `CHANGELOG.md` bundled as a resource.
- Tests: `UpdaterTests`, `ConfigTests`, `ConfigSchemaTests`, `SettingsLogicTests`, `MainMenuTests`, plus new tests for the changelog reader and the what's-new timing.
- Docs: README's config section, CHANGELOG, the screen-test flows. Version bump to 0.10.0-dev.
