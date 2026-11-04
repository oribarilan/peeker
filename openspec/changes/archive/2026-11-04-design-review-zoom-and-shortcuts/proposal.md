# Proposal

## Why

Three findings from the design review (`docs/design-review-2026-11-01.md`) are still open: Wrap Lines takes Opt+Cmd+W, which macOS reserves for closing all windows (M6); Cmd+0 and Cmd+9 zoom images but do nothing in PDFs, text or Markdown (M7); and the signature pad's line disappears in dark mode while its white canvas has no edge in light mode (D2). Each is small, and together they finish the review's shortcut and zoom items.

## What Changes

- Wrap Lines loses its default shortcut. It stays in the View menu and the toolbar, and a shortcut can still be set in Settings or the config. A config that names a shortcut for it keeps that shortcut, including one the Settings window wrote out when it saved the old default. The rest of M6 is already done: Cmd+E Edit Mode is gone (windows are always editable) and Sign has no default shortcut.
- PDFs gain Actual Size (Cmd+0, 100% scale) and Zoom to Fit (Cmd+9, back to fitting the window), in the View menu only, like the image plugin's.
- Plain text gains Actual Size (Cmd+0), which puts the font back to its default size. The Markdown Editor gains Actual Size (Cmd+0), back to its default text size. Neither gets Zoom to Fit: text reflows to the window, so there is nothing to fit.
- The host's rule for zoom shortcuts grows from Cmd+= and Cmd+- to include Cmd+0 for Actual Size and Cmd+9 for Zoom to Fit, wherever a plugin offers them.
- The signature pad draws its signature line and a 1 pt border in fixed grays, so it reads as paper in both appearances.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `text`: Wrap Lines has no default shortcut; Actual Size resets the font size.
- `pdf`: Actual Size and Zoom to Fit; the signature pad looks like paper in either appearance.
- `markdown`: Actual Size in the Markdown Editor.
- `plugin-host`: Cmd+0 and Cmd+9 join Cmd+= and Cmd+- as the shared zoom shortcuts.

## Impact

- Plugins: `Plugins/text/TextPlugin.swift` and `TextDocument.swift`, `Plugins/pdf/PDFPlugin.swift` and `PDFPluginDocument.swift`, `Plugins/markdown/MarkdownPlugin.swift` and `MarkdownEditor.swift`, `Plugins/pdf/SignaturePad.swift`. No host code changes: the View menu, Settings panes and `schema.json` are built from each plugin's tool list.
- Tests: tool lists in `PluginToolsTests`, `ToolbarTests`, `ConfigSchemaTests`, `PDFPluginTests` and `TextPluginTests` change; new tests for each new tool, for Wrap Lines without a default, and for the pad's colors.
- Screen flow: `scripts/screen/viewer-flow.sh` gains an Actual Size check on a PDF.
- Docs: a `CHANGELOG.md` line under Unreleased; M6, M7 and D2 marked fixed in the design review; their lines leave `openspec/backlog.md` at archive.
- No new dependencies. Nothing is added to the open path.
