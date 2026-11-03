# Design

## Context

See proposal.md for why. Markdown and Plain Text set colors directly: `TextDocument` leaves the text view's defaults (system text and background), `MarkdownEditor` applies `labelColor`, `tertiaryLabelColor`, `linkColor`, `secondaryLabelColor` and `quaternarySystemFill` in its style pass, and `MarkdownRenderer` (the Peek panel's view and printing) uses the same system colors. Plugins may import only PeekerKit, so they can't read `Config`. The host applies config changes in `AppDelegate.configChanged`. `TextPrinting` prints in the light appearance on white.

## Goals / Non-Goals

**Goals:**
- One theme value the host sets and every text view reads, with light and dark handled by AppKit rather than by each view.
- Recoloring an open view without touching its text, undo history, selection or scroll position.

**Non-Goals:**
- Syntax highlighting and the token colors it will add.
- Custom, imported or per-plugin themes; fonts.
- Theming the sidebar, toolbar, notes or the Peek panel's chrome.

## Decisions

### `TextTheme` in PeekerKit, as dynamic colors

A public `TextTheme` struct holds an id (the config name), a display name, and nine roles: background, text, heading, marker (dimmed Markdown syntax), link, code background, selection, cursor and find match. Each role is an `NSColor(name:dynamicProvider:)` built from a light and a dark hex value, so AppKit picks the variant from the view's effective appearance, and a system appearance switch redraws without any code of ours. `System` uses the system's semantic colors (`textBackgroundColor`, `labelColor`, `tertiaryLabelColor`, `linkColor`, `quaternarySystemFill`, `selectedTextBackgroundColor`, `textInsertionPointColor`, `findHighlightColor`), which are dynamic already.

`TextTheme.all` lists the eight in pop-up order, with the group each belongs to for the separators. `TextTheme.current` (main actor) is set by the host; setting it posts `TextTheme.didChange`. Text views read `current` when they're made and observe the notification.

Alternative: pass the theme through `OpenContext` and a new contract method. Rejected: the theme changes while documents are open, so a method call into every document is the same mechanism with more plumbing, and the Peek panel's documents would need it too. Alternative: plain colors and a switch on the effective appearance in each view. Rejected: every view would observe appearance changes itself.

### Host: config, schema, Settings

`Config.textTheme` is a string, default `"system"`. The reader takes a top-level `textTheme`; a value that isn't a string or isn't in `TextTheme.all` adds a problem naming the eight and leaves the default. Rendering writes it; the schema gives it an `enum` of the ids. `AppDelegate` sets `TextTheme.current` before the first window opens and again in `configChanged` (only when it differs, so a save of another setting doesn't recolor everything). `GeneralPane` gets a `Picker` in its own section, listing `TextTheme.all` with `Divider`s between groups, saving through `model.save`.

### Views recolor from the theme

- `TextDocument`: sets `backgroundColor`, `textColor`, `insertionPointColor` and `selectedTextAttributes` from the theme, and again on `didChange`.
- `MarkdownEditor`: the same text view properties; its style pass takes heading, marker, link, quote (marker color), task box and code background from the theme. On `didChange` it runs the style pass, which never touches undo or the text.
- `MarkdownDocument` (Peek panel): the text view's background, and `MarkdownRenderer.render` gains a theme parameter for its colors. On `didChange` it renders the blocks it already has again, keeping the scroll position.
- Printing renders with `TextTheme.system` (the Markdown printout) or keeps today's black text (Plain Text), and `TextPrinting` already prints in the light appearance on white, so dynamic system colors print dark.

### Find highlights through a text finder of our own

`NSTextView`'s built-in find bar draws match highlights in a system color and exposes no way to change it. Each text view that uses the find bar gets its own `NSTextFinder` (client: the text view, container: its scroll view, incremental searching on, content dimming off) instead of `usesFindBar`, and the text view subclass forwards `performTextFinderAction(_:)` to it. Its `incrementalMatchRanges` (key-value observable) are drawn as temporary background attributes in the theme's find-match color on the layout manager, which doesn't touch the text storage or undo. If this proves unreliable in testing, the find highlights stay system-colored and the maintainer is told, as agreed.

## Risks / Trade-offs

- [Replacing `usesFindBar` with an explicit `NSTextFinder` could change find behavior (Cmd+G, Use Selection for Find, the bar's placement below the toolbar)] → the existing find tests and the viewer flow's find steps must still pass; if they don't, fall back to the system find bar and report.
- [Temporary attributes on a 90 MB log with thousands of matches] → the finder reports matches incrementally; only the ranges it reports are colored, and they're cleared when the bar closes.
- [Dark themes with low-contrast markers] → marker colors were checked in the mock; High Contrast keeps markers at 7:1.
- [Restyling the whole Markdown storage on a theme change] → the same pass runs after every typing pause already.

## Migration Plan

None: a missing `textTheme` means System, today's look.
