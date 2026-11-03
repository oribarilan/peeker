# Proposal

## Why

Three rough edges the maintainer found in the 0.2 build (2026-11-03): the Wrap Lines button's ↵ arrow reads as Back; the sidebar button sits on the right next to Open With instead of over the sidebar as in Finder, though the spec already puts it at the toolbar's leading end; and the Markdown outline gives no feedback on hover and doesn't show where the cursor is.

## What Changes

- Wrap Lines uses the `text.alignleft` symbol (ragged lines of text), in the toolbar and wherever the tool's symbol shows.
- The sidebar button sits over the sidebar, beside the window buttons, with the title, Open With and the tools past the sidebar, as in Finder. Hiding the sidebar keeps the button by the window buttons.
- Outline rows highlight while the pointer is over them.
- The outline marks the heading of the section the cursor is in, and keeps it marked as the cursor moves, by typing, clicking or the keyboard. Clicking a heading jumps there as before and marks it.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `plugin-host`: where the sidebar button sits, made concrete with a scenario.
- `markdown`: the outline's hover highlight and current section.

## Impact

- `Plugins/text/TextPlugin.swift`: the Wrap Lines symbol.
- `Sources/Host/Documents/DocumentWindowController.swift`: a sidebar tracking separator after the sidebar button.
- `Plugins/markdown/OutlineList.swift`: hover highlight and a marked row; `MarkdownEditor` tells it the cursor's section when the selection changes.
- Tests, the markdown-edit and viewer screen flows, CHANGELOG, and the version goes to `0.5.0-dev` (the current section is a feature).
