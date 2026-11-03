# Tasks

## 1. Speed

- [x] 1.1 Profile opening the 864 KB fixture (styler sample, per-step timing); make fonts once per style pass; count words by scalar; skip plain nodes and convert ASCII-line positions directly; verify the Markdown tests pass
- [x] 1.2 Write failing tests: a file over 20,000 units styles the first screen at once and the rest on the next turn; a file over 64 KB shows from a parse of its start and completes the outline and styling after; the prefix cut stops at the first blank line after the limit; the word count matches splitting into characters. Then add the quick parse and the first-screen pass; verify the tests pass

## 2. Cursor

- [x] 2.1 Write failing tests: Markdown and text files open with the cursor at the start, and the outline marks the first heading. Then set the selection on open; verify the tests pass

## 3. Wrap-up

- [x] 3.1 Run `scripts/build.sh` and `scripts/build.sh test`; verify all tests pass with no warnings
- [x] 3.2 Benchmark the Markdown cases (`bench/ppbench.py run --files large.md,small.md --launches 15`) and compare with the base; run the markdown-edit, recovery, viewer, theme and flows screen flows; verify they pass
- [x] 3.3 Add an Unreleased line to CHANGELOG and bump `MARKETING_VERSION` to `0.5.2-dev`, committed after this change
