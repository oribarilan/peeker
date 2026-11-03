# Proposal

## Why

The Text theme pop-up lists eight names, so there's no way to know what a theme looks like without picking it and opening a file. Peeker also always follows the system's light or dark appearance, for the app and for text alike, while some people want a dark app with a light page to write on, or the reverse. The maintainer chose preview cards and two appearance settings in their own Settings pane (decided 2026-11-03).

## What Changes

- Settings gets an Appearance pane, listed right after General. The Text theme pop-up leaves General.
- Appearance: System, Light or Dark for the whole app, Settings included. System, the default, follows the Mac.
- Text appearance: Match App, Light or Dark, which picks the light or dark look of the text theme. Match App, the default, uses the app's appearance. It applies to the text area of Markdown and text files, in windows and the Peek panel; toolbars, sidebars and the panel's frame follow the app.
- Text theme: a grid of eight cards in four columns and two rows, each showing a few lines of styled Markdown (a heading with its dimmed `#`, a link, a code span and a task) in that theme's colors, drawn in the look Text appearance picks. The name sits under each card and the chosen one is marked. Clicking a card applies it at once.
- The config gains top-level `appearance` (`system`, `light`, `dark`) and `textAppearance` (`app`, `light`, `dark`). An unknown value is a config problem and the default is used. The schema lists the values.
- Find matches near the visible text take the theme's find color, without dimming the rest; the current match keeps the system's find indicator. The text views run their own text finder for this, and fall back to the system find bar if it ever stops working.
- Printing still ignores theme and appearance and prints dark on white.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `settings`: the Appearance pane in the sidebar, its three controls; the pop-up in General goes.
- `routing-and-config`: the `appearance` and `textAppearance` keys, their schema and problems.
- `text-themes`: a theme's variant follows the text appearance instead of always the system.

## Impact

- `Sources/PeekerKit/TextTheme.swift`: a forced appearance for text alongside the current theme, posting the same change notification.
- Host: `Config` reads, renders and checks the two keys; the schema lists them; `AppDelegate` sets the app's appearance and the text appearance at launch and on config changes; a new `AppearancePane` with the cards; `SettingsPane` gains `.appearance`; `GeneralPane` loses the pop-up.
- Plugins: `TextDocument`, `MarkdownEditor` and `MarkdownDocument` give their scroll view the text appearance.
- Tests, the theme screen flow, README, CHANGELOG, and the version goes to `0.4.0-dev`.
