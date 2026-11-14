# Spec Delta

## ADDED Requirements

### Requirement: Cmd+C copies what's selected in the Peek panel

While the Peek panel shows a file and Finder is in front, Cmd+C SHALL copy what the user selected inside the panel (table cells, or text) when there is something to copy there, instead of Finder copying the file; otherwise it SHALL stay Finder's. Before the user clicks into the panel, nothing in it counts as selected. When copying needs a sheet, the sheet SHALL have the keyboard while it's open, with no key closing the panel or reaching Finder, and Finder SHALL get the keyboard back when it closes, as long as the panel is still showing.

#### Scenario: Before any click

- **WHEN** the Peek panel shows `prices.csv` and the user presses Cmd+C without having clicked into it
- **THEN** Finder copies the file, as without Peeker

#### Scenario: One cell

- **WHEN** the user clicks Cake's price in the panel, then presses Cmd+C
- **THEN** the clipboard holds `4.20`, Finder stays in front, and the arrow keys still move Finder's selection

#### Scenario: Several cells

- **WHEN** the user drags across four cells in the panel, presses Cmd+C, then Return in the copy sheet
- **THEN** the cells are copied, the sheet closes, and Finder is in front again with the panel still showing

#### Scenario: Selected text

- **WHEN** the panel shows `notes.md` and the user selects a word in it and presses Cmd+C
- **THEN** the clipboard holds that word
