## MODIFIED Requirements

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

## ADDED Requirements

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
