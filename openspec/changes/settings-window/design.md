# Design

## Context

See proposal.md for why. What exists today:

- `ConfigStore` (`Sources/Host/App/ConfigStore.swift`) reads `config.json` at launch and again whenever it changes, keeps the last usable `Config` and the problems, and calls `AppDelegate.configChanged`, which applies settings everywhere. It never writes.
- `Config` holds `disabled`, `extensions` (only lists the file gives), `keys` (shortcut overrides) and `quickLookKey`. `Config.owners(of:)` resolves which plugin owns each extension and reports clashes. `Shortcut` parses config text such as `cmd+shift+h` but can't write it back.
- `SettingsWindowController` hosts one SwiftUI `Form`, the Config file pane, in a 560×420 `NSWindow`.
- `AppDelegate.startHotkey` asks for Accessibility once and polls every 2 s until the event tap starts, then stops polling. Nothing else watches the permission.
- `MenuBarItem.show(problems:)` draws the red dot. Open at Login is in the menu bar menu and the app menu (`MainMenu`).
- `FileReplacement.replaceContents(ofFileAt:with:)` writes atomically, follows a symlink to its target and keeps permissions.

Tinycast, the model (AGPL, ideas only): a `NavigationSplitView` in a plain window, panes as an enum with a title and SF Symbol, permission rows with a status label and Grant Access or Open, status re-read every second while the pane is visible, a custom shortcut recorder, and a config file re-rendered in full from an ordered tree, written only when the rendering differs.

## Goals / Non-Goals

**Goals:**
- One write path for the config, so every pane saves the same way and the file always reads back to what the window shows.
- Panes built from the plugin list (`PluginEntry`: id, name, default extensions, commands), so a new plugin gets a pane with no Settings code.
- Pure, testable logic for everything that isn't drawing: writing the config, shortcut text, clash checks, moving an extension, default-app status.

**Non-Goals:**
- A way for plugins to add their own settings rows. The pane has host rows only until a plugin needs more.
- Search in the sidebar, Back/Forward history, or remembering the last pane across launches.
- Preserving hand formatting when Settings writes. A full rewrite was decided; patching JSON in place would need a format-preserving parser.

## Decisions

### 1. Window: SwiftUI `NavigationSplitView` in the existing `NSWindow`

Keep `SettingsWindowController` and its `NSHostingController`, and swap the root view for a `NavigationSplitView` with a fixed-width sidebar (about 200 pt) and the selected pane as a grouped `Form`. The window grows to about 720×520, resizable, with a frame autosave name. Panes are an enum, `general`, `plugin(id)`, `permissions` and `configFile`, so menu items can open a given pane (`showSettings(pane:)`). Opening Settings again while it's open selects the requested pane.

*Alternatives:* SwiftUI's `Settings` scene (it doesn't fit an AppKit app that already manages its own windows and presence); AppKit `NSSplitViewController` with hand-built panes (more code for the same result, and the Config file pane is already SwiftUI).

### 2. One write path: `ConfigStore.save(_:)` renders the whole config

`ConfigStore.save { config in … }` applies the change to a copy of the current `Config`, renders it, and writes it:

- **Rendering** (`Config.json(plugins:)`, a new file next to `Config.swift`): `$schema`, `quickLook.key`, and for every plugin `enabled`, `extensions` (its effective list: the configured or default list minus any extension another plugin keeps) and `commands.<id>.shortcut` (override or default; commands with neither are left out). Serialized with sorted keys, pretty-printed, slashes unescaped, trailing newline. Because it's built from `Config`, unknown keys and unusable values disappear by construction.
- **Writing**: skip when the bytes equal the file's (as Tinycast does). Otherwise create the folder if needed, write through `FileReplacement` (so a symlink stays a symlink), write `schema.json` too when the folder was just created, then re-read at once so the window and the app update without waiting for the file watcher. The watcher's own re-read afterwards finds the same content and changes nothing.
- **Failure**: an alert with the error; the store's settings stay as they were, so the control snaps back.

`Config.read(json(c))` returning `c` is the contract, and the tests check it.

*Alternatives:* writing only the keys that differ from defaults (rejected in the interview: the file should show every setting); patching the user's JSON (see Non-Goals).

### 3. Locking: `ConfigStore.isUsable`

`ConfigStore` records whether the last read produced a `Config` (`isUsable`). A missing file is usable (defaults). Panes that change the config apply `.disabled(!store.isUsable)` and show a banner at the top ("config.json isn't valid JSON, so these settings are locked") with the first problem and Open in Editor. `save` refuses to write while unusable, as a second guard. The Permissions pane doesn't read `isUsable`.

### 4. `Shortcut` writes its config text

Add `Shortcut.configText`, modifiers in a fixed order (`ctrl+opt+shift+cmd+`) then the key (`space`, `esc`, `tab`, `enter`, or the character). A test parses `configText` back for every key `Shortcut` supports. Also add `init?(event: NSEvent)` mapping a key event to a `Shortcut` through the same key-code table, returning nil for keys the config can't express (arrows, function keys), which is what the recorders refuse.

### 5. Key recorder: one AppKit view, two rule sets

`KeyRecorder` is an `NSViewRepresentable` around a small `NSView` that starts recording on click, captures the next key with a local `NSEvent` monitor (SwiftUI focus would otherwise swallow Space, Tab and Escape), and stops on a key, on Escape (cancel) or on losing focus. Refusals show for a moment under the recorder, then it returns to the current value.

- **Quick-look key rules:** bare Space, or any supported key with a modifier. Off is a separate control next to it.
- **Command rules:** a modifier is required, and the shortcut must not equal another command of the same plugin (effective shortcuts) or any item in the app's main menu outside the Commands menu. The menu shortcuts are read from `NSApp.mainMenu` itself, so the list can't drift from `MainMenu`.

