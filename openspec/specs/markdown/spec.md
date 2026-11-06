# markdown Specification

## Purpose

The Markdown plugin: edit `.md` files in a window as source styled while you type, show them rendered in the Peek panel and in print, with an outline to jump around and task boxes that tick as an edit.

## Requirements

### Requirement: Renders Markdown with native text

The Peek panel SHALL show Markdown files rendered: headings, paragraphs with bold, italic, inline code and strikethrough, ordered and unordered lists, task lists, code blocks, block quotes, horizontal rules and tables. Images on this Mac SHALL appear as pictures and every other image as its alt text in brackets, as the image requirements below describe. A file that isn't text SHALL show an error.

#### Scenario: A README

- **WHEN** the user presses Space on a README with headings, a list and a code block
- **THEN** the Peek panel shows it rendered, with the code block in a monospaced font and no `#` before the headings

#### Scenario: A README with a screenshot

- **WHEN** the user presses Space on a README with `![Main window](docs/window.png)` and that file exists
- **THEN** the Peek panel shows the screenshot as a picture where the image is written, not `[Main window]`

### Requirement: Links open outside the app

In the Editor a plain click on a link SHALL place the cursor, and Cmd-click SHALL follow it; in the Peek panel a click SHALL follow it. A web link (`http:` or `https:`) or an email link (`mailto:`) SHALL open with the system's default handler. Any other scheme, such as `file:` or another app's own, SHALL first ask, showing the address, and open only after Open. A link without a scheme SHALL be followed inside Peeker, as a heading link or a link to a file.

#### Scenario: Web link

- **WHEN** the user Cmd-clicks a link to a web page in the Editor
- **THEN** the page opens in the default browser

#### Scenario: Editing a link

- **WHEN** the user clicks a link in the Editor without Cmd
- **THEN** the cursor lands in the link text and nothing opens

#### Scenario: Link to another app

- **WHEN** the user Cmd-clicks a `file:` link or a link with another app's scheme
- **THEN** Peeker asks whether to open it, showing the address, and opens it only after Open

#### Scenario: Relative link

- **WHEN** the user Cmd-clicks a link to `other.md` in the Editor
- **THEN** Peeker follows it inside the app instead of doing nothing

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

When the Peek panel or the Editor shows a long Markdown file, it SHALL draw the first part of the document before the rest, so the top shows without waiting for the whole document. In the Editor, a file over 64 KB SHALL open from a parse of its start, with the outline and counts completing once the rest is parsed.

#### Scenario: Long document

- **WHEN** the user presses Space on an 844 KB Markdown file
- **THEN** the top of the document is drawn first and the rest follows on the next turn of the run loop

#### Scenario: Long document in the Editor

- **WHEN** the user opens an 864 KB Markdown file in a window
- **THEN** the window shows the top styled without waiting for the whole file, and shortly after the outline lists every heading

### Requirement: Opening Markdown is at least as fast as TextEdit

Opening a Markdown file with the app not running SHALL draw its styled source in the Editor no later than TextEdit shows its window for the same file: faster, or within 10%. The benchmark measures this on 1 KB and 844 KB files.

#### Scenario: 1 KB Markdown

- **WHEN** the benchmark opens the 1 KB Markdown fixture in Peeker and in TextEdit
- **THEN** Peeker's content time is lower than TextEdit's window time, or at most 10% higher

### Requirement: Print Markdown

