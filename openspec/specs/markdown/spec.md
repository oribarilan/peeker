# markdown Specification

## Purpose

The Markdown plugin: edit `.md` files in a window as source styled while you type, show them rendered in the Peek panel and in print, with an outline to jump around and task boxes that tick as an edit.

## Requirements

### Requirement: Renders Markdown with native text

The Peek panel SHALL show Markdown files rendered: headings, paragraphs with bold, italic, inline code and strikethrough, ordered and unordered lists, task lists, code blocks, block quotes, horizontal rules and tables. Images SHALL appear as their alt text in brackets, not as pictures. A file that isn't text SHALL show an error.

#### Scenario: A README

- **WHEN** the user presses Space on a README with headings, a list and a code block
- **THEN** the Peek panel shows it rendered, with the code block in a monospaced font and no `#` before the headings

### Requirement: Links open outside the app

In the Editor a plain click on a link SHALL place the cursor, and Cmd-click SHALL open it; in the Peek panel a click SHALL open it. A web link (`http:` or `https:`) or an email link (`mailto:`) SHALL open with the system's default handler. Any other scheme, such as `file:` or another app's own, SHALL first ask, showing the address, and open only after Open. A link without a scheme SHALL do nothing.

#### Scenario: Web link

- **WHEN** the user Cmd-clicks a link to a web page in the Editor
- **THEN** the page opens in the default browser

#### Scenario: Editing a link

- **WHEN** the user clicks a link in the Editor without Cmd
- **THEN** the cursor lands in the link text and nothing opens

#### Scenario: Link to another app

- **WHEN** the user Cmd-clicks a `file:` link or a link with another app's scheme
- **THEN** Peeker asks whether to open it, showing the address, and opens it only after Open

### Requirement: Outline and info in the sidebar

The sidebar SHALL list the document's headings; a row SHALL highlight while the pointer is over it, and clicking one SHALL put the cursor at the start of that heading's line and scroll to it. In the Editor the outline SHALL mark the heading of the section the cursor is in, following the cursor as it moves. The sidebar SHALL also show the word count and, when the file has tasks, how many are done out of the total. While the user types, the outline and counts SHALL refresh after a short pause.

#### Scenario: Jumping to a section

- **WHEN** the user clicks a heading in the outline
- **THEN** the view scrolls to that heading, the cursor sits at the start of its line, and the heading is marked

#### Scenario: A new heading

- **WHEN** the user types a new `## Notes` line in the Editor
- **THEN** Notes appears in the outline shortly after, without saving

#### Scenario: Hovering a heading

- **WHEN** the pointer moves over a heading in the outline
- **THEN** that row highlights, and the highlight goes when the pointer leaves

#### Scenario: The cursor's section

- **WHEN** the cursor moves from the text under `# One` into the text under `## Two`
- **THEN** the outline's mark moves from One to Two

#### Scenario: Before the first heading

- **WHEN** the cursor is in text above the first heading
- **THEN** no heading is marked

### Requirement: The first screen appears before the rest

When the Peek panel renders a long Markdown file, it SHALL draw the first part of the document before laying out the rest, so the top shows without waiting for the whole document.

#### Scenario: Long document

- **WHEN** the user presses Space on an 844 KB Markdown file
- **THEN** the top of the document is drawn first and the rest follows on the next turn of the run loop

### Requirement: Opening Markdown is at least as fast as TextEdit

Opening a Markdown file with the app not running SHALL draw its styled source in the Editor no later than TextEdit shows its window for the same file: faster, or within 10%. The benchmark measures this on 1 KB and 844 KB files.

#### Scenario: 1 KB Markdown

- **WHEN** the benchmark opens the 1 KB Markdown fixture in Peeker and in TextEdit
- **THEN** Peeker's content time is lower than TextEdit's window time, or at most 10% higher

### Requirement: Print Markdown

Printing a Markdown file SHALL print it rendered, as the Peek panel shows it, unsaved edits included, in the light appearance (dark text on white) whatever the system appearance, wrapped to the page width across as many pages as it takes. Each page SHALL carry the system's header and footer: the file's name, the date and the page number.

