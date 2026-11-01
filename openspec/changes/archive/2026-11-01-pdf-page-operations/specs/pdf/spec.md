## ADDED Requirements

### Requirement: Page commands

In a document window, the PDF plugin SHALL offer Rotate Left (Cmd+L), Rotate Right (Cmd+R) and Delete Page, in the Commands menu and a right-click menu on the thumbnails, with Rotate and Delete buttons in the toolbar in Edit mode. Run from the read view, they SHALL turn Edit mode on first. Each SHALL act on the selected thumbnails (Shift- and Cmd-click select several), or on the current page when none is selected. The Space panel SHALL have no page commands.

#### Scenario: Rotating selected pages
- **WHEN** pages 2 and 3 are selected in the sidebar and the user presses Cmd+R in Edit mode
- **THEN** both pages turn a quarter turn clockwise, and their thumbnails show it

#### Scenario: Current page when nothing is selected
- **WHEN** no thumbnail is selected, page 4 is the current page, and the user chooses Rotate Left
- **THEN** page 4 turns a quarter turn counterclockwise

#### Scenario: From the read view
- **WHEN** the user presses Cmd+L in the read view of an editable PDF
- **THEN** Edit mode turns on and the page rotates

### Requirement: Deleting pages

Delete Page, or the Delete key with the sidebar's thumbnails focused in Edit mode, SHALL remove the selected pages (or the current page) without asking. When the selection covers every page, Delete Page SHALL be greyed out with the reason "A PDF needs at least one page.", and the Delete key SHALL beep and change nothing.

#### Scenario: Deleting a page
- **WHEN** the user selects page 2 of 5 and presses Delete in the sidebar in Edit mode
- **THEN** page 2 disappears, the document has 4 pages and is marked as edited

#### Scenario: Every page selected
- **WHEN** all pages are selected
- **THEN** Delete Page is greyed out and the Delete key beeps

### Requirement: Reordering pages

In Edit mode, dragging thumbnails in the sidebar SHALL move those pages to where they are dropped, keeping their relative order. In the read view and the Space panel, thumbnails SHALL only select and go to pages, never move them. Pages dragged in from outside the document SHALL be refused.

#### Scenario: Dragging a page
- **WHEN** in Edit mode the user drags page 5's thumbnail above page 1
- **THEN** that page becomes page 1 and the others move down

#### Scenario: Read view
- **WHEN** the user drags a thumbnail in the read view
- **THEN** no page moves

### Requirement: Saving page changes

Rotating, deleting and reordering SHALL be edits like the others: pending until Cmd+S, one undo step per command or drag, kept in the recovery copy and asked about on close. Undo SHALL bring back a deleted page even after the deletion was saved. Saving SHALL write rotation as each page's standard rotation and keep each page's annotations, form fields and links with it. Marks on a page SHALL go with the page when it's rotated, moved or deleted.

#### Scenario: Saved and seen elsewhere
- **WHEN** the user rotates page 1, deletes page 3, moves page 4 to the front and presses Cmd+S
- **THEN** the file on disk has the new order without page 3, page 1 is rotated, and Preview shows the same

#### Scenario: Undo after save
- **WHEN** the user deletes page 2, saves, presses Undo and saves again
- **THEN** page 2 is back in the file at its old place

#### Scenario: A mark goes with its page
- **WHEN** a text box was added on page 3 and the user drags page 3 to the front
- **THEN** the text box is on the first page, and saving writes it there

#### Scenario: Recovery
- **WHEN** the user rotates and deletes pages and Peeker is force-quit before saving
- **THEN** the next launch reopens the PDF in Edit mode with those page changes

### Requirement: Page change permission

When a PDF's permissions forbid page changes but allow comments and form filling, Edit mode SHALL still work for forms, text boxes, signatures and highlights, while Rotate Left, Rotate Right and Delete Page SHALL be greyed out with the reason "This PDF's permissions don't allow page changes." and dragging thumbnails SHALL move nothing.

#### Scenario: Assembly forbidden
- **WHEN** a PDF allows form filling but not page changes and the user turns Edit mode on
- **THEN** form fields can be filled, and the page commands are greyed out with that reason
