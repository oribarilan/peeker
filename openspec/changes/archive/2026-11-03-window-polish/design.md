# Design

## Context

See proposal.md for why. The toolbar is built in `DocumentWindowController.toolbarDefaultItemIdentifiers`: `[.toggleSidebar]` when the document has a sidebar, then Open With, a flexible space and the tools. The window's content view controller is the document's `DocumentViewController`, an `NSSplitViewController` whose sidebar item can arrive after the content. With the unified toolbar style and no tracking separator, the title takes the leading side and the items, sidebar button included, follow it on the right. The outline is the Markdown plugin's `OutlineList`, a source-list table built on each sidebar rebuild; a click calls back with the heading's 1-based line, and `MarkdownEditor.jump(toLine:)` moves the cursor.

## Goals / Non-Goals

**Goals:**
- The toolbar laid out as Finder's: sidebar button over the sidebar.
- An outline that answers the pointer and shows where the cursor is.

**Non-Goals:**
- A current section in the Peek panel, which has no cursor.
- Collapsing outline sections, or other outline features.

## Decisions

### A tracking separator after the sidebar button

The default items become `[.toggleSidebar, .sidebarTrackingSeparator]` before Open With when the document has a sidebar. AppKit ties the separator to the window's split view controller, so the sidebar button rides over the sidebar and the title and the rest follow the divider. If the separator can't find the sidebar because it arrives after the toolbar is built, the toolbar is rebuilt when the sidebar is added, as it already is when tools change.

### Hover as a row view state

`OutlineList` adds a tracking area over the table and, on mouse moved, entered and exited, records the row under the pointer; each row view draws a faint rounded fill (`quaternarySystemFill`) while it's the hovered one. Hover needs no selection change, so it never moves the cursor.

### The current section is the table's selection

The marked heading uses the table's own selection, so it gets the source list's selected look, focus handling and VoiceOver's "selected". `OutlineList.mark(_ index: Int?)` selects that row (or none) without calling back, and scrolls it into view. `MarkdownEditor` keeps the UTF-16 offset of each heading's line start, computed with the line-start table whenever a style pass lands, and on every selection change finds the last heading at or before the cursor (binary search) and marks it. Between a keystroke and the next style pass the offsets can be a few characters off; the mark settles when the outline refreshes, the same pause the outline already has.

Alternative: count lines up to the cursor on each selection change. Rejected: linear in the file's size on every arrow key.

### Wrap Lines symbol

`text.alignleft`, chosen by the maintainer from rendered candidates. It's the tool spec's symbol, so the toolbar and any other place that shows it follow.

## Risks / Trade-offs

- [The separator only works while the window's content controller is the split view controller] → It is for every Editor document; the toolbar is rebuilt on each tab switch anyway.
- [A mark that lags typing by the refresh pause] → Short and self-correcting; the outline itself lags the same way.
