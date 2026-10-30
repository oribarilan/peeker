# plugin-host Specification

## Purpose

How the app finds its format plugins, runs them, and keeps working when one fails. Today each plugin runs as its own process and the host draws what it describes.

## Requirements

### Requirement: Plugins ship inside the app

The host SHALL load the plugins bundled in the app, each described by a manifest with an id, a display name and the file types it supports. The host SHALL read manifests without starting any plugin, and SHALL skip a plugin whose manifest can't be read, logging why, while loading the rest.

#### Scenario: A manifest is broken

- **WHEN** one plugin's manifest is missing or isn't valid JSON
- **THEN** that plugin is left out, the reason is logged, and the other plugins load normally

### Requirement: Each plugin runs in its own process, started on demand

A plugin SHALL run as a separate process that starts on the first request for it and is shared by every open document of that plugin. A plugin process with no open documents SHALL stop after the `plugin.idle` seconds from config (60 by default), and the next request SHALL start it again.

#### Scenario: Two documents of the same format

- **WHEN** the user opens two PDFs
- **THEN** both are served by a single PDF plugin process

#### Scenario: Idle plugin stops

- **WHEN** the last document of a plugin closes and `plugin.idle` seconds pass with none reopened
- **THEN** the plugin process exits, and opening another file of that type starts it again

### Requirement: Plugins describe content and the host draws it

A plugin SHALL NOT put anything on screen. It SHALL answer an open with a description of what to show: a content view of a kind the host provides (text, rendered Markdown, PDF, bitmap), sidebar panels, and commands. The host SHALL render that description with its own native views. A command the host's view can perform by itself (zoom, highlight) SHALL be handled by the host; any other command SHALL be sent back to the plugin.

#### Scenario: Highlighting a PDF selection

- **WHEN** the user runs Highlight Selection on a PDF
- **THEN** the host's PDF view draws the highlight without a round trip to the plugin

### Requirement: Large content travels outside the message pipe

Pixels and text too large for a message SHALL be handed over through a temporary shared file, never inside a message. The host SHALL validate such a file before using it, and SHALL delete one it never uses.

#### Scenario: Opening a large log

- **WHEN** the text plugin opens a 90 MB log
- **THEN** the decoded text reaches the host through a shared file, not a 90 MB message

### Requirement: A failing plugin never takes the app down

Every request to a plugin SHALL get exactly one answer. A plugin that crashes, sends a reply the host can't read, or misses its deadline (10 seconds for open and commands, 30 seconds for save) SHALL be stopped. Each of its documents SHALL then show an error message with a Reopen button in its own tab, while other tabs and the rest of the app keep working.

#### Scenario: Plugin crashes while opening

- **WHEN** the plugin process exits before replying to an open
- **THEN** the tab shows what happened and a Reopen button, and tabs of other plugins are unaffected

#### Scenario: Plugin hangs

- **WHEN** a plugin hasn't replied to an open 10 seconds after the request
- **THEN** the host kills the process and the tab shows that the plugin stopped responding

#### Scenario: Plugin sends garbage

- **WHEN** a plugin writes a line that isn't a valid reply
- **THEN** the host stops the plugin and fails its pending requests with a message instead of waiting forever

#### Scenario: Reopen after a failure

- **WHEN** the user clicks Reopen in a failed tab
- **THEN** the host starts the plugin again if needed and opens the file afresh

### Requirement: A plugin failure never loses unsaved edits

When a plugin fails while one of its documents has unsaved edits, the host SHALL keep the edits on screen instead of replacing them with the error view. The next save SHALL reopen the document in a fresh plugin process before sending the edits.

#### Scenario: Plugin crashes during editing

- **WHEN** the text plugin crashes while a document has unsaved edits
- **THEN** the edits stay in the window, and Cmd+S restarts the plugin and saves them

### Requirement: Plugin output is logged

The host SHALL log through the unified system log under the app's bundle identifier. Each line a plugin writes to its error output SHALL be logged, tagged with the plugin id, without disturbing replies.

#### Scenario: Plugin prints a warning

- **WHEN** a plugin writes a line to its error output
- **THEN** the line appears in the system log tagged with that plugin's id, and the plugin's replies are read normally
