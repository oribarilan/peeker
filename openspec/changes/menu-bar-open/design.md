# Design

## Context

`MenuBarItem.menu(target:lines:)` builds the menu's commands from a list of titles and selectors. `AppDelegate.showOpenPanel(_:)` runs an `NSOpenPanel` modally and opens each chosen file. With no Editor or Settings window, `Presence` keeps the app an accessory (no Dock icon), and macOS doesn't activate an accessory app on `NSApp.activate()`: in a test with real clicks the panel came up behind Finder's focus.

## Decisions

**Open… goes first in the menu, as in File.** It's the command people reach for when no window is open.

**`showOpenPanel` makes the app regular and activates it before the panel, and calls `updatePresence()` when it returns.** That's what opening Settings does through `Presence`. `updatePresence()` then applies the usual rule, accessory again after Cancel and regular with the new window. Considered teaching `Presence.policy` about the panel: it's modal and lives inside one function, so the state would only exist during `runModal`.

## Risks / Trade-offs

- [The Dock icon appears for the panel's lifetime] → it's what macOS needs to give the panel the keyboard, and it matches the Settings window.
