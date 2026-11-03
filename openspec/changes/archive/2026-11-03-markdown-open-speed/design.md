# Design

## Context

See proposal.md for why. `MarkdownPlugin.load` read the file and ran `MarkdownStyler.style` on all of it off the main thread; `MarkdownEditor.init` then set the text and applied every style run on the main thread. A sample of the styler showed most of its time in converting swift-markdown positions to UTF-16 offsets (a line search and a byte scan per position) and in type casts on every node, plain text included.

## Goals / Non-Goals

**Goals:**
- Large Markdown files open in a window at least as fast as before the Editor.
- The same styling once the open finishes.

**Non-Goals:**
- Restyling only what changed while typing in a large file: a pause still restyles the whole file on the main thread.

## Decisions

### Show from a parse of the start, then parse the rest

For a styled file over 64 KB, `load` parses only its start, up to the first blank line after 64 KB, which ends most blocks so the start parses as in the whole file. The Editor shows that, then runs its usual `restyle` off the main thread on the whole text and applies it if nothing was typed meanwhile, rebuilding the sidebar when the outline changed. For smaller files the Editor styles the first 20,000 UTF-16 units before the window shows and the rest on the next turn of the run loop.

Alternative: show the text unstyled and style it all once parsed. Rejected: the top would visibly reflow as headings grow.

### A cheaper styler

Plain text, soft and hard breaks return before any position is worked out; paragraphs, lists and the document recurse without one. Positions on an ASCII-only line convert by subtraction, and the line comes from swift-markdown's location instead of a search. A node's child span looks at its first and last child only. Words are counted by Unicode scalar, which matches splitting into characters at a fraction of the cost. A style pass makes the heading and code fonts once and caches bold and italic conversions.

### The cursor starts at the top

Setting a text view's text leaves the cursor at its end; both plugins put it at the start, as TextEdit does.

## Risks / Trade-offs

- [Until the full parse lands, the outline and counts cover only the start, and a reference link defined further down isn't styled] → They complete within about 150 ms.
- [Applying the full style to a large file still takes about 100 ms on the main thread after the window shows] → It no longer delays the window; typing in that moment waits briefly.
