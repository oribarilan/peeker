---
name: run-peeker
description: Use when asked to run, launch, try or demo Peeker, to check a change in the real app rather than in unit tests, or to capture screenshots or a screen recording of its flows as evidence (Space in Finder, Open With, the menu bar icon, config problems, Settings, PDF Edit mode).
---

# Run Peeker

Unit tests (`scripts/build.sh test`) check the parts. This skill checks the built app the way a user meets it. Build first with `scripts/build.sh`; the app lands in `build/dd/Build/Products/Release/Peeker.app`.

## 1. Routing check (works with the screen locked)

```sh
scripts/screen/e2e-routing.sh
```

Launches the app once per case in benchmark mode (`PEEKER_BENCH_OUT`), which opens a synthetic file through the real catalog and config, in a window and in the Space panel, and records which plugin opened it. It covers default lists, a dotfile, `Makefile`, a symlink, `.mp4` and a folder (no plugin), a config that moves `md` to Plain Text, a disabled plugin, and a clash. It needs no permissions. Add a line to `CASES` when routing changes. Quit any running Peeker first.

## 2. Flows on screen, with evidence

```sh
scripts/screen/record-flows.sh
```

Records the flows a user sees and writes everything to `build/evidence/<time>/` (gitignored):

- `results.txt`: one `ok` or `FAIL` line per check, so it's a test, not only a recording.
- `1-…8-*.png`: Space on a Markdown file and a dotfile (Peeker's panel), on an `.mp4` and a folder (Finder's Quick Look), a document window switched through Open With (Markdown, Plain Text, Image), and the menu bar icon reporting a config clash.
- `9-…13-*.png`: Settings, where each change is checked in `config.json`: Image off (Space on an image goes to Quick Look) and on, `md` added with Return and moved to Plain Text, Reset from either pane, the quick-look key recorded as Option-Space (which then opens the panel, and records rather than opens while recording), Off, a new Highlight shortcut used in an open PDF, Permissions, and the controls locking while the file is broken JSON.
- `flows.mp4`: the whole run as a 1080p screen recording.

It takes over the keyboard and Finder for about four minutes, so the screen must be unlocked and nobody should touch it; it refuses to start on a locked screen. It runs Peeker with a throwaway config through `PEEKER_CONFIG` and a throwaway crash-recovery folder through `PEEKER_RECOVERY`, so the user's own `~/.config/peeker/config.json` and recovery records are never read or written, and quits the app at the end. Share the PNGs and the MP4 with the user when they asked to see the flows.

## 3. PDF editing flow

```sh
scripts/screen/pdf-edit-flow.sh
```

Makes a one-page form (`pdf-tool form`), opens it, and checks Edit mode the way a user meets it: the read view hides the tools and ignores typing into a field, Edit Mode shows them, a typed name and a ticked checkbox, a text box on the Date line, a drawn signature placed, then placed again with Use Last Signature, and Save. `pdf-tool inspect` then reads the saved file, and the checks want the field values, one free-text and two ink annotations named `peeker-…`. Evidence goes to `build/evidence/pdf-<time>/`: `results.txt`, screenshots of each step, `saved.txt` and `pdf-flow.mp4`. It finds the Name field through Accessibility and places everything relative to it, so a change to the form means changing the offsets. Like the other flow it takes over the mouse and keyboard; clicks and keys go out only while Peeker is in front.

## Driving by hand

`drive.swift` does the pieces, for flows the script doesn't cover. Build it once: `swiftc -O scripts/screen/drive.swift -o build/run-tools/drive`. Its commands are listed at the top of the file. Keys, clicks and typing go out only while the named app is in front, as in `drive keys Finder space`.

Launch the app yourself with `open --env PEEKER_CONFIG=<scratch config> --env PEEKER_RECOVERY=<scratch folder> -a <Peeker.app> [file]`; both apply only when the app isn't running yet. A full-screen capture is `screencapture -x out.png`, and a recording is `screencapture -v -V <seconds> -x -k -C out.mov`, then `avconvert --preset Preset1920x1080 --source out.mov --output out.mp4`.

## Requirements and traps

- **A locked screen blocks everything visual.** Screenshots come back black, `screencapture -l` fails, Accessibility reports no windows, and keys go to the lock screen. Check `drive locked` first; only the routing check runs while locked.
- The terminal running the scripts needs Accessibility (keys, the Accessibility tree) and Screen Recording (captures), and the first `drive select` asks to let it automate Finder.
- Peeker itself needs Accessibility for Space to reach it. Without it, every Space goes to Finder's Quick Look and the first two checks fail with `Quick Look`. To confirm, list the system's event taps (`CGGetEventTapList`): a Peeker with Accessibility has one. The build is signed with a team ID, so the permission survives rebuilds.
- A bare Space only reaches Peeker while Finder is frontmost and no text field has focus, which is why the script selects files through Finder first.
