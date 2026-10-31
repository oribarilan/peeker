# Tasks

## 1. Writing the config

- [x] 1.1 Add `Shortcut.configText` (modifiers as `ctrl+opt+shift+cmd+`, then `space`, `esc`, `tab`, `enter` or the character) and `Shortcut.init?(event:)` (nil for keys the config can't express); verify with tests that `Shortcut(parsing: s.configText) == s` for every supported key with and without modifiers, and that an arrow key event gives nil
- [x] 1.2 Add `Config.json(plugins:)` (design decision 2): `$schema`, `quickLook.key`, and per plugin `enabled`, its effective `extensions` (minus ones another plugin keeps) and each command's effective shortcut; sorted keys, pretty-printed, trailing newline; verify with tests that `Config.read(json)` gives back the same settings for defaults and for a config with every kind of override, that keys come out sorted, and that a clashing extension is left out of the losing list
- [x] 1.3 Give `ConfigStore` `isUsable` (false while the last read gave no `Config`; true for a missing file) and `save(_ change:)`: apply the change, render, skip if the bytes are unchanged, create the folder and `schema.json` when missing, write through `FileReplacement`, re-read at once, refuse while unusable, throw on failure; verify with `ConfigStoreTests` for a first save with no file, a save that drops an unknown key, a symlinked config that stays a symlink with the target changed, no write when nothing changed, and a refused save while the file is broken JSON
- [x] 1.4 Share `Config`'s extension check (make `listEntry` internal) and add pure helpers for the pane edits: add an extension, remove one, reset a plugin to its defaults, and move an extension from its owner; verify with tests, including moving `md` from Markdown to Plain Text and resetting Markdown afterwards, which takes `md` back
- [x] 1.5 Update the README's Config section: Settings rewrites the whole file on a change made there (sorted keys, every setting, unknown keys dropped), and the app never writes it otherwise; verify `ReadmeConfigTests` still passes

## 2. Window and panes

- [x] 2.1 Replace the root view of `SettingsWindowController` with a `NavigationSplitView`: a sidebar of General, one row per plugin in catalog order, Permissions and Config File, a grouped `Form` per pane, about 720×520, resizable, with a frame autosave name; move the Config file pane to `ConfigFilePane.swift`; add `showSettings(pane:)`, which selects a pane in an open window too; verify with a test that the pane list comes from the plugin list in order, and by opening Settings in the built app
- [x] 2.2 Lock the config-backed panes with `.disabled(!store.isUsable)` and a banner naming the problem with Open in Editor, leaving Permissions usable; verify with a `ConfigStore` test that a broken file makes it unusable and a fixed one usable again, and by saving broken JSON while Settings is open in the built app

## 3. General pane and the key recorder

- [x] 3.1 Build `KeyRecorder` (design decision 5): click to record, a local key monitor while recording, Escape cancels, losing focus stops, a refusal shown briefly under it; the rules are a parameter: quick-look (bare Space, or any supported key with a modifier) and command (modifier required); verify the rule functions with tests (bare Space accepted, bare J refused, Option-J accepted for quick-look; bare J refused for commands)
- [x] 3.2 Pause the quick-look hotkey monitor while any recorder records, and resume it afterwards; verify in the built app that recording Option-Space while it's the current key records it instead of opening the panel
- [x] 3.3 Build the General pane: the quick-look key recorder and Off, saving through `ConfigStore.save`; verify in the built app that Option-Space opens the panel from any app and Off sends Space to Finder's Quick Look, and that `config.json` holds the new value

## 4. Plugin panes

- [x] 4.1 Build `PluginPane` with the on/off switch, saving `enabled`; verify in the built app that turning Image off sends Space on an image to Finder's Quick Look
- [x] 4.2 Build `ExtensionTokens`: tokens with remove, a text field that adds on Return, an inline message for entries that aren't extensions, Reset, and a confirmation naming the owner with Move and Cancel when the extension belongs to another plugin; verify with the step 1.4 helpers' tests and in the built app by moving `md` to Plain Text and back with Reset on both panes
- [x] 4.3 Add a row per command with a `KeyRecorder` (command rules) and reset to default; add the pure clash check against the same plugin's other commands and the main menu outside Commands (read from `NSApp.mainMenu`); verify with tests that Command-S is refused naming Save and that a key free in the menu but used by another command of the plugin is refused naming that command, and in the built app that a new Highlight Selection shortcut works in an open PDF

## 5. Permissions pane

- [x] 5.1 Add `Permissions`: Accessibility via `AXIsProcessTrusted`, Finder via `AEDeterminePermissionToAutomateTarget` off the main thread (granted, not granted, not asked yet; keep the last status on `procNotFound`), and Open at Login via `SMAppService`; verify with tests for the mapping from the Apple Event result codes to the three statuses
- [x] 5.2 Build the Permissions pane: Accessibility and Finder rows with what each is for, status, and Grant Access (System Settings links; the system request for Finder when not asked yet), refreshed every second while visible; an Open at Login switch with the needs-approval note and Login Items button, and an alert on failure; verify in the built app that granting Accessibility updates the row within two seconds
- [x] 5.3 Remove Open at Login from the app menu (it stays in the menu bar menu); verify with a menu test that the Peeker menu has Settings… and no Open at Login
- [ ] 5.4 Add `DefaultApps` (design decision 8): per extension the system type (none for `noExtension` and dynamic types), the current default app compared by bundle identifier, per-plugin all/some/none with counts, and Make Default per plugin and per extension; verify the classification with tests (all, some with a count, none, and extensions that can't be set), and check on macOS 26 in the built app whether `setDefaultApplication` asks for confirmation, recording the result in design.md
- [ ] 5.5 Show the default-app rows in the Permissions pane, expanding to per-extension rows with the current app's name when Peeker is the default for only some; verify in the built app that Make Default on PDF makes a double-clicked PDF open in Peeker

## 6. Missing-permission dots

- [ ] 6.1 Add `AccessibilityStatus`, owned by `AppDelegate`, replacing the startup-only trust timer: while the quick-look key is on it polls every 2 s, starts the event tap once trust appears, and publishes whether Accessibility is missing; verify that the existing behavior (Space starts working within a few seconds of granting, without a relaunch) still holds in the built app
- [x] 6.2 Change `MenuBarItem.show` to take problems and the missing-Accessibility state: the dot for either, and the line "Space in Finder needs Accessibility…" opening the Permissions pane, while the problems line opens Config File; verify with `MenuBarItemTests` for each combination of the two
- [ ] 6.3 Show a red dot on the Permissions sidebar row from the same status; verify in the built app before granting Accessibility

## 7. Run-peeker checks for Settings

- [ ] 7.1 Extend `.claude/skills/run-peeker/record-flows.sh` (and `drive.swift` if needed) with a Settings flow: open Settings from the menu bar icon, turn a plugin off and on, add and move an extension, and check `config.json` after each change, with screenshots; update `SKILL.md`; verify the script's checks pass on an unlocked screen

## 8. Integration

- [ ] 8.1 Run `scripts/build.sh test` (no new warnings), `scripts/check-plugin-imports.sh`, `.claude/skills/run-peeker/e2e-routing.sh` and `openspec validate --all --strict`; then run `record-flows.sh` on an unlocked screen and confirm every check passes

## Workflow follow-up

- Archive `extension-lists` before this change, since this change's plugin panes edit the extension lists it adds.
- After archiving, update `openspec/config.yaml`'s roadmap (Settings done, PDF fill, sign and annotate next).
