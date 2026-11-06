# Design

## Context

A PDF highlight is a `PDFMark` of kind `.highlight(RGBA)`, written as a standard highlight annotation. The color is stored per mark already, but `PDFPluginDocument.highlightSelection()` always passes the fixed `highlightColor` (1, 0.8, 0). Tools reach the host as `ToolSpec`s. The host runs a tool through `perform(_:)`, checks a switch through `isOn(_:)`, greys a tool out through `unavailableReason(for:)`, and shows the active tool with the toolbar item's `.prominent` style. Plugins get app preferences through `OpenContext.preferences` (`PluginPreferences`, prefix `plugins.<id>.`), which the image plugin uses already; the PDF plugin doesn't take it yet.

Mockups built on 2026-11-06 showed that an `NSMenuToolbarItem` with `showsIndicator` gives the split button the maintainer chose. They also showed that its menu doesn't draw menu item images, while a colored "●" in an attributed title shows in both the toolbar menu and a menu bar submenu.

## Goals / Non-Goals

**Goals:**
- A generic contract for a tool's choices, reusing `perform` and `isOn` so plugins learn one small thing.
- The same choices, checked the same way, in the toolbar and the menu bar.

**Non-Goals:**
- Shortcuts for single choices (no default key for Green, say). The tool's own key stays.
- Recoloring existing highlights (backlog), underline and strikethrough marks, and a custom color picker.

## Decisions

**Choices are tools without buttons.** `ToolSpec` gains `choices: [ToolSpec.Choice]`, where a choice has an `id`, a `title` and an optional `color: RGBA`, and `choicesTitle: String?` names the submenu ("Highlight Color").
- Picking a choice calls `perform(choice.id)`; the current one answers `isOn(choice.id) == true`. Availability follows `unavailableReason(for: tool.id)`.
- Rejected: a new protocol method such as `chosenOption(for:)` plus `choose(_:for:)`. That's two more requirements on every plugin document for something `perform` and `isOn` already express.
- Choice ids are plain strings the plugin owns, such as `highlight-green`. The host never parses them.

**Host rendering.**
- Toolbar: a tool with choices gets an `NSMenuToolbarItem` (`showsIndicator = true`). Its target and action run the tool as other items do, so a click on the button arms Highlight and the arrow opens the menu. `showActiveTool()` already sets `style` on every tool item, so the active look works unchanged.
- Menus: `MainMenu.rebuildTools` adds an item titled `choicesTitle` right after the tool, with a submenu of the choices.
- Every choice item uses one action, `runChoice(_:)`, which finds the choice by `representedObject` (its id). `validateMenuItem` checks it through `isOn` and greys it out with the tool's reason. Choice items are removed with the tools on rebuild: they share a tag and action, so the existing clean-up loop catches them.
- The dot: an attributed title starting with a "●" in the choice's color, since the toolbar menu ignores item images. Without a color, the title is plain.

**PDF colors.** The ids are `highlight-yellow`, `-green`, `-blue`, `-pink` and `-purple`.
- Yellow keeps today's (1, 0.8, 0), so existing highlights and tests don't move. The others are pale enough to read text through: Green (0.4, 0.85, 0.35), Blue (0.35, 0.65, 1), Pink (1, 0.45, 0.65) and Purple (0.72, 0.5, 1). Preview's exact values aren't documented; these are close and can be tuned without a spec change.
- `perform` on a color id sets the color, stores its name under `plugins.pdf.highlightColor` (`yellow`, `green`, ...), then runs the same code as `"highlight"`.
- At open, the document reads the stored name and falls back to Yellow for anything else. `PDFPlugin` passes `context.preferences`, which is nil in tests and benchmarks, so those always start yellow.

**Screen step.** Synthetic drags don't select PDF text, so the highlight itself stays a unit test, which reads the saved annotation's color.
- `record-flows.sh` already arms Highlight in an open PDF. It adds: pick Green through `drive menu` with a submenu path, check `✓ Highlight` and `✓ Green`, quit, relaunch, and check Green is still checked.
- `drive menu` learns a `Menu>Submenu` item path. `common.sh` adds `plugins.pdf.highlightColor` to `PREF_KEYS`, so the run leaves the user's color alone.

## Risks / Trade-offs

- [`NSMenuToolbarItem` doesn't take the `.toolbar` push button the switch tools use] → Highlight isn't a switch (`isOn("highlight")` is nil). It uses `style`, which `NSMenuToolbarItem` supports. A tool that is both a switch and has choices would need more work; none exists.
- [A "●" in the title is read aloud by VoiceOver] → Give each choice item an accessibility label of just its title.
- [A preference shared by every window] → The value is read when a window opens and written on each pick, so another open window keeps its color until it's reopened. That's acceptable for a remembered default, and it's how text zoom works.
