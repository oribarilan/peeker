# Proposal

## Why

Since windows became the always-editable Editor, Markdown is the one format that can't be edited there: a window shows the same rendered view as the Peek panel, and changing a word means Open With > Plain Text. The maintainer decided (2026-11-03) that the Editor shows Markdown as styled source, editable like Plain Text, while the Peek panel stays the rendered reading view.

## What Changes

- In the Editor, a Markdown file opens as its source text, editable, with undo and Cmd+S. The source is styled as you type: larger bold headings, bold and italic, code in the monospaced font on a tinted background, colored links, and the markers (`#`, `**`, `-`, ``` fences, link brackets) kept visible but dimmed. Prose uses the system font. Colors follow the system's light and dark appearance.
- The Peek panel keeps showing Markdown rendered. There is no rendered view in a window; Space is the read view.
- **BREAKING** Clicking a task box in the Editor flips it as an ordinary edit (marked edited, undoable, saved with Cmd+S). Ticking a task no longer writes the file at once, and the Peek panel's task boxes stop being clickable, since the panel only views.
- A plain click on a link in the Editor places the cursor; Cmd-click opens it, with today's rule of asking before any link that isn't a web page or email.
- The outline and the Words and Tasks info refresh while you type; clicking a heading puts the cursor on it.
- Find, Zoom In and Zoom Out work as in Plain Text; text always wraps. Printing still prints the document rendered, now including unsaved edits.
- Markdown reads and writes files the way Plain Text does: the same encoding detection (not only UTF-8), line endings and byte-order mark kept, unchanged text writes nothing, and text the encoding can't hold offers Save as UTF-8.
- Big files follow Plain Text's limits (over 10 MB read-only, over 16 MB shown in part), and above 1 MB the source opens unstyled, still editable.
- Unsaved Markdown edits go into the crash-recovery copy like any other edits.
- Plain Text's file reading and writing moves into PeekerKit so both plugins share it.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `markdown`: the Editor's styled, editable source; the Peek panel's rendered view; tasks, links, outline, find and zoom, print, encodings, large files and recovery for Markdown.
- `documents`: saving no longer mentions a plugin tool that writes the file directly, since ticking a Markdown task was the only one.

## Impact

- `Plugins/markdown`: a new editable source document for the Editor next to the existing rendered one (kept for the Peek panel and printing), a styler that turns the parsed document into text attributes, and a text view that handles task-box clicks and Cmd-click on links. Task toggling straight into the file goes.
- `Plugins/text` and `Sources/PeekerKit`: encoding detection, size limits, the unsaved-text recovery shape and the safe write move from the text plugin into PeekerKit; Plain Text's behavior doesn't change.
- Tests: Markdown editing, styling, tasks, outline, large files and recovery; the text tests follow the moved code.
- Screen flows: a new Markdown flow (type and save, the Peek panel still rendered, a task click, an outline jump), with driver commands to find text on screen and read the cursor position.
- Benchmarks: Markdown window opens now draw styled source and must not get slower; the Peek panel's Markdown path changes only in how it decodes the file.
- Docs: README's plugin list and CHANGELOG.
