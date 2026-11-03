# Design

## Context

See proposal.md for why. Today `MarkdownPlugin.open` reads the file as UTF-8, parses it with swift-markdown into `MarkdownBlock`s, and `MarkdownDocument` renders them into a read-only `NSTextView` (TextKit 2, from `scrollableTextView()`), drawing the first 150 blocks before the rest. Task boxes are `.link` attributes with a private scheme whose click rewrites the line on disk through `MarkdownPlugin.toggleTask`. Its editability is `.notEditable`, so windows show the rendered view too.

Plain Text already does everything an editable source view needs: `TextCodec` detects encodings exactly, `TextPlugin.load` applies the 10 MB edit and 16 MB display limits, `TextPlugin.write` writes through `FileReplacement` with the Save as UTF-8 offer, and `TextDocument` is a TextKit 1 view with non-contiguous layout (chosen over TextKit 2 for speed, see its header), unsaved-edit tracking, recovery and reload. Plugins may import only PeekerKit, so Markdown can't use any of that yet.

`OpenContext.allowsEditing` is false in the Peek panel and true in the Editor, so the plugin can pick its view per place with no host change.

## Goals / Non-Goals

**Goals:**
- One plugin, two views: styled source in the Editor, the existing rendered view in the Peek panel and on paper.
- Share Plain Text's file handling instead of copying it.
- Restyling never blocks typing, and a Markdown window opens as fast as it does today.

**Non-Goals:**
- Hiding markers (Bear or Obsidian style live preview), inline images, rendered tables in the Editor.
- Syntax highlighting inside fenced code, color themes, a theme setting.
- Moving Plain Text's own note bar to the host's read-only note.

## Decisions

### Two document classes, chosen by `allowsEditing`

`MarkdownPlugin.open` returns the new `MarkdownEditor` when `context.allowsEditing` is true and the existing `MarkdownDocument` (rendered, view-only) otherwise. The rendered class loses task toggling: its boxes become plain ☐ and ☑ glyphs, `toggleTask` and the task link scheme go, and `MarkdownRenderer` stops emitting task links.

Alternative: one class that switches between rendered and source. Rejected: two unrelated views and state machines in one file, and the rendered path is what the Peek panel's speed depends on, so it should stay untouched.

### Shared text file code moves to PeekerKit

`TextCodec`, `TextFormat`, `LineEnding`, `TextLimits`, the unsaved-text recovery shape (`TextEdits`, its JSON unchanged so existing records restore), the Save as UTF-8 offer, and the load and write steps of `TextPlugin` (decode, limits, read-only note, truncation, safe write) move into PeekerKit as a small public `TextFile` API. Plain Text's info rows stay in the text plugin, which calls `TextFile`. Behavior and messages stay as they are; the move is checked by the existing text tests passing unchanged apart from imports.

Alternative: copy the codec into the Markdown plugin. Rejected: two copies of exact-encoding logic that must never drift, and AGENTS.md puts code two plugins need into PeekerKit.

### The Editor view: TextKit 1 source with attribute styling

`MarkdownEditor` is built like `TextDocument`: TextKit 1, non-contiguous layout, `isRichText = false`, quote, dash and text substitutions, link and data detection, and spelling correction off (each would rewrite the user's Markdown), undo on, find bar on, wrapping always on. It differs in fonts and in reporting read-only: it returns `.readOnly(reason)` with the note from `TextFile`, so the host's note under the toolbar shows it (Markdown has no edit tools to grey out). Zoom In and Zoom Out are view tools, menu-only like Plain Text's, and scale a base size from which every style derives.

Saving, unsaved edits, restore, revert and reload follow `TextDocument`: a literal baseline comparison, no write when the bytes are unchanged, reload ignored while there are unsaved edits. `MarkdownPlugin.recoveryText` decodes the shared recovery shape.

### Styling: parse with swift-markdown, apply attribute runs

`MarkdownStyler` is a pure function from source text to style runs (`NSRange` plus a kind: heading level, strong, emphasis, strikethrough, inline code, code block, link, marker, task box, quote) and also returns the outline, word and task counts, and the task-box and link ranges. It parses with swift-markdown, already a dependency, and maps each node's source range to UTF-16 offsets through a table of line starts. swift-markdown columns count UTF-8 bytes; the first styler test pins that with non-ASCII text and CRLF line endings. Marker ranges are each node's range minus its children's (the `**` of a strong span, the `#` run of a heading, a list marker, a fence line, a link's brackets and address).

