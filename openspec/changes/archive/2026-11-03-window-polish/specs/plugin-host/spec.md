## MODIFIED Requirements

### Requirement: The info sidebar shows and hides

An Editor window whose plugin shows sidebar panels SHALL have the system sidebar button at the leading end of its toolbar, over the sidebar beside the window buttons, with the title and the other toolbar items past the sidebar. The button and View > Show/Hide Sidebar SHALL show and hide the sidebar. Whether the sidebar is shown, and its width, SHALL apply to every Editor window, and SHALL last through saves, reloads, Open With and relaunching. Where a document has no sidebar, the item SHALL be greyed out.

#### Scenario: Where the button sits
- **WHEN** the user opens a Markdown file with the sidebar shown
- **THEN** the sidebar button is over the sidebar next to the window buttons, and Open With is right of the sidebar

#### Scenario: Hidden stays hidden after a save
- **WHEN** the user hides the sidebar, edits the file and presses Cmd+S
- **THEN** the sidebar stays hidden

#### Scenario: The next window
- **WHEN** the user hides the sidebar in one window and then opens another file
- **THEN** the new window opens with its sidebar hidden

#### Scenario: Width is remembered
- **WHEN** the user drags the sidebar wider, quits and opens a file again
- **THEN** the sidebar opens at the width it had
