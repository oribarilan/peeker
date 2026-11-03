## Purpose

Coloring code by its syntax, in Plain Text files and in Markdown's fenced code blocks, with colors from the text theme.

## ADDED Requirements

### Requirement: Code files are colored by language

Plain Text SHALL color a file whose language it knows: by extension, or for a file without one, by a `#!` first line naming the interpreter. It SHALL know Python, JavaScript and TypeScript with JSX/TSX, Swift, C, C++, Objective-C, Go, Rust, Java, Kotlin, Ruby, Perl, shell (sh, bash, zsh, fish), SQL, CSS, SCSS, JSON, JSONC, YAML, TOML and INI-style config. Text, logs, CSV, TSV, XML and diffs SHALL stay plain.

#### Scenario: A Python file

- **WHEN** the user opens `tool.py`
- **THEN** its keywords, strings, comments, numbers, types and function names show in the theme's syntax colors

#### Scenario: A script without an extension

- **WHEN** the user opens `deploy` whose first line is `#!/usr/bin/env bash`
- **THEN** it's colored as shell

#### Scenario: A log

- **WHEN** the user opens `server.log`
- **THEN** it shows in the plain text color

### Requirement: What gets colored

Coloring SHALL mark six kinds of text: keywords, strings, comments, numbers and constants, type names, and function names; everything else SHALL keep the body text color. Syntax a language's rules can't follow simply, such as heredocs, raw or nested string templates, regex literals and JSX tags, SHALL be left uncolored rather than colored wrongly across lines where avoidable.

#### Scenario: A string with an escaped quote

- **WHEN** a Swift file has `"say \"hi\" // not a comment"`
- **THEN** the whole literal is colored as a string and nothing in it as a comment

### Requirement: Markdown colors tagged code blocks

A fenced code block in a Markdown file whose tag names a known language SHALL have its code colored, in the Editor's styled source and in the Peek panel. An untagged block, or one with an unknown tag, SHALL look as before.

#### Scenario: A Python block

- **WHEN** a Markdown file has a block fenced with ```` ```python ````
- **THEN** its keywords and strings show in the theme's syntax colors in the Editor and in the Peek panel

### Requirement: Coloring stays off the open path

Coloring SHALL never delay showing a file or typing in it: it SHALL run off the main thread, color the first screen before the rest, and color again shortly after typing pauses. Files over 1 MB SHALL stay plain. Changing the theme SHALL recolor code at once.

#### Scenario: A 1 MB source file

- **WHEN** the user opens a 1 MB Swift file
- **THEN** the window shows as fast as it does for plain text, with the top colored at once and the rest moments later

#### Scenario: Typing

- **WHEN** the user types `def ` at the start of a line in a Python file
- **THEN** `def` takes the keyword color shortly after typing pauses, and the window stays responsive

#### Scenario: A large file

- **WHEN** the user opens a 3 MB JSON file
- **THEN** it shows in the plain text color

### Requirement: Printed code keeps its colors

Printing a code file, or a Markdown file with colored code blocks, SHALL print the code in the System theme's light syntax colors on white, whatever theme and appearance are chosen.

#### Scenario: Printing in Tokyo Night

- **WHEN** the theme is Tokyo Night and the user prints a Python file
- **THEN** the printout is on white, with keywords and strings in System's light colors
