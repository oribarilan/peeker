# pdf Specification

## Purpose

The PDF plugin: open PDFs faster than Preview, read them with thumbnails and zoom, and add highlights that are saved into the file as standard annotations.

## Requirements

### Requirement: Opens PDFs quickly and safely

The plugin SHALL open PDF files without stalling the app, checking that the file is a readable PDF before showing it. A file that isn't a readable PDF SHALL show "This file isn't a readable PDF." in its tab, and a password-protected PDF SHALL show "This PDF is password protected."

#### Scenario: Locked PDF

- **WHEN** the user opens a password-protected PDF
- **THEN** the tab says the PDF is password protected

#### Scenario: Not a PDF

- **WHEN** the user opens a text file renamed to `.pdf`
- **THEN** the tab says the file isn't a readable PDF, and the app keeps running

### Requirement: Shows pages in a continuous native view

The PDF SHALL appear in a native PDF view as one continuous column of pages, scaled to fit the window, with text that can be selected and copied and the file's existing annotations visible. Zoom In and Zoom Out (Cmd+= and Cmd+-) SHALL change the scale.

#### Scenario: Copying text

- **WHEN** the user selects a sentence on a page and presses Cmd+C
- **THEN** the sentence is on the clipboard

### Requirement: Thumbnails and document info in the sidebar

The sidebar SHALL show page thumbnails that jump to a page when clicked, and an info panel with the page count, PDF version, and the title, author, creating app and encryption when the file has them.

#### Scenario: Jumping by thumbnail

- **WHEN** the user clicks the thumbnail of page 40
- **THEN** the view scrolls to page 40

### Requirement: Highlighting a selection is an edit

Highlight Selection (Ctrl+Cmd+H) SHALL be an Edit mode tool: from the read view it SHALL turn Edit mode on first. It SHALL cover each line of the current text selection with an opaque yellow highlight, clear the selection, and mark the document edited. With no selection it SHALL change nothing. Highlights SHALL stay pending until Cmd+S, follow the document rules for prompts and crash recovery, and disappear on Don't Save.

#### Scenario: Highlight across two lines

- **WHEN** the user selects text spanning two lines and presses Ctrl+Cmd+H
- **THEN** both lines are highlighted and the window shows the edited mark

#### Scenario: From the read view

- **WHEN** a PDF is in its read view and the user selects a sentence and presses Ctrl+Cmd+H
- **THEN** Edit mode turns on and the sentence is highlighted

### Requirement: Highlights are saved as standard PDF annotations

On Cmd+S, the plugin SHALL write each pending highlight into the file as a standard highlight annotation, so it appears in Preview and other PDF apps. The plugin SHALL refuse the whole save, writing nothing, when a highlight names a page the file doesn't have or has an invalid position or color, or when the file is no longer a readable PDF or is locked.

#### Scenario: Highlight seen in Preview

- **WHEN** the user highlights a sentence in Peeker, saves, and opens the file in Apple's Preview
- **THEN** Preview shows the highlight

### Requirement: Opening PDFs beats Preview

Opening a PDF with the app not running SHALL draw its content no later than Preview shows its window for the same file: faster, or within 10%. The benchmark measures this on a 3-page and a 2,000-page PDF.

#### Scenario: 2,000-page PDF

- **WHEN** the benchmark opens the 2,000-page fixture in Peeker and in Preview
- **THEN** Peeker's content time is lower than Preview's window time, or at most 10% higher

### Requirement: PDFs have an edit mode with Text Box, Sign and Highlight

A PDF opened in a window SHALL have an edit mode. Its tools SHALL be Text Box, Sign and Highlight Selection, each with a shortcut that can be rebound like other plugin commands. Zoom In and Zoom Out SHALL work in both modes. The Space panel SHALL never offer Edit mode.

#### Scenario: The tools

- **WHEN** the user turns on Edit mode for a PDF
- **THEN** the toolbar offers Text Box, Sign and Highlight Selection

### Requirement: Form fields can be filled only in Edit mode

In the read view, a PDF's form fields SHALL show their values but not accept input. In Edit mode, the user SHALL be able to type into text fields, tick checkboxes, pick radio buttons and choose list entries, and each change SHALL be an edit.

#### Scenario: Filling a field

- **WHEN** a PDF form is in Edit mode and the user types a name into its Name field
- **THEN** the field shows the name and the document is marked edited

#### Scenario: A field in the read view

- **WHEN** the same form is in its read view and the user clicks the Name field
- **THEN** no cursor appears and the field doesn't change

### Requirement: Field values are saved into the form

On Cmd+S, filled-in values SHALL be written into the form's fields as field values, keeping the form fillable. The plugin SHALL NOT flatten the form.

#### Scenario: Seen in Preview

- **WHEN** the user fills and saves a form in Peeker and opens it in Preview
- **THEN** Preview shows the values in the fields and they can still be changed there

### Requirement: Text boxes add text anywhere on a page

With Text Box chosen, a click on a page SHALL start a text box there for typing, and double-clicking a text box SHALL edit its text again. Text SHALL be black, in one system font, at a size set by a control shown with the box being edited, and the box SHALL grow to fit. An empty text box SHALL be removed when editing ends. On Cmd+S each text box SHALL be written as a standard free-text annotation.

#### Scenario: Filling a flat form

- **WHEN** the user chooses Text Box, clicks next to "Date:" on a scanned form and types a date
- **THEN** the date appears where they clicked, and after saving Preview shows it as a text annotation

