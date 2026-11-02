## MODIFIED Requirements

### Requirement: Slow file work never freezes the app

Reading, decoding and saving a file SHALL run off the main thread. While a file opens in a document window and nothing of it shows yet, a spinner SHALL appear in the middle of the content once the open has taken about half a second, and go away when the file or its failure appears. An open that finishes sooner SHALL never show it, and the Peek panel SHALL show none. The rest of the app SHALL keep responding.

#### Scenario: Opening a large log

- **WHEN** the user opens an 86 MB log and immediately switches to another tab
- **THEN** the other tab responds at once, and the log appears when it's ready

#### Scenario: A slow open shows a spinner

- **WHEN** opening a file in a document window takes two seconds
- **THEN** a spinner shows in the middle of the empty content from about half a second on, and goes away when the file appears

#### Scenario: A fast open shows none

- **WHEN** a file opens in under half a second
- **THEN** no spinner is ever drawn

#### Scenario: A failed open replaces the spinner

- **WHEN** a slow open fails
- **THEN** the spinner goes away and the failure shows in its place

### Requirement: Closing cancels pending work

Closing a tab or window, or moving the Peek panel to another file, SHALL cancel that document's open in progress, and nothing from it SHALL be applied afterwards.

#### Scenario: Browsing past a large photo

- **WHEN** the Peek panel starts opening a 48 MP photo and the user presses the down arrow
- **THEN** the panel shows the next file, and the photo never replaces it

### Requirement: Print from document windows

The File menu SHALL have Print (Cmd+P). In a document window it SHALL show the system print panel for the current document, as a sheet on the window, with the file's name as the job title. What prints SHALL be decided by the document's plugin and SHALL include unsaved edits, and typing in progress (such as in a PDF text box) SHALL count. Print SHALL be unavailable when no document window is in front, while the document is still opening or failed to open, and for a plugin that offers no printing.

#### Scenario: Printing a document
- **WHEN** the user presses Cmd+P in a document window showing an opened file
- **THEN** the system print panel opens as a sheet on that window, titled with the file's name

#### Scenario: Unsaved edits print
- **WHEN** a document has unsaved edits and the user prints it
- **THEN** the printout shows the document with those edits

#### Scenario: Nothing to print
- **WHEN** the front window is the Peek panel or the Settings window, or the document is still opening
- **THEN** Print is greyed out
