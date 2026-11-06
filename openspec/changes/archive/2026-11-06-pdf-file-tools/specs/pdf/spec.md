# Spec Delta

## ADDED Requirements

### Requirement: Inserting pages from files

File > Insert Pages from File… and dropping PDFs or images from Finder onto the pages SHALL insert the other PDF's pages, or each image as a page of its size, after the last selected page, or after the page shown. Inserted pages SHALL be pending edits like other page tools: undoable, saved with Cmd+S or Save As…, and kept in the recovery copy.

#### Scenario: Combining two scans

- **WHEN** the user opens `scan 1.pdf`, inserts `scan 2.pdf` at the end and chooses Save As… with the name `scans.pdf`
- **THEN** `scans.pdf` has the pages of both, in that order, and `scan 1.pdf` is unchanged

#### Scenario: A photo as a page

- **WHEN** page 1 is shown and the user drops a JPEG onto the pages
- **THEN** a page showing the photo appears after page 1, and Undo takes it out

### Requirement: Saving selected pages

File > Save Selected Pages As… SHALL write the pages selected in the thumbnails, as shown with their unsaved edits, to a new PDF chosen in a sheet, and leave the window on its file.

#### Scenario: Pulling out an invoice

- **WHEN** the user selects pages 3 and 4 and saves them as `invoice.pdf`
- **THEN** `invoice.pdf` has those two pages and the window still shows the whole file

### Requirement: Splitting a PDF

File > Split… SHALL write one file per page, or one file per run of pages starting at each selected page, in the original's folder, named "<name> 1.pdf", "<name> 2.pdf" and on, never overwriting a file that exists. The window SHALL stay on its file.

#### Scenario: Splitting at chapters

- **WHEN** a 10-page `book.pdf` has pages 4 and 8 selected and the user splits at the selected pages
- **THEN** `book 1.pdf` has pages 1-3, `book 2.pdf` pages 4-7 and `book 3.pdf` pages 8-10

#### Scenario: A name that exists

- **WHEN** `book 1.pdf` already exists and the user splits every page
- **THEN** the first page goes to the next free name and `book 1.pdf` is untouched

### Requirement: File tools follow page permissions

Insert Pages from File…, Save Selected Pages As… and Split… SHALL be greyed out with the reason where page changes are, and absent from the Peek panel.

#### Scenario: A signed PDF

- **WHEN** a digitally signed PDF is in front
- **THEN** the three items are greyed out with the reason
