# Spec Delta

## ADDED Requirements

### Requirement: Copying cells

Copy (Cmd+C, Edit > Copy, or Copy in the right-click menu) SHALL put the selected cells on the clipboard as plain text. With one cell selected it SHALL copy that cell's text at once. With more than one selected it SHALL open the copy sheet. Cells SHALL be copied in the order the table shows them, row by row, with only the selected columns in their shown order. A read-only table SHALL copy too.

#### Scenario: One cell

- **WHEN** Cake's price, `4.20`, is the only cell selected and the user presses Cmd+C
- **THEN** the clipboard holds `4.20` and no sheet appears

#### Scenario: A sorted block

- **WHEN** the table is sorted by price and the user selects the name and price of the first two rows shown and copies them as Tabs without the header
- **THEN** the clipboard holds those two rows in the sorted order, each as name, a tab, price

#### Scenario: Copy in the right-click menu

- **WHEN** the user right-clicks a selected block
- **THEN** the menu offers Copy, and choosing it opens the copy sheet

### Requirement: The copy sheet

The copy sheet SHALL show a preview of the text that will be copied (its first lines when there are many), a format choice of Tabs, Commas, Semicolons and Markdown table, and an Include header row checkbox shown only when the table shows a header row, which adds the selected columns' titles first. Copy SHALL be the default button and Cancel SHALL copy nothing. The sheet SHALL open with the format and header choice last used to copy, Tabs with the header the first time.

#### Scenario: Return copies the last way

- **WHEN** the user last copied as Markdown table with the header and now selects a block and presses Cmd+C, then Return
- **THEN** the block is copied as a Markdown table with the column titles first

#### Scenario: The preview follows the choices

- **WHEN** the copy sheet is open and the user switches the format from Tabs to Commas
- **THEN** the preview shows the cells separated by commas, with fields holding commas quoted

#### Scenario: Cancel

- **WHEN** the user opens the copy sheet and clicks Cancel
- **THEN** the clipboard is unchanged

#### Scenario: A table without a header row

- **WHEN** Header Row is off and the user copies two cells
- **THEN** the sheet has no Include header row checkbox

### Requirement: Copy formats

With Commas, Semicolons or Tabs, a copied field holding the separator, a quote or a line break SHALL be quoted, with its quotes doubled. With Markdown table, the first line SHALL be the header (or empty titles without one), then a `---` row, and a field's `|` SHALL be escaped and its line breaks turned into spaces.

#### Scenario: A comma in a field

- **WHEN** the user copies `Green, loose leaf` and `3.50` as Commas
- **THEN** the clipboard holds `"Green, loose leaf",3.50`

#### Scenario: A Markdown table

- **WHEN** the user copies a cell holding `a|b` with its column title `note` as Markdown table with the header
- **THEN** the clipboard holds `| note |`, then `| --- |`, then `| a\|b |`
