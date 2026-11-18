# Proposal

## Why

Settings and alerts call PDF, Markdown, Image and the rest "plugins", a word users don't think in. And Make Default sits in General, far from the pane where the same format's extensions are set, so someone making Peeker their PDF app looks in the wrong place.

## What Changes

- Settings and alerts say "format" instead of "plugin". The sidebar's section is titled Formats.
- Each format's pane gets a Default App section after Extensions: "Opens in <app>" with Make Default, expanding to one row per extension when the extensions open in different apps. It's hidden while the format is off and stays usable while the config is locked.
- General loses its Default app list.
- The toggle reads "Open <Name> files in Peeker". Its footer reads "When this is off, Peeker opens no <Name> files and no other format takes them. Space shows Finder's Quick Look instead."
- The alert for a file no enabled format opens, and the recovery messages for such files, say "Peeker doesn't open …" and point to a format in Settings.
- The config file's Open in Editor button becomes Open in Text Editor. The Appearance footer says "format panes".
- Config problem messages and `schema.json` descriptions say "format". The `plugins` key and paths such as `plugins.pdf` stay as they are; `docs/config.md` says each entry under `plugins` is a format in Settings.
- "Plugin" stays in the code, AGENTS.md, specs and architecture docs.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `settings`: the sidebar section's title, the format pane's toggle text and new Default App section, General without the Default app list, Open in Text Editor, and what stays usable while the config is locked.
- `routing-and-config`: the wording of the alert for a file no enabled format opens.
- `documents`: the wording of the recovery messages for files no enabled format opens.

## Impact

- Changed: `Sources/Host/Settings/PluginPane.swift`, `DefaultAppSection.swift` (becomes the format pane's section), `GeneralPane.swift`, `SettingsWindowController.swift`, `ConfigFilePane.swift`, `AppearancePane.swift`; `Sources/Host/App/AppDelegate.swift`, `Config.swift`, `ConfigSchema.swift`; `Sources/Host/Documents/RecoveryRestore.swift`.
- Tests in `Tests/SettingsLogicTests.swift` and the suites that check config problem and recovery text; the Settings steps in `scripts/screen/record-flows.sh`.
- `docs/config.md`, a CHANGELOG line, and a minor version bump.
- Nothing on the open path. The config format is unchanged, so existing configs keep working.
