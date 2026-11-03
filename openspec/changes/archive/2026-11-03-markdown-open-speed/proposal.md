# Proposal

## Why

The benchmark against the build before the Markdown editor (run 2026-11-03, postponed until then by the maintainer) flagged large Markdown files: opening the 864 KB fixture in a window went from 142 ms to 290 ms, and launching with it from 422 ms to 553 ms. The Editor parsed the whole file and applied about 96,000 style runs on the main thread before showing anything. While checking the fix, a second issue showed: Markdown and text files opened with the cursor at the end, so the outline marked the last heading and scrolled to the bottom.

## What Changes

- A styled Markdown file over 64 KB opens from a parse of its start, up to a blank line, with the first screen styled; the rest is parsed off the main thread once the window shows, and the outline and counts complete then. Smaller files show the first screen styled and the rest on the next turn of the run loop.
- The styler counts words by Unicode scalar, skips plain text nodes before working out positions, converts positions on ASCII lines without scanning, and makes each font once per style pass.
- Markdown and text files open with the cursor at the start.

Measured on the same machine: the window open is 30 ms (from 290), launch with the file 315 ms (from 553), and the window uses 73 MB (from 92).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `markdown`: the first screen appears first in the Editor too; the cursor starts at the top.
- `text`: the cursor starts at the top.

## Impact

- `Plugins/markdown/MarkdownPlugin.swift`, `MarkdownStyler.swift`, `MarkdownEditor.swift`; `Plugins/text/TextDocument.swift`.
- Tests; no screen flow change (existing flows pass). Version goes to `0.5.2-dev` (a fix).
