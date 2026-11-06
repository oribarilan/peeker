# Proposal

## Why

PDF highlights come in one color, yellow, which `openspec/gaps.md` lists as a gap. People who mark up a document often use colors to tell kinds of notes apart, and Preview offers five. The file format already holds any color per highlight, so what's missing is a way to pick one.

## What Changes

- The PDF Highlight tool offers Preview's five colors: Yellow, Green, Blue, Pink and Purple.
- The colors appear in two places, each with a colored dot and a checkmark on the current color:
  - a menu on the toolbar's Highlight button, opened by the arrow beside it;
  - a Highlight Color submenu under Tools, after Highlight.
- Picking a color sets it and arms the highlighter, the same as choosing Highlight. Text already selected is highlighted at once in the new color.
- New highlights use the current color. Highlights already on the page keep theirs; recoloring them goes to the backlog.
- The last color is remembered for every PDF, in windows and across launches. It starts as Yellow.
- The plugin contract gains a generic way for a tool to offer a short list of choices. The host shows them as the toolbar menu and the submenu, and checks the current one, so it still knows nothing about PDFs or colors.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `pdf`: the highlighter draws in the chosen color instead of always yellow; the colors, picking one, and remembering it.
- `plugin-host`: a tool can offer choices, shown as a menu on its toolbar button and a submenu under its menu item, with the current choice checked.

## Impact

- `Sources/PeekerKit/Plugin.swift`: `ToolSpec` gains its choices. The current choice is reported through the existing `isOn(_:)`, and picking one runs through the existing `perform(_:)`.
- `Sources/Host/Documents/DocumentWindowController.swift` (toolbar item and active-tool look) and `Sources/Host/App/MainMenu.swift` (the submenu).
- `Plugins/pdf/`: `PDFPlugin` declares the colors and passes `PluginPreferences` to the document; `PDFPluginDocument` keeps the current color and uses it in `highlightSelection()`.
- Tests: Swift Testing suites for the contract, the menus, and the PDF tool. The screen flows check the submenu and the remembered color.
- Docs: CHANGELOG, `openspec/gaps.md` (the one-color gap goes), `openspec/backlog.md` (recoloring a highlight), the `run-peeker` skill. Minor version bump.
