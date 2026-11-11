# Design

## Decisions

- **The key monitor catches the keys.** The panel never takes the keyboard from Finder, so Cmd+O would reach Finder's Open. `HotkeyMonitor.decide` already swallows Escape and follows the arrows while the panel is up; it gets two more decisions, `.open` and `.showInFinder`, for keys matching the configured ones while the panel is visible, Finder is in front and its button menu is closed. That is the same condition Escape uses, so the keys never reach past Finder; a panel opened from another app with a modifier key keeps that app's Cmd+O and Cmd+R. Only the key-down is acted on; its key-up is swallowed as for Space.
- **A rule of their own.** `Shortcut.Rules.panelAction` accepts only keys with Command, Option or Control. Bare keys would break Finder's type-to-select, and Page Up and Page Down belong to Finder's list. The config reader and the recorders both check it, and both refuse the Peek panel key or the other action's key.
- **Config shape.** `Config.peekPanelOpenKey` and `Config.peekPanelShowInFinderKey`, `Shortcut?`, defaulting to Cmd+O and Cmd+R; nil is `"off"`. Rendering always writes them, as it writes `peekPanel.key`. The schema describes them as strings.
- **Captions reuse the Editor's.** The folder button's image comes from `ToolbarImage.make(symbol:name:key:showsKey:)`, which already draws a key beside an icon. The main button's title gets the key's `displayText` after two spaces. Both follow `Config.showShortcuts`, and the title bar accessory is laid out again when they change, as it is for "Open in TextEdit". Tooltips use `Shortcut.tooltip`.
- **The panel gets them from `AppDelegate`** with `openWith` each time a file is shown, and the monitor reads them from the config through a closure, so a saved config applies at the next key.

## Risks / Trade-offs

- [Cmd+R in Finder is Show Original for aliases] → Taken only while the panel is up; the panel's file is already selected.
- [Captions widen the title bar's buttons] → About 30 points; the backlog already has the long-title overlap.
