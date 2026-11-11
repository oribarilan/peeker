# Proposal

## Why

The Editor's tools have keys that show on their buttons and can be changed in Settings; the Peek panel's two buttons, Open in Peeker and the folder button that shows the file in Finder, have none, so they need the mouse.

## What Changes

- While the Peek panel is up, Cmd+O does what its main button does (opens the file in Peeker, or in the default app for its type), and Cmd+R shows the file in Finder and closes the panel. Both keys are caught only while the panel shows; otherwise they reach the app in front as before.
- Each button shows its key as a caption, as the Editor's toolbar buttons do: "Open in Peeker ⌘O", and ⌘R beside the folder icon. The captions follow the Show shortcuts setting in Appearance. Tooltips name the key too.
- Settings > General gets an Open key and a Show in Finder key under the Peek panel key: a recorder, a clear button and Reset, as plugin tools have. A key needs Command, Option or Control, since Finder takes bare keys for typing a file's name. A key can't be the Peek panel key or the other action's key.
- The config takes them as `peekPanel.openKey` and `peekPanel.showInFinderKey`, written like other keys (`"cmd+o"`) or `"off"`.
- The arrow's menu and the Editor's File > Show in Finder keep no key.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `peek-panel`: the two keys and their captions.
- `settings`: the two recorders in General.
- `routing-and-config`: the two config keys.

## Impact

- Changed: `Sources/Host/App/Shortcut.swift` (a rule for panel keys), `Config.swift`, `ConfigRendering.swift`, `ConfigSchema.swift`, `Sources/Host/PeekPanel/HotkeyMonitor.swift` (decides on the two keys), `PeekPanel.swift` (captions), `Sources/Host/App/AppDelegate.swift` (passes the keys on), `Sources/Host/Settings/GeneralPane.swift`.
- Tests next to `Tests/HotkeyDecisionTests.swift`, `Tests/ConfigTests.swift`, `Tests/ConfigSchemaTests.swift`, `Tests/PeekPanelTests.swift`; a step in the main screen flow; a CHANGELOG line.
- No work on the Space path beyond comparing two more keys in the key monitor.
