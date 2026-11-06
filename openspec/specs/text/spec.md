# text Specification

## Purpose

The Plain Text plugin: view and quickly edit text files such as notes, logs, config and source code, keeping their encoding and line endings exactly as they were, fast on small files and usable on a 90 MB log.

## Requirements

### Requirement: Opens the text files on its list

By default the plugin SHALL open plain text and logs (`txt`, `text`, `log`), structured data (`json`, `xml`, `yaml`, `yml`, `toml`), config files (`ini`, `conf`, `cfg`, `env`, `properties`), common source code and scripts, and files with no extension (`noExtension`). CSV and TSV files belong to the Table plugin. A file that isn't text (it holds NUL bytes and isn't UTF-16, or decodes in no supported encoding) SHALL show "This doesn't look like a text file." in its tab.

#### Scenario: Extensionless binary file

- **WHEN** the user opens a binary file that has no extension
- **THEN** the tab says the file doesn't look like a text file

#### Scenario: Config file macOS has no type for

- **WHEN** the user opens `nginx.conf`
- **THEN** Plain Text shows it, with no config needed

#### Scenario: A CSV still opens as text on request

- **WHEN** the user opens a `.csv` file and picks Plain Text from Open With
- **THEN** the tab shows the file as text

### Requirement: Detects the encoding exactly

The plugin SHALL detect UTF-8 with or without a byte-order mark, UTF-16 little or big endian with a byte-order mark, and then Windows-1252 or Mac Roman. A legacy encoding SHALL be chosen only if the text encodes back to exactly the original bytes, so saving without edits can never change the file.

#### Scenario: Windows-1252 file

- **WHEN** the user opens a file saved in Windows-1252
- **THEN** its accented characters show correctly and the info panel says Western (Windows Latin 1)

### Requirement: Shows text in a native, monospaced view

The text SHALL appear in a native text view in the system monospaced font, with the native find bar (Cmd+F, Cmd+G), lines wrapped by default, Wrap Lines in the View menu and the toolbar to toggle wrapping, and Zoom In and Zoom Out (Cmd+= and Cmd+-) for the font size. Wrap Lines SHALL show whether wrapping is on: checked in the menu and pressed in the toolbar. The sidebar SHALL show the line count, the encoding (noting a byte-order mark), the dominant line ending and the file size.

#### Scenario: Toggling wrap on a long line

- **WHEN** the user turns Wrap Lines off on a file with a long line
- **THEN** the line runs on to the right and the view scrolls horizontally

#### Scenario: Wrap state shows

- **WHEN** a text file opens with lines wrapped and the user then turns Wrap Lines off
- **THEN** View > Wrap Lines is checked at first, and unchecked after

#### Scenario: Wrap Lines has no default shortcut

- **WHEN** a text file is in front and the config sets no shortcut for Wrap Lines
- **THEN** View > Wrap Lines shows no shortcut, and Opt+Cmd+W doesn't change wrapping

#### Scenario: A configured shortcut stays

- **WHEN** the config sets `plugins.text.tools.toggle-wrap.shortcut` to `opt+cmd+w`
- **THEN** Opt+Cmd+W toggles wrapping, and View > Wrap Lines shows it

### Requirement: Editing keeps the file's format

Text files SHALL be editable in the Editor, with undo and redo. Saving SHALL write the text in the file's original encoding and byte-order mark, write every line break as the file's dominant line ending, and keep the trailing newline as it is in the text. A save with no change to the text SHALL write nothing, so a file with mixed line endings stays byte for byte the same.

#### Scenario: Editing a CRLF file

- **WHEN** the user edits and saves a UTF-16 file with CRLF line endings and a byte-order mark
- **THEN** the file is still UTF-16 with the same byte-order mark and CRLF endings

#### Scenario: Saving without changes

- **WHEN** the user saves a file whose text they changed and then changed back
- **THEN** the file on disk is unchanged

### Requirement: Text that doesn't fit the encoding asks before converting

When edited text can't be written in the file's encoding (an emoji typed into a Windows-1252 file), the save SHALL ask whether to save as UTF-8 or cancel, and SHALL never substitute or drop characters.

#### Scenario: Emoji in a legacy file

- **WHEN** the user types an emoji into a Mac Roman file and saves
- **THEN** a sheet offers Save as UTF-8 or Cancel, and Save as UTF-8 writes UTF-8 without a byte-order mark

### Requirement: Large files stay responsive

Files over 10 MB SHALL open read-only with a note saying so. Text over 16 MB SHALL show only its first 16 MB, cut at a line break, with a note naming how much is shown out of the file's size; when a line in that part is longer than 1 MB, only the first 4 MB SHALL show. Opening a 90 MB log SHALL never stall the app.

#### Scenario: 86 MB log

- **WHEN** the user opens an 86 MB log
- **THEN** the first 16 MB appear without a stall, marked read-only, with a note saying how much of the file is shown

### Requirement: Opening text is at least as fast as TextEdit

Opening a text file with the app not running SHALL draw its content no later than TextEdit shows its window for the same file: faster, or within 10%. The benchmark measures this on 10 KB, 11 MB and 86 MB files.

#### Scenario: 10 KB text file

- **WHEN** the benchmark opens the 10 KB text fixture in Peeker and in TextEdit
- **THEN** Peeker's content time is lower than TextEdit's window time, or at most 10% higher

### Requirement: Print text

Printing a text file SHALL print the text in the window, unsaved edits included, in the window's font and size, black on white whatever the system appearance, with code colored in the System theme's light syntax colors, wrapped to the page width even when Wrap Lines is off, across as many pages as it takes. Each page SHALL carry the system's header and footer: the file's name, the date and the page number.

#### Scenario: Dark mode
- **WHEN** the system is in dark mode and the user prints a text file
- **THEN** the printout is black text on white

#### Scenario: Long lines with wrapping off
- **WHEN** Wrap Lines is off and a line is wider than the page
- **THEN** the line wraps on paper instead of being cut off

#### Scenario: Header
- **WHEN** the user prints `notes.txt`, which needs 3 pages
- **THEN** each page shows "notes.txt", the date and its page number

#### Scenario: A code file
- **WHEN** the user prints `tool.py` with the Tokyo Night theme
- **THEN** the text is on white, with keywords and strings in System's light syntax colors

### Requirement: The cursor starts at the top

A text file SHALL open with the cursor at the start of the text.

#### Scenario: Opening a file

- **WHEN** the user opens a text file in a window
- **THEN** the cursor is at the start of the first line

### Requirement: Actual Size in plain text

Actual Size (Cmd+0) SHALL put the text back at the default font size, 12 points, and that size SHALL be remembered like any other. It SHALL be listed in the View menu only, with no toolbar button. Plain text SHALL NOT offer Zoom to Fit.

#### Scenario: Back to the default size

- **WHEN** the user presses Cmd+= three times in a text file and then Cmd+0
- **THEN** the text is at 12 points, and View lists Zoom In, Zoom Out and Actual Size but no Zoom to Fit

### Requirement: Text size and wrapping are remembered

Plain text SHALL remember its font size and whether Wrap Lines is on, across files and launches: a change in any window SHALL apply to every text file opened after it, in a window or the Peek panel. Text files already open SHALL keep their own until changed.

#### Scenario: Reading logs unwrapped

- **WHEN** the user turns Wrap Lines off and zooms in twice in one log file, then quits Peeker and later opens another log
- **THEN** the other log opens unwrapped at the larger size

#### Scenario: A bad stored size

- **WHEN** the stored size is outside 6 to 72 points
- **THEN** text opens at the default 12 points