The styler runs off the main thread: once in `open` (the parse moves from the rendered path into a shared step, so open does the same amount of work as today), then after each edit with a short pause (about 150 ms) on the current text. The result is applied on the main thread inside one `beginEditing`/`endEditing` on the text storage, only if the text hasn't changed since the parse started (a generation counter), so a slow parse never overwrites newer typing. Attribute changes made on the storage directly don't enter the undo stack and don't count as edits. Until a restyle lands, typed characters take the typing attributes of their neighbors, which is close enough for a pause that short.

Above 1 MB (`MarkdownLimits.styledBytes`) no styling runs and the text uses the body font; the outline and counts come from the open or reload parse only, so a large file's typing never triggers a full parse.

Alternative: a line-by-line regular-expression highlighter. Cheaper per keystroke, but wrong on nested emphasis, fences and lists spanning lines, and it would disagree with the renderer the panel uses. Alternative: incremental reparsing of the edited block. Faster on big files, but swift-markdown has no incremental API and the 1 MB cap bounds a full parse; revisit if typing on large styled files lags.

### Clicks: a text view subclass

`MarkdownTextView` overrides `mouseDown`. It finds the character under the click, and:
- for a plain single click inside a task-box range from the last parse (and an editable document), replaces the box's middle character through `shouldChangeText`, `replaceCharacters` and `didChangeText`, so it's undoable and reported as an edit;
- for a Cmd-click inside a link range, opens the link through the existing ask-first rule (`opensWithoutAsking`), moved to a shared helper both views call;
- otherwise passes the click to `NSTextView`, so a plain click on a link places the cursor.

Links in the Editor carry a color, not a `.link` attribute, so `NSTextView` never opens them on a plain click. The Peek panel keeps `.link` attributes and its delegate.

### Outline jump and print

The outline's line numbers map to UTF-16 offsets through the same line table; a click selects an empty range at the line's start, scrolls it into view and flashes the find indicator. Printing parses the current text with `MarkdownTree`, renders it with `MarkdownRenderer` and hands it to `TextPrinting`, as the rendered view does today, so a printout is rendered and includes unsaved edits.

### Screen flow

A new `markdown-edit-flow.sh` covers the four agreed steps: type and save (compares the saved file with the expected bytes), Space on the file shows the panel rendered (its text has no `**`), a task click (the line reads `[x]` and the window is edited), and an outline jump (the cursor's line is the heading's). The driver gains `textframe <process> <text>`, the screen frame of a substring of the focused text area through `AXBoundsForRangeParameterized`, and `selection <process>`, the focused text area's selected range and line through `AXSelectedTextRange` and `AXLineForIndex`. `screen-test.sh` lists the new flow, and the run-peeker skill describes it.

## Risks / Trade-offs

- [Restyling an 844 KB file after every typing pause could stutter] → the parse is off the main thread and dropped when stale; the attribute pass is one batched edit. If the benchmark or a hand check shows lag, lower `styledBytes`.
- [Typed text looks unstyled for a moment before the restyle] → 150 ms pause; acceptable for styled source, revisit only if it reads as flicker.
- [Applying attributes over the whole storage forces layout of hidden text] → non-contiguous layout lays out only what's visible; check with the 844 KB fixture.
- [Moving `TextCodec` into PeekerKit widens the kit's public surface] → expose only what the two plugins use (`TextFile` load and write, the format, limits, the recovery shape and the offer), keep helpers internal.
- [The Peek panel's Markdown decode now runs encoding detection] → for UTF-8 it's a validity check the old `String(contentsOf:encoding:)` also did; the panel's Space benchmark checks it doesn't slow down.
- [Recovery records made before this change for Markdown] → none exist, since Markdown had no edits.

## Migration Plan

Local only. Users who ticked tasks from the rendered view now tick them in the Editor and save; the CHANGELOG says so. Rollback is reverting the change; no stored data changes shape.
