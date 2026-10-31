# Known gaps

Found while writing the baseline specs on 2026-10-30. Each is either a spec requirement the code doesn't meet yet, or something Preview does that Peeker doesn't. A change that fixes one removes it from this list.

## Unmeasured requirements

- **Space vs Quick Look** (quick-look-panel). `bench/ppbench.py space` runs `bench/spacebench.swift` on every fixture for Quick Look and Peeker, but on 2026-10-30 it measured nothing: the harness hung, most likely on a Finder automation permission prompt. It times the panel appearing, not content drawn. Left open from in-app-plugin-modules (task 7.2).
- **A green A/B run after the in-app move.** The last run against `main` before the move had every timing equal or better, with six photo memory flags that the gate now shows as not comparable (the old build left decoded images out of its memory number). One more `scripts/bench-ab.sh` run should confirm the gate passes. Left open from in-app-plugin-modules (task 7.3).
- **A check by hand of the in-app move**: edit and save a text file, highlight and save a PDF, force-quit with unsaved edits and relaunch. Tests cover these paths; nobody has done them in the real app yet. Left open from in-app-plugin-modules (task 8.1).
- **Text vs TextEdit** (text). The published reference run predates the text plugin, so BENCHMARKS.md has no text rows. CI's A/B gate does cover text against `main`.

## Requirements the code misses

- **Large Markdown** (markdown) opened in 472 ms against TextEdit's 286 ms in the published run. After the in-app move the A/B run measured 310 to 400 ms, but TextEdit wasn't timed in that run, so the requirement is still unconfirmed.

## Missing next to Preview

- **PDF:** no way to unlock a password-protected PDF, saved highlights can't be removed, one highlight color.
- **Images:** zooming in on a large photo shows upscaled screen pixels because decoding stops at screen size; no actual-size zoom; no zooming out below fit; only the first frame (no animated GIFs, first page of a TIFF).
- **Markdown:** images show as their alt text; relative links such as `other.md` most likely do nothing (untested); no editing except Open With > Plain Text.

## Future work

- **Find and Print in the Space panel.** Both work only in document windows for now (decided 2026-10-31); the panel is for a quick look.

## Risks

- **Space waits on Finder** (quick-look-panel). Space asks Finder for its selection through a synchronous Apple Event on the main thread. While Finder is busy, Space does nothing, and a hung Finder could freeze Peeker for up to the event's two-minute timeout. Seen only in the recorded flow, which selects files through Finder a moment before pressing Space. If it shows up in real use, cap the wait at a fraction of a second and pass Space on to Finder.
