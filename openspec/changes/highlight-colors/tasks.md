# Tasks

## 1. Contract

- [x] 1.1 Add `ToolSpec.Choice` (`id`, `title`, optional `color: RGBA`) and `choices` / `choicesTitle` to `ToolSpec` in `Sources/PeekerKit/Plugin.swift`, defaulting to none; document that a choice runs through `perform` and is checked through `isOn`.

## 2. Host

- [x] 2.1 Failing tests: a tool with choices gets a submenu named `choicesTitle` right after its menu item, listing the choices with a colored dot and an accessibility label of just the title; the item `isOn` reports is checked; picking one calls `perform(choice.id)`; choices grey out with the tool's reason; a rebuild for another document removes them; a tool without choices gets no submenu.
- [x] 2.2 Implement them in `MainMenu.rebuildTools` and `DocumentWindowController` (`runChoice(_:)`, `validateMenuItem`).
- [x] 2.3 Failing test, then implementation: the toolbar item of a tool with choices is an `NSMenuToolbarItem` with the indicator, the same menu, and the tool's own action; `showActiveTool` still marks it active.

## 3. PDF

- [x] 3.1 Failing tests: Highlight lists the five colors in order with Yellow on by default; picking Green highlights selected text green and arms the highlighter; a highlight made earlier keeps its color; saving writes each color into the file; a read-only PDF greys the colors out with Highlight's reason.
- [x] 3.2 Failing tests: the pick is stored under `plugins.pdf.highlightColor` and a new document starts with it; an unknown stored value counts as Yellow; with no preferences (tests, benchmark) it's Yellow.
- [x] 3.3 Implement: the colors and choice ids in `PDFPlugin`, `context.preferences` passed to `PDFPluginDocument`, the current color used in `highlightSelection()`, `perform` and `isOn` for the color ids.

## 4. Checks and docs

- [x] 4.1 `drive menu` takes a `Menu>Submenu` item path; `common.sh` adds `plugins.pdf.highlightColor` to `PREF_KEYS`.
- [x] 4.2 Screen step in `record-flows.sh`: in the open PDF check the Highlight button's color arrow, pick Tools > Highlight Color > Green, check `✓ Highlight` and `✓ Green`, close and reopen the PDF, check Green is still checked and the preference says green (a fresh launch reading it is the unit test); update the `run-peeker` skill.
- [x] 4.3 `scripts/build.sh test` passes with no new warnings.
- [x] 4.4 CHANGELOG line; `openspec/gaps.md` drops "one highlight color"; `openspec/backlog.md` gains recoloring a highlight; `openspec validate --all --strict`.

## Workflow follow-up

- Commit the change, then bump the minor version in its own commit; run the screen flows; archive, push and install.
