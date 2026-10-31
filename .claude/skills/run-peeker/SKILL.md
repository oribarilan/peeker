---
name: run-peeker
description: Use when asked to run, launch, try or demo Peeker, to check a change in the real app rather than in unit tests, to run the screen tests, or to capture screenshots or a screen recording of its flows as evidence (Space in Finder, Open With, the menu bar icon, config problems, Settings, PDF Edit mode and page edits, image editing, crash recovery).
---

# Run Peeker

Unit tests (`scripts/build.sh test`) check the parts. The screen tests check the built app the way a user meets it. They drive the real app, so they need the maintainer's go: an unlocked screen nobody touches for a few minutes.

## The suite

```sh
scripts/screen-test.sh                 # build, then routing and every flow
scripts/screen-test.sh pdf-edit        # only the flows named: routing, flows, pdf-edit, pdf-pages, image-edit, recovery
scripts/screen-test.sh --record        # also save a video of each flow (slower)
scripts/screen-test.sh --no-build      # test the app already built
```

It runs every flow even after one fails, prints each flow's ok and FAIL counts, and exits non-zero when a check failed or a flow didn't finish (the reason is on its line). Evidence goes to `build/evidence/run-<time>/<flow>/` (gitignored): `output.txt`, `results.txt`, screenshots, and with `--record` a video. Without video the whole suite takes about three minutes, plus the build. Read a failure's screenshots and `output.txt` before rerunning; a check that fails once and passes later is a bug to find, in the app or in the flow.

When a change is user-facing, add or update a step in a flow, with a `check` for what the user should see.

## The flows

`scripts/screen/` holds them, with `common.sh` (their shared setup), `drive.swift` and `pdf-tool.swift`. Each also runs on its own, into `build/evidence/<flow>-<time>/`.

- **routing** (`e2e-routing.sh`): launches the app once per case in benchmark mode (`PEEKER_BENCH_OUT`), which opens a synthetic file through the real catalog and config, in a window and in the Space panel, and records which plugin opened it. It covers default lists, a dotfile, `Makefile`, a symlink, `.mp4` and a folder (no plugin), a config that moves `md` to Plain Text, a disabled plugin, and a clash. It needs no permissions and works with the screen locked. Add a line to `CASES` when routing changes.
- **flows** (`record-flows.sh`, about two minutes): Space on a Markdown file and a dotfile (Peeker's panel), on an `.mp4` and a folder (Finder's Quick Look); a document window switched through Open With; the menu bar icon reporting a config clash; Settings, where each change is checked in `config.json`: Image off and on, `md` moved to Plain Text and Reset, the quick-look key recorder and Off, a new Highlight shortcut used in an open PDF, one recorder listening at a time, Permissions, and the controls locking while the file is broken JSON.
- **pdf-edit** (`pdf-edit-flow.sh`, about 15 seconds): makes a one-page form, checks the read view hides the tools and ignores typing into a field, then in Edit mode types a name, ticks a checkbox, adds a text box, draws and places a signature twice, and saves; `pdf-tool inspect` then reads the saved file. It finds the Name field through Accessibility and places everything relative to it, so a change to the form means changing the offsets.
- **pdf-pages** (`pdf-pages-flow.sh`, about 25 seconds): in Edit mode on a numbered 4-page PDF (`pdf-tool pages`), rotates page 2 and deletes page 4 picked in the thumbnails, drags page 3 to the top, and saves; undoes the drag and the saved delete and saves again; then rotates and deletes once more and leaves Edit mode with Don't Save. `pdf-tool inspect` lists the saved pages (text and rotation) after each save. Thumbnails are found by the page numbers under them; the drag holds before it moves, or PDFKit doesn't start one.
- **image-edit** (`image-edit-flow.sh`, about 15 seconds): crops a 400 × 200 PNG, presses R in Rotate & Resize, sets the width to 100 with Keep proportions on, applies and saves, then checks the size fields, the saved pixel size (`sips`), the info panel's Dimensions, and that Cmd+W asks nothing. Every expected size comes from the fields after the crop, so the crop drag needn't land exactly.
- **recovery** (`recovery-flow.sh`, about 25 seconds): types into a text file and fills the form's Name field, waits for both recovery records, kills the build under test with SIGKILL and launches it again. Both documents come back as tabs with their edits, the PDF in Edit mode; closing each asks to save, and Don't Save empties the recovery folder. A recovered file that's gone (its text goes to the clipboard) stays a unit test, so a run never touches the clipboard.

Every flow runs Peeker with a throwaway config through `PEEKER_CONFIG` and a throwaway crash-recovery folder through `PEEKER_RECOVERY`, so the user's own config and recovery records are never read or written. It drives and quits only the build under test.

## Driving by hand

`drive.swift` does the pieces; its commands are listed at the top of the file. Build it with `swiftc -O scripts/screen/drive.swift -o build/run-tools/drive` (the flows do this themselves). Keys, clicks and typing go out only while the named app is in front, as in `drive keys Finder space`. Wait on state rather than time: `drive wait Peeker window form.pdf`, `drive wait Peeker sheet --gone`, `drive wait Peeker control "Text Box"`. `drive focus Peeker` shows where the keyboard is when typing doesn't arrive.

Launch the app yourself with `open --env PEEKER_CONFIG=<scratch config> --env PEEKER_RECOVERY=<scratch folder> -a <Peeker.app> [file]`; both apply only when the app isn't running yet. A full-screen capture is `screencapture -x out.png`, and a recording is `screencapture -v -V <seconds> -x -k -C out.mov`, then `avconvert --preset Preset1920x1080 --source out.mov --output out.mp4`.

## Requirements and traps

- **A locked screen blocks everything visual.** Screenshots come back black, Accessibility reports no windows, and keys go to the lock screen. The flows refuse to start then; only routing runs while locked.
- **Another copy of Peeker** (an installed one) makes the flows refuse to start, so the user's windows are never touched. Quit it first.
- The terminal running the tests needs Accessibility (keys, the Accessibility tree) and Screen Recording (captures), and the first `drive select` asks to let it automate Finder.
- Peeker itself needs Accessibility for Space to reach it. Without it, every Space goes to Finder's Quick Look and the Space checks fail with `Quick Look`. The build is signed with a team ID, so the permission survives rebuilds.
- A bare Space only reaches Peeker while Finder is frontmost and no text field has focus, which is why the flows select files through Finder first.
- **Modifier keys.** A synthetic key event's flags leave its modifiers set in the system's state; `drive keys` releases them afterwards, and `drive type`, `click` and `drag` send no modifiers. Any other tool that posts key events must do the same, or later typing arrives as shortcuts.
- **Stopping a run.** Ctrl-C (or SIGTERM) stops a flow: it answers Don't Save, quits the build under test and kills the recorder, losing that video, since `screencapture` can't stop early and keep its file. A flow started with `&` from another script ignores SIGINT, so use SIGTERM there.
