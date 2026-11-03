# Design

## Context

See proposal.md for why. `TextTheme` (PeekerKit) holds dynamic light/dark colors, and `TextTheme.current` is set by `AppDelegate` from the config; text views observe `TextTheme.didChange` and recolor. Each dynamic color resolves against the effective appearance of the view drawing it, which today is always the app's, and the app always follows the Mac. Settings is a SwiftUI sidebar of panes (`SettingsPane`), each control saving through `SettingsModel.save`, which rewrites `config.json`. The Text theme pop-up sits in `GeneralPane`.

## Goals / Non-Goals

**Goals:**
- See every theme before choosing it.
- Choose the app's look and the text's look separately, with defaults that behave as today.

**Non-Goals:**
- Custom themes, per-plugin themes, or a theme switcher in the View menu.
- Theming the toolbar, sidebar or the Peek panel's frame.
- The benchmark run, which the maintainer postponed.

## Decisions

### The app's appearance is `NSApp.appearance`

`AppDelegate` sets `NSApp.appearance` to `nil` (System), `.aqua` (Light) or `.darkAqua` (Dark) at launch, before the first window, and again when the config changes. Every window, Settings and the Peek panel included, follows it with no other code.

### The text's appearance is the text area's own appearance

PeekerKit gains `TextTheme.appearance: NSAppearance?`, set by the host next to `current`: `nil` for Match App, otherwise `.aqua` or `.darkAqua`. Changing it posts the same `didChange`. On a change, each text document sets its scroll view's `appearance` to it, so the text view, its background and every dynamic theme color inside resolve in that look, while the window's toolbar, sidebar and notes keep the app's. The find bar lives in the scroll view and so follows the text look, which matches the page it searches.

Alternative: resolve the theme's colors to fixed light or dark values when the text appearance is forced. Rejected: every view would rebuild its colors, and the system theme's semantic colors would lose their own adjustments, such as increased contrast.

### One reader for the three named choices

`textTheme`, `appearance` and `textAppearance` are each a string from a fixed list, with a problem naming the list otherwise. That's the third copy, so the reader takes one helper: the key, the allowed values and where to store the result. Rendering writes all three; the schema gives each an `enum` and a default.

### The Appearance pane and its cards

`SettingsPane` gains `.appearance` (storage key `appearance`) between General and the plugins, with the `paintpalette` symbol. `AppearancePane` is a grouped form: two segmented pickers, then a `LazyVGrid` of four fixed columns. A card is a button drawing the sample with SwiftUI `Text` runs: `#` in the marker color and `Title` in the heading color, a line with a link, a code span on the code background, and `- [x] Done`. Its colors are resolved to fixed sRGB values for the chosen variant (`NSAppearance.performAsCurrentDrawingAppearance`), so the card doesn't depend on how SwiftUI resolves a dynamic `NSColor`. The variant is the text appearance, or for Match App the pane's own color scheme. The chosen card gets an accent ring and the selected accessibility trait; each card's label is the theme's name. `GeneralPane` loses its theme section.

### Find highlights

The built-in find bar draws matches in the system yellow and dims the rest. A PeekerKit `ThemedFindTextView` (the base of the three text views) runs its own `NSTextFinder` with `incrementalSearchingShouldDimContentView` off, which Apple documents as the way to draw matches yourself, watches `incrementalMatchRanges`, and marks the matches within a screen of the visible text with temporary attributes (TextKit 1) or rendering attributes (TextKit 2), marking again on scroll and theme changes. Find options and Replace come from the same finder.

Being the finder's client relies on NSTextView methods Apple doesn't document, and on `usesFindBar` staying on, without which NSTextView tells the finder to show nothing. So on first use the view checks that its finder will show the bar; if not, it drops it for good and lets the built-in find bar run. The worst a future macOS can do is take the colors away. The current match keeps the system's indicator, which takes no color.

## Risks / Trade-offs

- [A forced text appearance gives the scroll view's scroller and find bar that look too] → They sit on the page, so matching it reads naturally; the toolbar keeps the app's look.
- [Eight cards with styled text cost a little to draw on opening the pane] → They're eight small views drawn once; Settings isn't on the open path.
