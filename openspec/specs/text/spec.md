# text Specification

## Purpose

The Plain Text plugin: view and quickly edit text files such as notes, logs, config and source code, keeping their encoding and line endings exactly as they were, fast on small files and usable on a 90 MB log.

## Requirements

### Requirement: Opens text and untyped files routed to it

The plugin SHALL open plain text and everything macOS types as plain text (logs, CSV, source code, extensionless files like `LICENSE`), plus JSON, XML, YAML and TOML, and untyped files the config routes to it. A file that isn't text (it holds NUL bytes and isn't UTF-16, or decodes in no supported encoding) SHALL show "This doesn't look like a text file." in its tab.

#### Scenario: Binary file routed to text

- **WHEN** `open.none = text` routes an extensionless binary file to the plugin
- **THEN** the tab says the file doesn't look like a text file

### Requirement: Detects the encoding exactly

The plugin SHALL detect UTF-8 with or without a byte-order mark, UTF-16 little or big endian with a byte-order mark, and then Windows-1252 or Mac Roman. A legacy encoding SHALL be chosen only if the text encodes back to exactly the original bytes, so saving without edits can never change the file.

#### Scenario: Windows-1252 file

- **WHEN** the user opens a file saved in Windows-1252
- **THEN** its accented characters show correctly and the info panel says Western (Windows Latin 1)

### Requirement: Shows text in a native, monospaced view

The text SHALL appear in a native text view in the system monospaced font, with the native find bar (Cmd+F, Cmd+G), lines wrapped by default, Wrap Lines (Opt+Cmd+W) to toggle wrapping, and Zoom In and Zoom Out (Cmd+= and Cmd+-) for the font size. The sidebar SHALL show the line count, the encoding (noting a byte-order mark), the dominant line ending and the file size.

#### Scenario: Toggling wrap on a long line

- **WHEN** the user turns Wrap Lines off on a file with a long line
- **THEN** the line runs on to the right and the view scrolls horizontally

### Requirement: Editing keeps the file's format

Text files SHALL be editable in document windows, with undo and redo. Saving SHALL write the text in the file's original encoding and byte-order mark, write every line break as the file's dominant line ending, and keep the trailing newline as it is in the text. A save with no change to the text SHALL write nothing, so a file with mixed line endings stays byte for byte the same.

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