### Requirement: Signatures are drawn and placed by clicking

Sign SHALL open a pad where the user draws a signature with the trackpad or mouse, with Clear, Cancel and Done. After Done, the signature SHALL follow the pointer over the page until a click places it there. On Cmd+S each signature SHALL be written as a standard ink annotation made of its strokes.

#### Scenario: Signing a contract

- **WHEN** the user chooses Sign, draws their signature, clicks Done and clicks on the signature line
- **THEN** the signature appears on the line, and after saving Preview shows it and can move it

### Requirement: Signatures are never written to disk

The plugin SHALL NOT write a signature anywhere except into the PDF the user places it in. The last signature drawn SHALL be kept in memory until Peeker quits, and Sign SHALL offer it alongside drawing a new one.

#### Scenario: Signing two pages

- **WHEN** the user places a signature on page 1, then chooses Sign again
- **THEN** Sign offers the same signature, which can be placed on page 2 without drawing again

#### Scenario: After quitting

- **WHEN** the user quits Peeker and opens it again
- **THEN** Sign has no earlier signature to offer, and no file under the user's folders holds one

### Requirement: Peeker's own annotations can be adjusted

In Edit mode, clicking a text box, signature or highlight that Peeker made SHALL select it. A selected one SHALL move by dragging, resize by dragging a corner handle, and be removed with Delete; each SHALL be an edit. This SHALL work for unsaved ones and for ones Peeker saved earlier. Annotations made by other apps SHALL be shown but not selected or changed.

#### Scenario: Moving a saved signature

- **WHEN** the user reopens a PDF they signed and saved in Peeker, turns on Edit mode and drags the signature
- **THEN** the signature moves and the document is marked edited

#### Scenario: Another app's note

- **WHEN** the PDF has a note added in Acrobat and the user clicks it in Edit mode
- **THEN** the note isn't selected and nothing changes

### Requirement: Undo covers every change since the window opened

In Edit mode, Undo (Cmd+Z) and Redo (Cmd+Shift+Z) SHALL take back and reapply each change: a field value, a placed text box or signature, a highlight, a move, a resize or a removal. The history SHALL reach back to when the window opened, including changes already saved; undoing a saved change SHALL be a new unsaved edit. Dropping unsaved edits with Don't Save SHALL clear the history.

#### Scenario: Undoing after saving

- **WHEN** the user places a signature, saves, then presses Cmd+Z
- **THEN** the signature disappears and the document is marked edited until saved again

### Requirement: A save writes every pending PDF edit or none

On Cmd+S the plugin SHALL apply all pending edits (field values, text boxes, signatures, highlights, moves, resizes and removals) to the file on disk, off the main thread, and write it through the safe-write path. If any edit can't be applied, it SHALL write nothing and say which edit failed.

#### Scenario: An annotation removed by another app

- **WHEN** the user moves a saved signature, another app deletes that signature from the file, and the user saves with Save Anyway
- **THEN** the save fails without writing, saying the signature to move is no longer in the file, and the edits stay pending

### Requirement: PDFs that can't be safely edited keep Edit mode off

Edit mode SHALL be unavailable, with a reason the user can see, for an XFA form ("This form uses XFA, which Peeker can't fill."), a PDF whose permissions forbid changes ("This PDF's permissions don't allow changes."), and a digitally signed PDF ("This PDF is digitally signed; changing it would break the signature."). Such PDFs SHALL still open and read as before.

#### Scenario: A signed contract

- **WHEN** the user opens a PDF that carries a digital signature and presses Cmd+E
- **THEN** a message says changing it would break the signature, and the PDF stays in its read view

### Requirement: Edit mode doesn't slow opening

The plugin SHALL set up its editing tools only when Edit mode first turns on, so opening a PDF does no more work than before this change. The open benchmark SHALL show no regression against the previous build.

#### Scenario: Benchmark after the change

- **WHEN** `scripts/bench-ab.sh` compares this change with the previous `main` on the PDF fixtures
- **THEN** no PDF open time regresses past the gate

### Requirement: Saved annotations stay Peeker's on every supported macOS

A highlight, text box or signature Peeker saved SHALL be found again as Peeker's own when the file is reopened, on every macOS version Peeker supports, so it can be moved, resized, changed or removed like an unsaved one. Another app's annotation SHALL never be taken for Peeker's.

#### Scenario: Removing a saved highlight on macOS 26

- **WHEN** on macOS 26 the user saves a highlight, reopens the PDF later, selects the highlight in Edit mode, deletes it and saves
- **THEN** the save succeeds and the highlight is gone from the file

#### Scenario: Another app's annotation on macOS 26

- **WHEN** on macOS 26 the PDF holds a highlight another app made, next to one Peeker saved
- **THEN** only Peeker's can be selected in Edit mode

### Requirement: Reordering pages by dragging needs macOS 27

On macOS 26, thumbnails SHALL NOT be draggable, in Edit mode or out of it; Rotate Left, Rotate Right and Delete Page SHALL keep working from the toolbar, the Commands menu and the thumbnails' menu. On macOS 27 and later, dragging SHALL reorder pages as before.

#### Scenario: Dragging on macOS 26

- **WHEN** on macOS 26 the user drags page 3's thumbnail above page 1 in Edit mode
- **THEN** no page moves, and Rotate and Delete Page still work on the selected thumbnails

#### Scenario: Dragging on macOS 27

- **WHEN** on macOS 27 the user drags page 3's thumbnail above page 1 in Edit mode
- **THEN** page 3 becomes page 1
