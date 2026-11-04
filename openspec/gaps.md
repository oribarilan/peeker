# Known gaps

Found while writing the baseline specs on 2026-10-30. Each is either a spec requirement the code doesn't meet yet, or something Preview does that Peeker doesn't. A change that fixes one removes it from this list.

## Unmeasured requirements

- **A green A/B run after the in-app move.** The last run against `main` before the move had every timing equal or better, with six photo memory flags that the gate now shows as not comparable (the old build left decoded images out of its memory number). One more `scripts/bench-ab.sh` run should confirm the gate passes. Left open from in-app-plugin-modules (task 7.3).
- **A check by hand of the in-app move**: edit and save a text file, highlight and save a PDF, force-quit with unsaved edits and relaunch. Tests cover these paths; nobody has done them in the real app yet. Left open from in-app-plugin-modules (task 8.1).
- **Screen tests on macOS 26.** CI runs the unit tests on macOS 26, but the screen tests need a real screen and run only where development happens, on macOS 27. A difference only a screen shows (like thumbnail drags, now off on 26) can still slip through.
- **Settings checks in the built app** (settings). Make Default is built and unit-tested but has never been tried in the real app: whether `setDefaultApplication` asks for confirmation on macOS 26, and whether Make Default on PDF makes a double-clicked PDF open in Peeker. The Accessibility status (Space starting within a few seconds of granting, and the red dot on Permissions before granting) hasn't been checked by hand either. Left open from settings-window (tasks 5.4, 5.5, 6.1 and 6.3).
- **Text vs TextEdit** (text). The published reference run predates the text plugin, so BENCHMARKS.md has no text rows. CI's A/B gate does cover text against `main`.

## Requirements the code misses

- **Space vs Quick Look** (peek-panel). A 3-run `bench/ppbench.py space` on 2026-11-02 had Peeker 1.3 to 4.3 times slower than Quick Look on 10 of 11 files (42-81 ms against 17-60 ms). It times the panel appearing, not content drawn, and Peeker's time includes asking Finder for its selection. Either find where the time goes or restate what the requirement compares.
- **Large Markdown** (markdown) opened in 472 ms against TextEdit's 286 ms in the published run. After the in-app move the A/B run measured 310 to 400 ms, but TextEdit wasn't timed in that run, so the requirement is still unconfirmed.

## Missing next to Preview

- **PDF:** one highlight color. Other apps' highlights can't be removed (Peeker's own can). A password-protected PDF opens view-only. A turned page's thumbnail stays upright (the page and the saved file are turned): PDFKit's thumbnail view ignores page rotation, even in a file opened fresh, so showing it means replacing that view with our own, drag, multiple selection and the page menu included (found 2026-10-31 by the `pdf-pages` screen flow).
- **Images:** a multi-page TIFF shows only its first page.

## Future work

- **Find and Print in the Peek panel.** Both work only in Editor windows for now (decided 2026-10-31). The panel never takes the keyboard from Finder, so Cmd+F and Cmd+P go to Finder; making them work means routing them through the global key monitor and handing keyboard focus to the panel and back.

## Risks

- **Space waits on Finder** (peek-panel). Space asks Finder for its selection through a synchronous Apple Event on the main thread. While Finder is busy, Space does nothing, and a hung Finder could freeze Peeker for up to the event's two-minute timeout. Seen only in the recorded flow, which selects files through Finder a moment before pressing Space. If it shows up in real use, cap the wait at a fraction of a second and pass Space on to Finder.
