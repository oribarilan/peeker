# Design

## Decisions

- **`NSWorkspace.activateFileViewerSelecting([url])`** does the work everywhere. It opens or reuses a Finder window, selects the file and brings Finder forward. It needs no permission; the Finder automation Peeker asks for is only for reading the selection. Both the window controller and the panel take it as an injected `revealInFinder` closure so tests don't open Finder.
- **The toolbar button is a host item** next to the sidebar button and Back and Forward (`navigationItem`), with the symbol `folder` and no key. It goes after Open With and before the flexible space, in every window, also while a file loads or fails to open.
- **The panel's folder button** sits in the same title-bar accessory as Open in Peeker, to its left, as a small push button with the `folder` symbol and a tooltip. One layout function places both, since Open in Peeker's width changes with the default app's name.
- **The panel's menu item** is a new `OpenWithItem.showInFinder`, in a group of its own after Other…, so the menu's order stays in the pure `PeekOpenWithMenu` and its tests.
- **No tab menu item.** The native tab bar's menu has no public API; the only working approach found (watching every menu open and matching AppKit's private item set, as Ghostty does) breaks silently with an OS update. The maintainer chose to skip it.

## Risks / Trade-offs

- [One more toolbar button in every window] → It's in the host group, and the toolbar's overflow menu takes it on narrow windows.
- [The folder button could crowd the panel's title for long names] → The title truncates; checked on screen with a long file name.
