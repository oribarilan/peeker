## ADDED Requirements

### Requirement: A tab keeps a history of followed links

Each Editor tab SHALL keep a history of the places links took it: the file it opened at, then each heading or file a followed link reached. Back and Forward SHALL move through it, any number of steps, returning to each place at the scroll position it was left at and with the plugin it was shown with. Following a link after going Back SHALL drop the places ahead. The window's title, proxy icon and Open With SHALL follow the file shown.

#### Scenario: Back to the previous file

- **WHEN** the user scrolls halfway down `README.md`, follows a link to `other.md`, then goes Back
- **THEN** the tab shows `README.md` again, scrolled halfway down, titled `README.md`

#### Scenario: Several steps

- **WHEN** the user follows `#install`, then `other.md`, then goes Back twice and Forward once
- **THEN** the tab shows `README.md` at Install

#### Scenario: A new jump drops the places ahead

- **WHEN** the user goes from `README.md` to `a.md`, goes Back, then follows a link to `b.md`
- **THEN** Forward is unavailable and `a.md` is no longer in the history

#### Scenario: A place whose file is gone

- **WHEN** the user goes Back to a file that was deleted since
- **THEN** Peeker beeps and the tab stays where it was

### Requirement: History lasts as long as the tab

A tab's history SHALL end when the tab closes. It SHALL not be saved: after a quit or a crash, a reopened file and a window brought back by crash recovery SHALL start with no history.

#### Scenario: After a crash

- **WHEN** the user follows links in a tab, edits the file the tab shows, and the app is killed
- **THEN** on the next launch that file reopens with the edits and with Back unavailable

### Requirement: Back and Forward controls

An Editor window SHALL show Back and Forward as toolbar buttons at the leading end, after the sidebar button, while its document follows links or its tab has history. Go > Back (Cmd-[) and Go > Forward (Cmd-]) SHALL do the same. Each SHALL be greyed out, not hidden, when there's no place in its direction, and the Go items SHALL be greyed out when no Editor window is in front.

#### Scenario: A freshly opened file

- **WHEN** the user opens a Markdown file
- **THEN** the toolbar shows Back and Forward greyed out, and so are Go > Back and Go > Forward

#### Scenario: After a jump

- **WHEN** the user follows a heading link and presses Cmd-[
- **THEN** the view returns to where it was, and Forward becomes available

#### Scenario: A document that doesn't follow links

- **WHEN** a PDF is open in the Editor
- **THEN** its toolbar has no Back or Forward buttons, and Go > Back and Go > Forward are greyed out

### Requirement: The history trail

While a tab's history holds more than one place, a one-line trail SHALL show under the toolbar listing every place in order, the current one marked: a heading by its title, a file by its name. Clicking a crumb SHALL go to that place as Back or Forward would. When the trail doesn't fit, the oldest crumbs SHALL be cut first; each crumb's tooltip SHALL give its file name and heading.

#### Scenario: The trail after two jumps

- **WHEN** the user follows `#install` in `README.md` and then a link to `other.md`
- **THEN** the trail reads `README.md › Install › other.md` with `other.md` marked

#### Scenario: Clicking a crumb

- **WHEN** the user clicks the `README.md` crumb in that trail
- **THEN** the tab shows `README.md` where it was left, and the trail still lists all three with `README.md` marked

#### Scenario: No history

- **WHEN** a file has just opened in a tab
- **THEN** no trail shows

### Requirement: Leaving a file through a link asks about unsaved edits

When a link, Back, Forward or a crumb would show another file in a tab whose document has unsaved edits, Peeker SHALL first ask Save, Don't Save (Cmd+D) or Cancel, with the sheet closing the tab shows. Cancel SHALL keep the file, its edits and the history as they were. Moving within the same file SHALL never ask.

#### Scenario: Cancel stays

- **WHEN** the user types in `README.md`, Cmd-clicks a link to `other.md`, and chooses Cancel
- **THEN** the tab still shows `README.md` with the typing, and Back is as it was

#### Scenario: Don't Save goes on

- **WHEN** the user chooses Don't Save at that prompt
- **THEN** the tab shows `other.md`, and going Back shows `README.md` as last saved

#### Scenario: A heading in the same file

- **WHEN** the user has unsaved edits and follows a `#install` link
- **THEN** the view moves to Install without asking

### Requirement: A file open elsewhere comes forward

When a link, Back, Forward or a crumb would show a file in a tab while another Editor window already has that file open, that window SHALL come forward instead, and the tab and its history SHALL stay as they were.

#### Scenario: Linked file already open

- **WHEN** `other.md` is open in one tab and the user follows a link to it from `README.md` in another
- **THEN** the `other.md` tab comes forward and the `README.md` tab is unchanged