#### Scenario: Rendered, not source
- **WHEN** the user prints a file with a `# Title` heading
- **THEN** the printout shows "Title" as a heading, without the `#`

#### Scenario: Unsaved edits
- **WHEN** the user types a new paragraph in the Editor and prints without saving
- **THEN** the printout includes the new paragraph

#### Scenario: Dark mode
- **WHEN** the system is in dark mode and the user prints a Markdown file
- **THEN** the printout uses dark text on white

### Requirement: The Editor shows Markdown as styled source

In the Editor a Markdown file SHALL show its source text, editable, with undo and redo. The source SHALL be styled as it is typed: headings larger and bold, bold and italic text styled, code in the monospaced font on a tinted background, links colored, and markers (`#`, `**`, list markers, fences, link brackets) visible but dimmed. Prose SHALL use the system font, and colors SHALL follow the system appearance.

#### Scenario: Opening a README

- **WHEN** the user opens a README with a `# Title` heading and a bold word in the Editor
- **THEN** the window shows `# Title` in a large bold font with the `#` dimmed, and the `**` around the word dimmed while the word is bold

#### Scenario: Typing a heading

- **WHEN** the user types `## ` at the start of a plain line
- **THEN** the line takes the heading style, and the window is marked edited

### Requirement: Find and zoom in the Markdown Editor

The Markdown Editor SHALL offer the native find bar (Cmd+F, Cmd+G) and Zoom In and Zoom Out (Cmd+= and Cmd+-), which scale every style together. Text SHALL always wrap to the window's width.

#### Scenario: Zooming in

- **WHEN** the user presses Cmd+= in a Markdown window
- **THEN** body text and headings both grow, and headings stay larger than the body

### Requirement: Editing Markdown keeps the file's format

The plugin SHALL read Markdown in the encodings Plain Text detects. Saving SHALL write the text in the file's encoding, byte-order mark and dominant line ending, a save with no change to the text SHALL write nothing, and text the encoding can't hold SHALL offer Save as UTF-8 or Cancel, never substituting characters.

#### Scenario: A Windows-1252 file

- **WHEN** the user opens a Markdown file saved in Windows-1252, edits a word and saves
- **THEN** its accented characters showed correctly, and the file is still Windows-1252 with its line endings

#### Scenario: Saving without changes

- **WHEN** the user types a character, deletes it and saves
- **THEN** the file on disk is unchanged

### Requirement: Task boxes toggle as an edit

In the Editor, clicking the box of a task (`[ ]` or `[x]` after a list marker) SHALL flip it, as an ordinary edit: the window is marked edited, Undo flips it back, and only Cmd+S writes it. In a read-only file a click SHALL change nothing. The Peek panel SHALL show task boxes ticked or not, without reacting to clicks.

#### Scenario: Ticking a task

- **WHEN** the user clicks the box in `- [ ] buy milk` in the Editor
- **THEN** the line reads `- [x] buy milk`, the window is marked edited, and the file on disk is unchanged until Cmd+S

#### Scenario: The Peek panel

- **WHEN** the user clicks a task box in the Peek panel
- **THEN** nothing changes, in the panel or in the file

### Requirement: Large Markdown files

Markdown files SHALL follow Plain Text's limits: over 10 MB the file opens read-only with the reason, and over 16 MB only its first part shows. Above 1 MB the source SHALL open unstyled, still editable when within the limits, with the outline updated only when the file opens or reloads.

#### Scenario: A 3 MB file

- **WHEN** the user opens a 3 MB Markdown file in the Editor
- **THEN** it shows as plain source in the system font, and typing into it works and marks it edited

#### Scenario: A 12 MB file

- **WHEN** the user opens a 12 MB Markdown file
- **THEN** a note under the toolbar says it's read-only because it's over 10 MB, and typing changes nothing

### Requirement: Unsaved Markdown edits survive a crash

Unsaved Markdown edits SHALL go into the crash-recovery copy and come back on the next launch like any other document's. When the file is gone, its text SHALL be offered the way recovered text always is.

#### Scenario: Killed with unsaved typing

- **WHEN** the user types into a Markdown file and the app is killed before saving
- **THEN** on the next launch the file reopens in the Editor with the typing, marked edited
