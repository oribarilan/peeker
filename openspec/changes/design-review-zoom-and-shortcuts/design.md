# Design

## Context

Each plugin declares its tools as `ToolSpec`s; the View menu, the Settings panes, `schema.json` and the config's shortcut checks are all built from those lists, so a new tool or a removed default needs no host code. A document runs a tool in `perform(_:)`. Text and the Markdown Editor zoom by font size (`TextDocument.defaultFontSize`, 12; `MarkdownEditor.defaultSize`, 14), the PDF view opens with `autoScales = true`, and the image plugin already has `zoom-fit` and `zoom-actual`. The Markdown Peek panel view (`MarkdownDocument`) has no tools and no zoom.

No fixed menu item uses Cmd+0 or Cmd+9, and no PDF, text or Markdown tool does, so the new defaults clash with nothing and the config won't refuse them.

## Decisions

- **Same ids, titles, symbols and keys as the image plugin.** `zoom-actual` ("Actual Size", `1.magnifyingglass`, `cmd+0`) and, for PDF, `zoom-fit` ("Zoom to Fit", `arrow.up.left.and.down.right.magnifyingglass`, `cmd+9`), both `showsInToolbar: false`, listed after Zoom Out in the image plugin's order. One set of names means one config key per meaning across plugins.
- **PDF uses PDFKit's own scaling.** Actual Size turns `autoScales` off and sets `scaleFactor = 1`; Zoom to Fit sets `autoScales = true`, which is how the view opens and makes it follow window resizes again. No fit math of our own.
- **Text and Markdown Actual Size reuse the size setters** with the default size. Unlike Zoom In at its limit, Actual Size at the default size does nothing and doesn't beep: there is no limit being hit. This is an assumption; Preview doesn't beep there either.
- **No Zoom to Fit for text or Markdown.** Their text reflows to the window, so fitting has no meaning; an item that did the same as Actual Size would only confuse.
- **Wrap Lines: drop the default, no migration.** The Settings window writes every tool's shortcut, defaults included, so anyone who saved from Settings has `"toggle-wrap": {"shortcut": "opt+cmd+w"}` in their config. That reads as their own choice and keeps working. The alternative, dropping that exact value on read as a leftover default, would be special-case code that can't tell a deliberate choice from a leftover, so it's left out unless the maintainer wants it.
- **The pad draws in fixed colors.** The canvas is always white paper, so the signature line and a 1 pt border use black at 25% alpha instead of `separatorColor`, which follows the window's appearance and vanishes on white in dark mode.

## Risks / Trade-offs

- [Users with a Settings-written config keep Opt+Cmd+W on Wrap Lines] → The CHANGELOG line says so and how to clear it (the clear button in Settings > Plain Text).
- [PDF Actual Size depends on PDFKit's notion of 100%, one PDF point per screen point] → This matches Preview's Actual Size; the unit test checks `scaleFactor == 1` and `autoScales == false`.
