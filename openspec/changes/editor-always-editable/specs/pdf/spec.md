## ADDED Requirements

### Requirement: PDF edit tools: Text Box, Sign and Highlight

A PDF opened in the Editor SHALL offer the edit tools Text Box (Ctrl+Cmd+T), Sign and Highlight Selection (Ctrl+Cmd+H); Sign SHALL have no shortcut by default, leaving Ctrl+Cmd+S to Show/Hide Sidebar. Each tool's shortcut can be set or rebound like other plugin tools. The Peek panel SHALL never offer edit tools.

#### Scenario: The tools

- **WHEN** the user opens a PDF in the Editor
- **THEN** the toolbar offers Text Box, Sign and Highlight Selection

#### Scenario: Ctrl+Cmd+S in a PDF

- **WHEN** a PDF is in front and the config sets no shortcut for Sign
- **THEN** Ctrl+Cmd+S shows or hides the sidebar, and Tools > Sign shows no shortcut

### Requirement: Form fields fill in the Editor

In the Editor, the user SHALL be able to type into a PDF's text fields, tick checkboxes, pick radio buttons and choose list entries, and each change SHALL be an edit. In the Peek panel, fields SHALL show their values but not accept input.

#### Scenario: Filling a field

- **WHEN** a PDF form is open in the Editor and the user types a name into its Name field
- **THEN** the field shows the name and the document is marked edited

#### Scenario: A field in the Peek panel

- **WHEN** the same form is shown in the Peek panel and the user clicks the Name field
- **THEN** no cursor appears and the field doesn't change

### Requirement: PDFs that can't be safely edited are read-only

A PDF SHALL be read-only, with a reason the user can see, when it's an XFA form ("This form uses XFA, which Peeker can't fill."), its permissions forbid changes ("This PDF's permissions don't allow changes."), or it's digitally signed ("This PDF is digitally signed; changing it would break the signature."). Such PDFs SHALL still open and read as before.

#### Scenario: A signed contract

- **WHEN** the user opens a PDF that carries a digital signature
- **THEN** the edit tools are greyed out and the note under the toolbar says changing it would break the signature

### Requirement: Edit tools don't slow opening

The plugin SHALL set up each edit tool's machinery (text boxes, the signature pad, form editing) only when that tool or a form field is first used, so opening a PDF in the Editor does no more work than opening it in the old read view. The open benchmark SHALL show no regression against the previous build.

#### Scenario: Benchmark after the change

- **WHEN** `scripts/bench-ab.sh` compares this change with the previous `main` on the PDF fixtures
- **THEN** no PDF open time regresses past the gate

### Requirement: Page tools

In the Editor, the PDF plugin SHALL offer Rotate Left (Cmd+L), Rotate Right (Cmd+R) and Delete Page, in the toolbar, the Tools menu and a right-click menu on the thumbnails. Each SHALL act on the selected thumbnails (Shift- and Cmd-click select several), or on the current page when none is selected. The Peek panel SHALL have no page tools.

#### Scenario: Rotating selected pages
- **WHEN** pages 2 and 3 are selected in the sidebar and the user presses Cmd+R
- **THEN** both pages turn a quarter turn clockwise, and their thumbnails show it

#### Scenario: Current page when nothing is selected
- **WHEN** no thumbnail is selected, page 4 is the current page, and the user chooses Rotate Left
- **THEN** page 4 turns a quarter turn counterclockwise

### Requirement: Reordering pages in the Editor

In the Editor, dragging thumbnails in the sidebar SHALL move those pages to where they are dropped, keeping their relative order. In the Peek panel, thumbnails SHALL only select and go to pages, never move them. Pages dragged in from outside the document SHALL be refused.

#### Scenario: Dragging a page
- **WHEN** the user drags page 5's thumbnail above page 1
- **THEN** that page becomes page 1 and the others move down

#### Scenario: In the Peek panel
- **WHEN** the user drags a thumbnail in the Peek panel
- **THEN** no page moves

### Requirement: Finding text in a PDF

In the Editor, Find… (Cmd+F) SHALL show a find bar above the pages and below the toolbar, never under it, with a search field, the match count, previous and next buttons and Done, with the cursor in the field. Typing SHALL search the whole document, ignoring case and accents, without stalling the window. Every match SHALL be highlighted and the current one selected and in view. Finding SHALL never change the file.

#### Scenario: Searching
- **WHEN** the user presses Cmd+F in a PDF window and types "invoice", which appears 3 times
- **THEN** all 3 matches are highlighted, the first is selected and in view, and the bar says "1 of 3"

