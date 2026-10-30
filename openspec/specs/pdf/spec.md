# pdf Specification

## Purpose

The PDF plugin: open PDFs faster than Preview, read them with thumbnails and zoom, and add highlights that are saved into the file as standard annotations.

## Requirements

### Requirement: Opens PDFs quickly and safely

The plugin SHALL open PDF files and check them in its own process first, parsing the first page there, so a file that crashes the PDF parser takes down the plugin rather than the app. A file that isn't a readable PDF SHALL show "This file isn't a readable PDF." in its tab, and a password-protected PDF SHALL show "This PDF is password protected."

#### Scenario: Locked PDF

- **WHEN** the user opens a password-protected PDF
- **THEN** the tab says the PDF is password protected

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

Highlight Selection (Ctrl+Cmd+H) SHALL cover each line of the current text selection with an opaque yellow highlight drawn by the host's view, clear the selection, and mark the document edited. With no selection it SHALL change nothing. Highlights SHALL stay pending until Cmd+S, follow the document rules for prompts and crash recovery, and disappear on Don't Save.

#### Scenario: Highlight across two lines

- **WHEN** the user selects text spanning two lines and presses Ctrl+Cmd+H
- **THEN** both lines are highlighted and the window shows the edited mark

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
