# Design

## Context

See proposal.md for why. Today:

- `MarkdownEditor` (the Editor's styled source) sends a Cmd-clicked link's destination string to `openLink`, which defaults to `LinkOpener.open`. `MarkdownDocument` (the Peek panel's rendered view) gets a `URL` from `textView(_:clickedOnLink:)`, built by `MarkdownRenderer` with `URL(string:)` and no base. `LinkOpener.open` returns early when the URL has no scheme.
- Both views already jump to headings from the outline: `MarkdownEditor.jump(toLine:)` places the cursor and scrolls; `MarkdownDocument.scroll(toLine:)` scrolls. Their outlines come from different parses (`MarkdownStyler` for the Editor, `MarkdownTree` for the panel) but carry the same `OutlineItem(title:level:line:)`.
- `DocumentWindowController` is one Editor window, created for one `url` (a `let`), and `AppDelegate` finds an open file's window by that `url`. Open With already replaces a tab's document in place: `show(with:)` closes the current `DocumentViewController`, builds a new one, rebuilds the toolbar and loads. `resolveUnsavedEdits()` is the Save / Don't Save / Cancel sheet closing and Open With use.
- `DocumentViewController` owns one file's document: loading, saving, watching, the recovery journal (keyed by its own `url`). It is used by both Editor windows and the Peek panel.
- The menu bar is seven fixed menus built by `MainMenu.make`; `DocumentWindowController.swift` is 456 lines.

## Goals / Non-Goals

**Goals:**
- The host stays format-agnostic: it routes links to files and keeps history; it never parses Markdown or knows what a heading is.
- One routing path for every link to a local file, from either view, so the rules in the specs live in one place.
- Opening a file stays as fast: nothing added before first paint.

**Non-Goals:**
- Long-press history menus on Back and Forward, history across tabs, or history saved to disk.
- Following links from Plain Text, PDF or images (the contract allows it later).
- Resolving `/path` links against a repository root.

## Decisions

### The contract: a `LinkFollowing` protocol in PeekerKit

```swift
@MainActor public protocol LinkFollowing: PluginDocument {
    /// Set by the host: call it with a link to a local file, resolved to an absolute file URL, its fragment naming a
    /// place in it. Links to this document's own file come here too.
    var onFollowLink: ((URL) -> Void)? { get set }
    /// Where the view is now, opaque to the host, handed back to `restore(_:)` when Back or Forward returns here.
    var position: any Sendable { get }
    func restore(_ position: any Sendable)
    /// Goes to the place `name` names; returns its title for the history trail, or nil when there's no such place.
    func go(to name: String) async -> String?
}
```

A separate protocol rather than more defaulted members on `PluginDocument`: the host needs to know whether a document takes part (to show Back and Forward), and `document as? LinkFollowing` answers that without a flag. The four members belong together and no other plugin needs them yet.

The plugin resolves the link (it knows its file and its link syntax) and hands the host an absolute file URL; the host never sees relative paths. Links with a scheme stay with the plugin's `LinkOpener` as today.

`position` is opaque so each plugin keeps whatever it needs (Markdown: the character at the top of the view and the selection; a PDF later: page and point). History isn't saved, so it never needs encoding. `go(to:)` is `async` because the Editor parses a file over 64 KB from its start first: a heading further down isn't in the outline until the full parse lands, and `go(to:)` waits for it rather than failing.

Alternative: history inside the plugin. Rejected: switching a tab's file is host work (tabs, routing, the save prompt, recovery), and a plugin can't reach another file's document.

### History lives in the window controller

Each `DocumentWindowController` owns a `NavigationHistory`: a plain value type with `entries`, `index`, `push` (drops entries ahead), `back`, `forward`, `move(to:)` and the current entry's `position`. An entry is the file URL, the plugin id it was shown with, the place name (fragment) if any, the place's title if any, and the position recorded when the tab left it. The first entry is the file the tab opened at.

The window controller, not `DocumentViewController`, because the document view controller is replaced on every file switch and may be a failure view; the history has to outlive both. The type is pure so push, back, forward and truncation are unit-tested without windows.

Storing the plugin id means Back returns to a file with the plugin it was shown with, even after Open With. Open With replaces the current entry's plugin and clears its position, since positions only mean something to the plugin that made them.

### One routing function for links

`LinkRoute` (Host/Documents) is a pure function from the link, the tab's current file and plugin, and lookups (does the file exist, which enabled plugin owns it, which window has it open) to one of: go to a place in this document, show the file in this tab, bring another window forward, open in its own tab, ask then open in the default app, or beep. It encodes the order in the specs: missing file, then same file (with a name it's a heading jump; without one, nothing), then already open elsewhere, then owned by the current entry's plugin (same tab, which for Markdown means the Markdown plugin), then any enabled plugin (own tab), then no plugin (ask). Same-file and open-elsewhere checks compare standardized paths with symlinks resolved.

The Editor window and the Peek panel both call it; the panel treats "show in this tab" and "open in its own tab" alike (close the panel, open an Editor window), and has no history.

### Switching the tab's file

`DocumentWindowController.url` becomes `private(set) var`, the tab's current file. A same-tab switch: record the current document's `position` into the current entry, run `resolveUnsavedEdits()` (Cancel ends it, history untouched), push the new entry, set `url`, the window's title and `representedURL`, then go through the existing `show(with:)` path. Once the new document's content is on screen (`onContentShown`), apply the entry: its position when it has one (Back, Forward, crumbs), else `go(to:)` its place name, else nothing (the top). If `go(to:)` returns nil the tab stays at the top and beeps; the entry keeps the file name as its label.

Back, Forward and a crumb click are the same thing: move the history to an index. Within the same file and plugin, only `restore(position)` runs, with no prompt. To another file, the switch above runs, with the target entry's plugin. A target file that is gone, or whose plugin is now turned off, beeps and leaves the index where it was.

An in-document jump: record the position, `await go(to:)`, and push an entry only when it returns a title; otherwise beep.

The recovery journal needs nothing new: each document view controller journals its own file, and the old one is closed only after its edits are saved or dropped. A crash brings back the file with edits in a window of its own, with no history.

A same-tab switch doesn't add the file to Open Recent; opening in its own tab goes through `AppDelegate.openInWindow`, which does, as any open does.

### Peek panel

`DocumentViewController.show` sets `onFollowLink` on documents that adopt the protocol and forwards it through a new `onFollowLink` callback. `AppDelegate` handles it for the panel: a place in the same file calls `go(to:)` (beep on nil); a file to open dismisses the panel, as Open in Peeker does, and calls `openInWindow(url, place:)`, which applies the place after the content shows. A file no plugin opens asks with a sheet on the panel, as `file:` links do today, so Finder keeps the keyboard until the user answers.

### Controls

- **Toolbar:** two items, Back (`chevron.left`) and Forward (`chevron.right`), labeled "Back" and "Forward" with those tooltips, at the leading end after the sidebar button and its tracking separator, before Open With. That's where Finder and Safari put navigation. Shown while the document adopts `LinkFollowing` or the history has more than one entry; greyed out through `validateToolbarItem`, as Safari does, so the toolbar doesn't shift as history grows. On first open they join the toolbar with the tool buttons after first paint; on a same-tab switch the history already has entries, so they're in the rebuilt toolbar from the start and don't flicker.
- **Menu:** a Go menu between View and Tools with Back (Cmd-[) and Forward (Cmd-]), actions on the window controller, validated like Save. Go rather than View because Preview's menu bar is File, Edit, View, Go, Tools, Window, Help with Back and Forward in Go, and Finder does the same; View is for how content looks. The cost is an eighth menu, greyed out outside Markdown windows, which the plugin-host delta records. Cmd-[ and Cmd-] aren't used by any menu or text view binding today, and `Shortcut` can't express `[` or `]`, so no plugin tool or config entry can take them.
- **Trail:** a `HistoryTrail` view in an `NSTitlebarAccessoryViewController` with `layoutAttribute = .bottom`, the system's place for a bar under the toolbar, which survives document swaps. One row of borderless buttons separated by `›`, 11 pt secondary text, the current crumb in the label color and semibold, each with an accessibility label and a tooltip giving file name and heading. Earlier crumbs truncate first. The accessory is hidden while the history has one entry.

`DocumentWindowController.swift` would pass 500 lines, so the history, routing calls, Back/Forward actions and trail wiring go in `DocumentWindowController+Navigation.swift`, widening only the members it needs from `private` to internal.

### Markdown plugin

- `HeadingNames` (one file): `name(for title:)` applies the GitHub rule from the spec (lowercase; keep letters, digits, `-`, `_` and spaces; spaces to hyphens), `names(for outline:)` adds `-1`, `-2` for repeats, and `index(of:in:)` matches a percent-decoded, lowercased name. Explicit HTML anchors aren't collected.
- `LinkOpener.resolve(_:against:)`: a destination without a scheme becomes `URL(string: destination, relativeTo: file)?.absoluteURL` (macOS encodes spaces from `<my notes.md>` destinations; percent escapes decode in the path), query dropped, fragment kept. With a scheme, `LinkOpener.open` as today.
- `MarkdownEditor` and `MarkdownDocument` adopt `LinkFollowing`. The Editor's default `openLink` resolves and calls `onFollowLink` for local links; its `go(to:)` waits for a pending full parse, finds the outline item and reuses `jump(toLine:)`; its position is the character index at the top of the visible area plus the selection, restored by scrolling that character to the top and clamping both to the text's length. The panel view does the same with `scroll(toLine:)` and the top character only.
- An image's destination in the Editor is a link like any other (`MarkdownStyle.links` includes images), so Cmd-clicking `![x](pic.png)` opens the image in its own tab. Drawing images is the `markdown-local-images` change's.

## Risks / Trade-offs

- [Restoring a position after styling changes line heights] → positions are a character index, not a point, so a restyle that changes heading sizes after a large file's first screen still lands on the same text.
- [A bottom titlebar accessory may sit over the sidebar oddly with the tracking separator] → check light and dark screenshots with the sidebar shown and hidden; if it looks wrong, place the trail above the content the way `ReadOnlyNote` places its note, with the window handing the same trail view to each new document view.
- [An eighth menu that's mostly greyed out] → it matches Preview's, and disabled-not-hidden is the system convention.
- [Links can point anywhere on disk with `..` or `/`] → opening a local file in a Peeker plugin only reads it; anything else asks first, as `file:` links do, so one click in a downloaded file can't start an app.
- [The window lookup by `url` now changes over a window's life] → `AppDelegate` already reads `url` each time; a test covers opening a file a tab navigated to.
- [Opening path] → the host adds a protocol check and two toolbar items after first paint; `scripts/bench-ab.sh` confirms no regression.

## Open Questions

- Whether the trail should also show on a narrow window or collapse to just Back and Forward; settle from screenshots during implementation.