#### Scenario: Bar below the toolbar
- **WHEN** the user presses Cmd+F in a PDF window
- **THEN** the whole find bar, its field and match count included, shows below the toolbar and the window title

#### Scenario: Case and accents ignored
- **WHEN** the user searches for "cafe" in a PDF containing "Café"
- **THEN** "Café" is a match

#### Scenario: No text
- **WHEN** the user searches a scanned PDF that has no text, or for a word that isn't there
- **THEN** the bar says "Not found"

#### Scenario: Nothing to save
- **WHEN** the user searches a PDF
- **THEN** matches are found and shown, and nothing is added to the unsaved edits

#### Scenario: Peek panel
- **WHEN** a PDF is shown in the Peek panel
- **THEN** Find is unavailable

## REMOVED Requirements

### Requirement: PDFs have an edit mode with Text Box, Sign and Highlight
**Reason**: There is no Edit mode; the tools are always available in the Editor.
**Migration**: See "PDF edit tools: Text Box, Sign and Highlight".

### Requirement: Form fields can be filled only in Edit mode
**Reason**: Forms fill directly in the Editor, as in Preview.
**Migration**: See "Form fields fill in the Editor".

### Requirement: PDFs that can't be safely edited keep Edit mode off
**Reason**: With no Edit mode, such PDFs are read-only with greyed tools and a note.
**Migration**: See "PDFs that can't be safely edited are read-only".

### Requirement: Edit mode doesn't slow opening
**Reason**: Restated for tools that load on first use.
**Migration**: See "Edit tools don't slow opening".

### Requirement: Page commands
**Reason**: Renamed to tools, without the read view.
**Migration**: See "Page tools".

### Requirement: Reordering pages
**Reason**: Restated without the read view.
**Migration**: See "Reordering pages in the Editor".

### Requirement: Find in a PDF
**Reason**: Restated without Edit mode.
**Migration**: See "Finding text in a PDF".

## MODIFIED Requirements

### Requirement: Peeker's own annotations can be adjusted

In the Editor, clicking a text box, signature or highlight that Peeker made SHALL select it. A selected one SHALL move by dragging, resize by dragging a corner handle, and be removed with Delete; each SHALL be an edit. This SHALL work for unsaved ones and for ones Peeker saved earlier. Annotations made by other apps SHALL be shown but not selected or changed.

#### Scenario: Moving a saved signature

- **WHEN** the user reopens a PDF they signed and saved in Peeker and drags the signature
- **THEN** the signature moves and the document is marked edited

#### Scenario: Another app's note

- **WHEN** the PDF has a note added in Acrobat and the user clicks it
- **THEN** the note isn't selected and nothing changes

### Requirement: Undo covers every change since the window opened

In the Editor, Undo (Cmd+Z) and Redo (Cmd+Shift+Z) SHALL take back and reapply each change: a field value, a placed text box or signature, a highlight, a move, a resize or a removal. The history SHALL reach back to when the window opened, including changes already saved; undoing a saved change SHALL be a new unsaved edit. Dropping unsaved edits with Don't Save SHALL clear the history.

#### Scenario: Undoing after saving

- **WHEN** the user places a signature, saves, then presses Cmd+Z
- **THEN** the signature disappears and the document is marked edited until saved again

### Requirement: Saved annotations stay Peeker's on every supported macOS

A highlight, text box or signature Peeker saved SHALL be found again as Peeker's own when the file is reopened, on every macOS version Peeker supports, so it can be moved, resized, changed or removed like an unsaved one. Another app's annotation SHALL never be taken for Peeker's.

#### Scenario: Removing a saved highlight on macOS 26

- **WHEN** on macOS 26 the user saves a highlight, reopens the PDF later, selects the highlight, deletes it and saves
- **THEN** the save succeeds and the highlight is gone from the file

#### Scenario: Another app's annotation on macOS 26

- **WHEN** on macOS 26 the PDF holds a highlight another app made, next to one Peeker saved
- **THEN** only Peeker's can be selected

### Requirement: Reordering pages by dragging needs macOS 27

On macOS 26, thumbnails SHALL NOT be draggable; Rotate Left, Rotate Right and Delete Page SHALL keep working from the toolbar, the Tools menu and the thumbnails' menu. On macOS 27 and later, dragging SHALL reorder pages as before.

#### Scenario: Dragging on macOS 26

- **WHEN** on macOS 26 the user drags page 3's thumbnail above page 1
- **THEN** no page moves, and Rotate and Delete Page still work on the selected thumbnails