While any recorder is recording, the app pauses its quick-look hotkey monitor (a callback to `AppDelegate`), so pressing the current key, such as Option-Space, records it instead of opening the panel.

The clash check is a pure function, `shortcutConflict(_:command:plugin:config:menu:) -> String?` (the name of what uses it), tested without UI.

### 6. Extension tokens and moving

The list is a wrapping row of capsule tokens, each with a remove button, followed by a text field. Entries go through the same check as config entries: `Config`'s private `listEntry` becomes internal and is shared. Adding one another plugin owns (from `config.owners(of:)`) shows a confirmation naming that plugin, with Move and Cancel. Move is one `save`: the extension leaves the owner's effective list and joins this one. Reset drops the plugin's own list, so its default list applies again (and is written out, since every setting is). By the ownership rule a default extension that was moved to another plugin comes back, and the rewrite takes it off that plugin's list. An extension the plugin took from another goes back to the plugin that lists it by default, so resetting either side undoes a move (found while checking the window: resetting Plain Text after moving `md` there left `md` with no plugin). The move and reset logic are pure functions on `Config`, tested without UI.

### 7. Permissions: polled while visible, Accessibility watched app-wide

- **Accessibility:** `AXIsProcessTrusted()`.
- **Finder automation:** `AEDeterminePermissionToAutomateTarget` for `com.apple.finder` with `askUserIfNeeded` false. It can block, so it runs off the main thread. The result maps to granted (`noErr`), not granted (`errAEEventNotPermitted`) or not asked yet (`errAEEventWouldRequireUserConsent`). When Finder isn't running (`procNotFound`), the last known status is kept.
- **Open at Login:** `SMAppService.mainApp.status`.

The pane re-reads all three every second while it's on screen. Grant Access opens `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility` or `…?Privacy_Automation`. For Finder in the not-asked state it calls the same API with `askUserIfNeeded` true, which shows the system's request. `NSAppleEventsUsageDescription` is already in the Info.plist.

For the red dots, a small `AccessibilityStatus` object owned by `AppDelegate` replaces the startup-only trust timer. While the quick-look key is on, it polls `AXIsProcessTrusted()` every 2 s, starts the event tap when trust appears, and publishes `isMissing`. That's a cheap call, and the current timer already makes it, just only until the first grant. `MenuBarItem.show(problems:needsAccessibility:)` shows the dot when either is set. A menu line, "Space in Finder needs Accessibility…", opens `showSettings(pane: .permissions)`. The maintainer approved this line on 2026-10-30, so the dot always has an explanation, as config problems do. The sidebar row draws its dot from the same object.

### 8. Default app per plugin

For each extension in a plugin's effective list, `UTType(filenameExtension:)` gives the type. `noExtension` and dynamic types (no system type, such as `conf`) are "can't set". Extensions that share a type (`jpg`/`jpeg`) are checked once. `NSWorkspace.urlForApplication(toOpen:)` gives the current app, compared by bundle identifier (not URL, so a dev build in `build/` counts). The plugin's status is all, some (n of m settable) or none. Make Default calls `NSWorkspace.setDefaultApplication(at: Bundle.main.bundleURL, toOpen:)` for each type that isn't already Peeker, then refreshes. The status is read when the pane appears, when the window becomes key and after Make Default, not on the 1 s timer. LaunchServices queries are cheap, but there's no reason to repeat them. Classifying the per-extension results into all, some or none is a pure function with tests.

### 9. Menus

Open at Login leaves `MainMenu` and `validateMenuItem` keeps serving the menu bar item. The problems line opens `.configFile`; the new Accessibility line opens `.permissions`.

### 10. Files

`Sources/Host/Settings/`: `SettingsWindowController.swift` (window and sidebar), `ConfigFilePane.swift` (moved out), `GeneralPane.swift`, `PluginPane.swift`, `ExtensionTokens.swift`, `KeyRecorder.swift`, `PermissionsPane.swift`, `Permissions.swift` (status checks), `DefaultApps.swift`. `Sources/Host/App/`: `ConfigRendering.swift` (writer), `AccessibilityStatus.swift`, small additions to `Config`, `ConfigStore`, `Shortcut`, `MenuBarItem`, `MainMenu` and `AppDelegate`. No plugin module changes, so `check-plugin-imports` is unaffected.

## Risks / Trade-offs

- [The first Settings change rewrites a hand-formatted file and drops unknown keys] → This is the decided behavior. The README says so, and only a change made in Settings writes. Opening the window never does.
- [Every setting is written, so a later version's new default extensions won't reach users who once saved from Settings] → Accepted with the full-rewrite decision. Reset in each plugin pane brings back the current defaults.
- [A write races an edit saved in another editor at the same moment] → Last write wins. The window re-reads right after writing and the watcher reports any later change, so what's shown matches the file.
- [`setDefaultApplication` may ask the user to confirm, or refuse for some types, on recent macOS] → Check on macOS 26 during the build. Report a refusal on the row, and keep "Open with" in Finder's Get Info as the fallback the row mentions for types it can't set.
- [`AEDeterminePermissionToAutomateTarget` blocks or launches nothing when Finder isn't running] → Run it off the main thread, keep the last status on `procNotFound`, and poll only while the pane is visible.
- [Polling Accessibility for the whole session costs something] → One `AXIsProcessTrusted()` call every 2 s, only while the quick-look key is on. The existing trust timer already does this until the first grant.
- [The local key monitor in the recorder could swallow keys meant for other fields] → It's installed only while a recorder is recording, and removed on stop or focus loss.

## Migration Plan

None needed. Existing configs keep working unchanged until the user first changes something in Settings, which writes the full file. Rolling back to an older build reads the written file fine: it only contains keys that build already knows.
