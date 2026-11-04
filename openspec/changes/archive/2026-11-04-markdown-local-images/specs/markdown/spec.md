# Spec Delta

## MODIFIED Requirements

### Requirement: Renders Markdown with native text

The Peek panel SHALL show Markdown files rendered: headings, paragraphs with bold, italic, inline code and strikethrough, ordered and unordered lists, task lists, code blocks, block quotes, horizontal rules and tables. Images on this Mac SHALL appear as pictures and every other image as its alt text in brackets, as the image requirements below describe. A file that isn't text SHALL show an error.

#### Scenario: A README

- **WHEN** the user presses Space on a README with headings, a list and a code block
- **THEN** the Peek panel shows it rendered, with the code block in a monospaced font and no `#` before the headings

#### Scenario: A README with a screenshot

- **WHEN** the user presses Space on a README with `![Main window](docs/window.png)` and that file exists
- **THEN** the Peek panel shows the screenshot as a picture where the image is written, not `[Main window]`

## ADDED Requirements

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
