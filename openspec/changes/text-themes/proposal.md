# Proposal

## Why

Markdown and Plain Text always use the system's colors. The maintainer wants themes for them (decided 2026-11-03): a few of Peeker's own palettes, a couple of slick ones in the spirit of note apps such as Bear, and the coder palettes Catppuccin and Tokyo Night, while keeping one simple setting.

## What Changes

- A new Text theme setting with eight built-in themes: System (today's look, the default), Paper, Slate, Graphite, Ink, Catppuccin, Tokyo Night and High Contrast. Each has a light and a dark variant and follows the system appearance.
- One theme covers Markdown and Plain Text, in windows and in the Peek panel. It colors the text area's background and body text, Markdown's headings, dimmed markers, links and code background, the selection, the cursor and find-match highlights. The sidebar, toolbar and notes keep the system look; fonts don't change.
- Settings > General gets a Text theme pop-up (System first, then Paper, Slate, Graphite and Ink, then Catppuccin and Tokyo Night, then High Contrast). The config gains a top-level `textTheme` key; an unknown name is reported as a config problem and System is used.
- Changing the theme recolors open windows and the Peek panel at once.
- Printing ignores the theme and stays dark on white.
- Catppuccin (Latte and Mocha) and Tokyo Night (Light and Night, from the MIT VS Code theme) use their official colors; a new `THIRD_PARTY_NOTICES.md` carries their MIT notices.
- Syntax highlighting, custom themes and per-plugin themes are left out; highlighting comes as its own change and adds its colors to the themes then.

## Capabilities

### New Capabilities

- `text-themes`: the built-in themes, what they color, light and dark, live switching, the Peek panel and printing.

### Modified Capabilities

- `routing-and-config`: the config's `textTheme` key and its schema.
- `settings`: the Text theme pop-up in General.

The `markdown` and `text` specs need no change: what a theme colors, in both plugins, is specified once in `text-themes`, and their print requirements already print dark on white.

## Impact

- `Sources/PeekerKit`: a public `TextTheme` (palettes as dynamic colors, the ordered list, the current theme and a change notification), so plugins can read the theme without knowing the config.
- Host: `Config` reads, renders and checks `textTheme`; the schema lists the names; `AppDelegate` sets the current theme on launch and on config changes; `GeneralPane` adds the pop-up.
- Plugins: `TextDocument`, `MarkdownEditor`, `MarkdownDocument` and `MarkdownRenderer` take their colors from the theme and recolor on a change; a text finder of their own lets the find highlights take the theme's color.
- Tests, a screen flow step set, README, CHANGELOG and the new notices file.