Printing a Markdown file SHALL print it rendered, as the Peek panel shows it, unsaved edits included, in the light appearance (dark text on white, code blocks in the System theme's light syntax colors) whatever the system appearance, wrapped to the page width across as many pages as it takes. Each page SHALL carry the system's header and footer: the file's name, the date and the page number.

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

### Requirement: The cursor starts at the top

A Markdown file SHALL open in the Editor with the cursor at the start of the text, and the outline SHALL mark the heading that section belongs to.

#### Scenario: Opening a long file

- **WHEN** the user opens a Markdown file with 4,000 headings
- **THEN** the cursor is at the start, the outline marks the first heading and shows the top of the list

### Requirement: Actual Size in the Markdown Editor

Actual Size (Cmd+0) SHALL put the Markdown Editor's text back at the default size, 14 points for body text, every style together, and that size SHALL be remembered like any other. It SHALL be listed in the View menu only, with no toolbar button. The Markdown Editor SHALL NOT offer Zoom to Fit, since its text always wraps to the window's width.

#### Scenario: Back to the default size

- **WHEN** the user presses Cmd+= twice in a Markdown window and then Cmd+0
- **THEN** body text is at 14 points and headings at their sizes for it, and View lists Zoom In, Zoom Out and Actual Size but no Zoom to Fit

### Requirement: Local images show as pictures

In the Peek panel and in print, an image whose source is a path relative to the Markdown file's folder, an absolute path or a `file:` URL SHALL show as a picture. A picture SHALL scale down to fit the text width, keeping its proportions, and SHALL never be drawn larger than its pixel size, one point per pixel. The Editor SHALL keep showing the image's Markdown source.

#### Scenario: A relative path

- **WHEN** `notes/plan.md` contains `![chart](img/chart.png)` and `notes/img/chart.png` exists
- **THEN** the Peek panel shows that chart as a picture

#### Scenario: A wide picture

- **WHEN** the image is 3000 pixels wide and the text is 600 points wide
- **THEN** the picture is drawn 600 points wide with its height scaled to match, and it narrows or widens with the panel up to 3000 points

#### Scenario: A small picture

- **WHEN** the image is 120 by 40 pixels
- **THEN** the picture is drawn 120 by 40 points, however wide the text is

#### Scenario: Printing

- **WHEN** the user prints a Markdown file with a local image from the Editor
- **THEN** the printout shows the picture, fitted to the page width

#### Scenario: The Editor

- **WHEN** the user opens the same file in a window
- **THEN** the window shows the line `![chart](img/chart.png)` as styled source, with no picture

### Requirement: Web images are never fetched

An image whose source is a web address (`http:` or `https:`), a `data:` URI or any scheme other than `file:` SHALL show its alt text in brackets, as before, and opening or printing the file SHALL never fetch it or reach the network for it.

#### Scenario: A badge

- **WHEN** a README contains `![build](https://example.com/badge.svg)`
- **THEN** the Peek panel shows `[build]` and makes no network request

### Requirement: Images that can't show keep their alt text

An image SHALL show its alt text in brackets when its file is missing, isn't a regular file, can't be read, isn't a picture the system can decode, is over 20 MB or 50 megapixels, is an iCloud file not yet downloaded, sits in a table cell, or comes after the document's 50th picture. A missing image SHALL never show an error or a broken-picture mark.

#### Scenario: A missing file

- **WHEN** a file contains `![diagram](diagram.png)` and no `diagram.png` sits beside it
- **THEN** the Peek panel shows `[diagram]` as it did before

#### Scenario: Not a picture

- **WHEN** an image's source points at a text file or a folder
- **THEN** the Peek panel shows its alt text in brackets

#### Scenario: Many images

- **WHEN** a file has 60 local images that all exist
- **THEN** the first 50 show as pictures and the last 10 show their alt text

### Requirement: Pictures never hold up the text

The Peek panel SHALL draw a Markdown file's text without waiting for its pictures to decode, with each picture's space already laid out so the text doesn't move when it arrives. Pictures SHALL decode off the main thread, at no more pixels than they are drawn at, and SHALL stop decoding when the panel closes. Opening a file without local images SHALL do no extra work.

#### Scenario: Large pictures

- **WHEN** the user presses Space on a file with five large photos referenced by relative paths
- **THEN** the text shows first and each photo appears in its place as it decodes, without the text below it moving

#### Scenario: Closing early

- **WHEN** the user closes the Peek panel while pictures are still decoding
- **THEN** the remaining pictures aren't decoded

### Requirement: Heading links go to the heading

A link that is `#` followed by a name SHALL go to the heading in the same file whose name matches, ignoring case, after decoding percent escapes. In the Editor the cursor SHALL move to the start of the heading's line and the view SHALL scroll to it; in the Peek panel the view SHALL scroll to it. A name that matches no heading SHALL beep and move nothing. HTML anchors such as `<a id="x">` SHALL not count as headings.

#### Scenario: Jumping to a section

- **WHEN** the user Cmd-clicks `[see install](#install)` in a file with a `## Install` heading
- **THEN** the view scrolls to Install and the cursor sits at the start of its line

#### Scenario: No such heading

- **WHEN** the user Cmd-clicks a link to `#missing` in a file with no heading of that name
- **THEN** Peeker beeps and the view and cursor stay where they were

#### Scenario: An HTML anchor

- **WHEN** the file has `<a id="top"></a>` and no heading named top, and the user follows `#top`
- **THEN** Peeker beeps

### Requirement: Headings are named by GitHub's rule

A heading's name SHALL be its text as shown, lowercased, with each space turned into a hyphen and every character other than letters, digits, hyphens and underscores dropped. When two headings get the same name, the second SHALL get `-1` added, the third `-2`, and so on, in the order they appear.

#### Scenario: Punctuation

- **WHEN** a file has the heading `## What's new?`
- **THEN** a link to `#whats-new` goes to it

#### Scenario: Code and emphasis

- **WHEN** a file has the heading ``## The `peek` **command**``
- **THEN** a link to `#the-peek-command` goes to it

#### Scenario: Repeated headings

- **WHEN** a file has two `## Notes` headings
- **THEN** `#notes` goes to the first and `#notes-1` to the second

### Requirement: Links to Markdown files open in the same tab

A link without a scheme that names a path SHALL be resolved against the folder of the file it is in, after decoding percent escapes; a path starting with `/` SHALL start at the disk's root. In the Editor, a link to a file the Markdown plugin opens SHALL show that file in the same tab, at the heading its `#name` names, or else at the top. A link to the file itself SHALL act as a heading link, or do nothing without a `#name`. A link to a file that doesn't exist SHALL beep.

#### Scenario: Another Markdown file

- **WHEN** the user Cmd-clicks `[guide](docs/guide.md)` in `README.md`
- **THEN** the same tab shows `docs/guide.md` from the top, and no new tab opens

#### Scenario: A heading in another file

- **WHEN** the user Cmd-clicks `[setup](../other.md#setup)`
- **THEN** the tab shows `other.md`, the folder above, scrolled to its Setup heading

#### Scenario: A name with spaces

- **WHEN** the user Cmd-clicks `[notes](my%20notes.md)` and `my notes.md` exists next to the file
- **THEN** the tab shows `my notes.md`

#### Scenario: Missing file

- **WHEN** the user Cmd-clicks a link to `gone.md` and no such file exists
- **THEN** Peeker beeps and the tab stays as it was

### Requirement: Links to other files open outside the tab

A link without a scheme to an existing file the Markdown plugin doesn't open SHALL open in Peeker in its own tab when an enabled plugin opens it. Otherwise, a folder included, Peeker SHALL first ask, as for a `file:` link, showing the path, and open it in its default app only after Open. Neither SHALL change the tab the link was in or its history.

#### Scenario: A text file

- **WHEN** the user Cmd-clicks `[log](./notes/a.txt)`
- **THEN** `a.txt` opens in Plain Text in a new tab, and the Markdown tab is unchanged

#### Scenario: A file no plugin opens

- **WHEN** the user Cmd-clicks a link to `report.numbers`, which no enabled plugin opens
- **THEN** Peeker asks whether to open it, showing its path, and opens it in its default app only after Open

### Requirement: Links in the Peek panel

In the Peek panel a heading link SHALL scroll to the heading. A link to another existing file SHALL close the panel and open the file in an Editor window, as Open in Peeker does, at the heading its `#name` names; a file no plugin opens SHALL ask first, as in the Editor. A missing file or heading SHALL beep. The panel SHALL keep no history.

#### Scenario: Heading link in the panel

- **WHEN** the user clicks a `#install` link in the Peek panel
- **THEN** the panel scrolls to Install and Finder keeps the keyboard

#### Scenario: File link in the panel

- **WHEN** the user clicks `[setup](other.md#setup)` in the Peek panel
- **THEN** the panel closes and `other.md` opens in an Editor window, scrolled to Setup

### Requirement: Markdown text size is remembered

The Markdown Editor SHALL remember its text size across files and launches: a zoom in any window SHALL apply to every Markdown file opened after it, in a window or the Peek panel. Files already open SHALL keep their own until changed.

#### Scenario: Reading at a larger size

- **WHEN** the user zooms in twice in a Markdown window, quits Peeker and later presses Space on another Markdown file
- **THEN** the Peek panel shows it at the larger size