#### Scenario: Dragging on macOS 27

- **WHEN** on macOS 27 the user drags page 3's thumbnail above page 1
- **THEN** page 3 becomes page 1

### Requirement: Deleting pages

Delete Page, or the Delete key with the sidebar's thumbnails focused, SHALL remove the selected pages (or the current page) without asking. When the selection covers every page, Delete Page SHALL be greyed out with the reason "A PDF needs at least one page.", and the Delete key SHALL beep and change nothing.

#### Scenario: Deleting a page
- **WHEN** the user selects page 2 of 5 and presses Delete in the sidebar
- **THEN** page 2 disappears, the document has 4 pages and is marked as edited

#### Scenario: Every page selected
- **WHEN** all pages are selected
- **THEN** Delete Page is greyed out and the Delete key beeps

### Requirement: Saving page changes

Rotating, deleting and reordering SHALL be edits like the others: pending until Cmd+S, one undo step per tool or drag, kept in the recovery copy and asked about on close. Undo SHALL bring back a deleted page even after the deletion was saved. Saving SHALL write rotation as each page's standard rotation and keep each page's annotations, form fields and links with it. Marks on a page SHALL go with the page when it's rotated, moved or deleted.

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
- **THEN** the next launch reopens the PDF with those page changes

### Requirement: Page change permission

When a PDF's permissions forbid page changes but allow comments and form filling, forms, text boxes, signatures and highlights SHALL still work, while Rotate Left, Rotate Right and Delete Page SHALL be greyed out with the reason "This PDF's permissions don't allow page changes." and dragging thumbnails SHALL move nothing.

#### Scenario: Assembly forbidden
- **WHEN** a PDF allows form filling but not page changes and the user opens it
- **THEN** form fields can be filled, and the page tools are greyed out with that reason

### Requirement: Password-protected PDFs

A PDF that needs a password SHALL show, in the Editor, a lock with the file's name, a password field and Unlock. The right password SHALL show the PDF with thumbnails, info, Find and Print, read-only with the reason; a wrong one SHALL say "Wrong password." and clear the field. The password SHALL never be stored. The Peek panel SHALL say the PDF is password protected and that Open in Peeker unlocks it in a window.

#### Scenario: Unlocking
- **WHEN** the user opens a password-protected PDF, types its password and presses Return
- **THEN** the pages, thumbnails and info appear, and the edit tools are greyed out with the reason

#### Scenario: Wrong password
- **WHEN** the user types a wrong password and presses Unlock
- **THEN** the tab says "Wrong password." and the field is empty

#### Scenario: Peek panel
- **WHEN** the user presses Space on a password-protected PDF
- **THEN** the panel says the PDF is password protected and that Open in Peeker unlocks it in a window

### Requirement: Highlight is a highlighter for one drag

Highlight (Ctrl+Cmd+H) SHALL be an edit tool. Choosing it SHALL arm the highlighter: the next drag over text SHALL cover each line it selects with an opaque yellow highlight, clear the selection, mark the document edited and disarm it. Text already selected SHALL be highlighted at once, leaving the highlighter armed for one drag. Escape or another tool SHALL disarm it. Highlights SHALL stay pending until Cmd+S.

#### Scenario: Highlighting by dragging

- **WHEN** the user clicks Highlight and drags over a sentence spanning two lines
- **THEN** both lines are highlighted, the window shows the edited mark, and a second drag only selects text

#### Scenario: A selection made first

- **WHEN** the user selects a word and presses Ctrl+Cmd+H
- **THEN** the word is highlighted, and the next drag over text highlights it too

#### Scenario: Changing one's mind

- **WHEN** the user clicks Highlight and presses Escape before dragging
- **THEN** the next drag only selects text

### Requirement: A waiting tool shows itself

While Text Box, Sign or Highlight waits for its click or drag, its toolbar button SHALL show as selected and its Tools menu item SHALL be checked, and the pointer over a page SHALL show the tool: a crosshair for Text Box, a highlighter for Highlight, and the signature following it for Sign. Once the tool is used or dismissed, both SHALL go back.

#### Scenario: Arming the highlighter

- **WHEN** the user clicks Highlight
- **THEN** the Highlight button shows as selected and the pointer over the page becomes a highlighter, until the drag that highlights or Escape

#### Scenario: Placing a text box

- **WHEN** the user clicks Text Box and then clicks on the page
- **THEN** the button shows as selected with a crosshair pointer until that click, then neither
