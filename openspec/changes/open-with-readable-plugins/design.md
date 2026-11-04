# Design

## Context

`PluginCatalog.openWithChoices(for:)` returns the owner, then every other enabled plugin. `DocumentWindowController` calls it afresh in the toolbar popup, in the popup's action, in File > Open With's fill and action, and on every menu check. The toolbar is rebuilt each time a document shows (first open, Open With, a followed link), so the toolbar's item list can depend on the file. Unit tests pass made-up paths such as `/tmp/notes.md` that don't exist on disk.

## Goals / Non-Goals

**Goals:**
- Decide "can read" without reading the file, so neither opening nor menu checks get slower.
- Keep the plugin contract the only place a plugin says what it reads.

**Non-Goals:**
- Sniffing file contents beyond what macOS already does for its type.
- Changing routing: extension lists still pick the owner.
- Open With in the Peek panel, which has none.

## Decisions

**The contract gains `static var readableTypes: [UTType]`, defaulting to none.** With the default a plugin is still listed for the files it owns, only never as an extra choice, which is a harmless way to forget it; requiring it instead would mean touching the 22 stub plugins in the tests for no behavior. `PluginEntry` copies it like `defaultExtensions`. Values: Plain Text `[.text]`; Markdown `[UTType("net.daringfireball.markdown")]`; PDF `[.pdf]`; Image the types from `CGImageSourceCopyTypeIdentifiers()`, built once in a `static let`. Considered a `canRead(url)` function per plugin: more flexible, but it invites file reads in a menu check, and types cover every case decided in the interview.

**The file's type comes from its `contentTypeKey` resource value, after resolving symlinks, falling back to `UTType(filenameExtension:)`.** The resource value is what macOS shows in Finder and types extensionless files by contents (an extensionless README reads as plain text, a binary as `public.data`). The fallback covers a path that doesn't exist, which the unit tests rely on. A plugin is listed when the type conforms to any of its readable types.

**`openWithChoices(for:showing:)` takes the current plugin's id.** Order: the owner, then the enabled plugins in catalog order that read the type or are the current one. A disabled plugin stays out even when it's the current one, as "Users can turn plugins off" requires.

**The window keeps the list it showed.** `DocumentWindowController` stores the choices when a document shows and when it takes a new config, and the popup, File > Open With and their actions all read that list. This keeps menu checks free of file lookups and keeps the indices used as tags matching the list that was shown, which today could drift if the config changed between filling the menu and choosing from it.

**One choice hides the toolbar item and greys out the menu.** `toolbarDefaultItemIdentifiers` leaves out `openWith` when the list has fewer than two plugins; the File > Open With item validates to false then. The menu item stays because Mac menus disable items rather than remove them.

## Risks / Trade-offs

- [macOS types some extensions oddly: `.ts` is a video, `.env` and `.mdown` have no type] → the owner is always listed, so these files still open and switch where their owner allows; only the extra choices are missing.
- [The toolbar shifts between windows that do and don't show Open With] → accepted in the interview; greying it out instead would leave a control that never does anything on most image and PDF windows.
- [A resource lookup on the main thread when a document shows] → it's a metadata read next to the one `listEntry` already does for the same file; CI's bench-ab run covers the open path.
