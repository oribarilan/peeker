# Design

## Context

The PDF plugin has a find bar (`PDFFindBar`, `FindField`, `FindFieldCell`, `FindFieldEditor`, `FindAction` in `Plugins/pdf/PDFFindContainer.swift`), generic apart from taking a `PDFFinder` and a `PDFFindContainer`. Plugins can't import each other, so a second user means moving it to PeekerKit. The table plugin draws cells with a cheap `CellView` (text only), shows rows through `TableView.order` (file order or a sort), and every table change goes through `TableView.reloadAll`, `reloadCells` or `reloadRows`. The host prints through `PluginDocument.printJob` and sets the job title; `TextPrinting` shows how header and footer are turned on.

## Goals / Non-Goals

**Goals:** one find bar for PDFs and tables; nothing added to opening a table; printing that handles a long or wide table.

**Non-Goals:** Replace; Find or Print in the Peek panel; printing only selected rows; remembering print choices past the window.

## Decisions

- **Shared bar in PeekerKit (`FindBar.swift`).** `FindBar(label:)` exposes `field`, `status` (a settable string), `onSearch: (String) -> Void` and `onAction: (FindAction) -> Void`, plus the static `action(for:shift:)`. `FindFieldEditor` forwards Find Next/Previous to a weak `target: NSResponder?` and asks `target as? NSMenuItemValidation` to validate. The PDF container keeps its layout and wires `onSearch` to `PDFFinder.search` and `finder.onChange` to `bar.status`. Its tests change only the type names.
- **`TableFindContainer` is the table document's content view.** It holds `TableView`, and from the first Cmd+F the bar above it (constraints switched as the PDF container does), and a `TableFinder`. It answers `performFindPanelAction` and menu validation in the responder chain, so Cmd+F, Cmd+G and Shift+Cmd+G work from the table, the cell editor and the field. It ends cell typing (`commitEditing`) before showing the bar.
- **`TableFinder` searches a value copy of `CSVTable`** (a `Sendable` struct) in a detached task, using `range(of:options: [.caseInsensitive, .diacriticInsensitive])` on each cell. It returns matches as `(fileRow, column)` in file order with a generation number, so a stale result is dropped. Ordering by what's shown is a separate pure step: header matches first, then by the shown position of each match's file row (from `TableView.order`, or file order), then by column. Tests cover matching and ordering without a window.
- **Tints.** `TableView` gets `marks: Set<CellRef>` and `currentMark: CellRef?`; `CellView` gets a `mark` (none, match, current) and fills a rounded rect behind its text in `findHighlightColor` (match at 40% alpha, current at full). Header matches tint the column title with a background-colored attributed title. The current match also selects its row and scrolls its cell into view. `TableView.onChange` fires after each reload, and the container searches again (without selecting the first match) while the bar shows.
- **Printing: `TablePrintView`, a flipped view that paginates itself.** `knowsPageRange` reads the operation's paper size and margins, measures each printed column's width (header plus the first 1,000 rows, 30 to 300 points at 10-point text, clipped), scales everything by `min(1, page width / total width)`, and fits whole rows per page under the repeated bold header. Its frame is the page width by the page height times the page count; `rectForPage` returns one band per page, and `draw` draws the bands it's asked for, black on white with light grid lines. Turning on `headerAndFooter` gives the system header and footer. Layout is a pure `TablePrintLayout`, so tests check scale, rows per page and page count.
- **Print panel section: `TablePrintOptions`,** an `NSViewController` conforming to `NSPrintPanelAccessorizing`, with a Row Numbers checkbox and a scrolling stack of column checkboxes. It edits a `TablePrintChoices` value (`showsRowNumbers`, `hiddenColumns`) shared with the print view and the document. `keyPathsForValuesAffectingPreview` names a KVO-observable `choicesVersion` that bumps on each change, so the preview redraws. The document keeps the last choices, so they last while the window is open; hidden columns past the column count are dropped.

## Risks / Trade-offs

- [A header row or a cell several times wider than the rest shrinks the whole printout] → Widths are capped at 300 points and cells clipped; Landscape in the panel helps.
- [Searching a 200 MB table reads every cell] → Done off the main thread, with the bar's status empty until it finishes; a new keystroke cancels the old search through the generation check.
- [Moving the find bar could change PDF find] → Same view code moved as is; the PDF find tests run unchanged apart from the type names.
