# markdown Specification

## Purpose

The Markdown plugin: show `.md` files rendered, with an outline to jump around and task checkboxes that can be ticked straight from the rendered view.

## Requirements

### Requirement: Renders Markdown with native text

The plugin SHALL open UTF-8 Markdown files and show them rendered: headings, paragraphs with bold, italic, inline code and strikethrough, ordered and unordered lists, task lists, code blocks, block quotes, horizontal rules and tables. Images SHALL appear as their alt text in brackets, not as pictures. A file that isn't valid UTF-8 SHALL show an error in its tab.

#### Scenario: A README

- **WHEN** the user opens a README with headings, a list and a code block
- **THEN** it appears rendered, with the code block in a monospaced font

### Requirement: Links open outside the app

Clicking a web link (`http:` or `https:`) or an email link (`mailto:`) SHALL open it with the system's default handler. A link with any other scheme, such as `file:` or another app's own, SHALL first ask, showing the address, and open only if the user chooses Open, since one click in a downloaded file could otherwise start an app. A link without a scheme SHALL do nothing.

#### Scenario: Web link

- **WHEN** the user clicks a link to a web page
- **THEN** the page opens in the default browser

#### Scenario: Link to another app

- **WHEN** the user clicks a `file:` link or a link with another app's scheme
- **THEN** Peeker asks whether to open it, showing the address, and opens it only after Open

### Requirement: Outline and info in the sidebar

The sidebar SHALL list the document's headings, and clicking one SHALL scroll to it. It SHALL also show the word count and, when the file has tasks, how many are done out of the total.

#### Scenario: Jumping to a section

- **WHEN** the user clicks a heading in the outline
- **THEN** the view scrolls to that heading

### Requirement: Task checkboxes toggle in the file immediately

Clicking a task checkbox SHALL flip that task in the file on disk at once, without Cmd+S, changing only that line, and SHALL re-render the document. The write SHALL be atomic and keep the file's permissions and symlinks.

#### Scenario: Ticking a task

- **WHEN** the user clicks the empty checkbox of `- [ ] buy milk`
- **THEN** the line in the file becomes `- [x] buy milk`, no other byte changes, and the view shows it ticked

### Requirement: The first screen appears before the rest

On open, the plugin's view SHALL draw the first part of the document before laying out the rest, so a long file shows its top without waiting for the whole document.

#### Scenario: Long document

- **WHEN** the user opens an 844 KB Markdown file
- **THEN** the top of the document is drawn first and the rest follows on the next turn of the run loop

### Requirement: Opening Markdown is at least as fast as TextEdit

Opening a Markdown file with the app not running SHALL draw its rendered content no later than TextEdit shows its window for the same file: faster, or within 10%. The benchmark measures this on 1 KB and 844 KB files.

#### Scenario: 1 KB Markdown

- **WHEN** the benchmark opens the 1 KB Markdown fixture in Peeker and in TextEdit
- **THEN** Peeker's content time is lower than TextEdit's window time, or at most 10% higher

### Requirement: Print Markdown

Printing a Markdown file SHALL print it rendered, as the window shows it, but in the light appearance (dark text on white) whatever the system appearance, wrapped to the page width across as many pages as it takes. Each page SHALL carry the system's header and footer: the file's name, the date and the page number.

#### Scenario: Rendered, not source
- **WHEN** the user prints a file with a `# Title` heading
- **THEN** the printout shows "Title" as a heading, without the `#`

#### Scenario: Dark mode
- **WHEN** the system is in dark mode and the user prints a Markdown file
- **THEN** the printout uses dark text on white
