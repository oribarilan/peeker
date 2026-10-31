# Checks that need a screen

Fixes and refactors from the 2026-10-31 code review that unit tests can't fully cover. Each needs the real app on an unlocked screen, left alone while it runs, with Accessibility and Screen Recording allowed for the terminal. Build first with `scripts/build.sh`.

## Results, 2026-10-31

Every check below passed on a Release build, along with the routing check (`e2e-routing.sh`, 30 of 30).

| Check | Result |
|---|---|
| 1. Flow scripts | `record-flows.sh` 26 of 26, twice. `pdf-edit-flow.sh` 8 of 8 three times; one earlier run lost its typed text because a pressed menu stayed open (fixed in `ab6de72`). |
| 2. Aborted run | Failed at first: the recorder ignored the cleanup's SIGINT, and Quit waited on a Save prompt. Fixed in `1fc76dd`; an aborted run now exits in about 2 s with no recorder, no Peeker and no recovery record left. |
| 3. Recorders | All four steps pass: only the last recorder clicked listens, the key goes to its command, and Space opens the panel after recording ends or the app is switched. |
| 4. Moved code | The GIF cycles its frames, holds one when clicked and plays on. A reload that fails shows the reason and Reopen, and Reopen brings the file back. |

To repeat check 2, interrupt a run with Ctrl-C in a terminal, or send it SIGTERM. A script started with `&` from another script ignores SIGINT, so `kill -INT` won't reach it.

## 1. Flow scripts send keys only to the named app (B7)

`drive key` is gone; the scripts now press Space and Escape with `drive keys <app> <key>`, which refuses unless that app is in front.

```sh
.claude/skills/run-peeker/record-flows.sh
.claude/skills/run-peeker/pdf-edit-flow.sh
```

Pass: every line in each run's `results.txt` says `ok`, and no "isn't in front: not sending input" error appears. The Space checks also cover the quick-look key decision, which moved into `HotkeyMonitor.decide` (`ed972f7`). Watch the four Space checks in `record-flows.sh` most closely: Escape now goes to Finder, which stays in front because Peeker's panel never takes focus. If Escape stops closing the panel or Quick Look, that assumption is wrong.

## 2. An aborted flow cleans up (T7)

Start `record-flows.sh`, press Ctrl-C about 20 seconds in, then:

```sh
pgrep -x screencapture; pgrep -x Peeker
```

Pass: neither command prints anything. Also check that a run left to finish quits Peeker and leaves a `flows.mp4` in its evidence folder.

## 3. One shortcut recorder at a time (B10)

The model's rule has a unit test; the SwiftUI recorder that follows it doesn't. Open Settings and choose the PDF pane.

1. Click the Zoom In recorder, then the Zoom Out recorder without pressing a key. Only Zoom Out shows "Type a shortcut…".
2. Press Option-Command-Z. Only Zoom Out changes, and `config.json` has the key under `zoom-out`.
3. In Finder, press Space on a Markdown file. Peeker's panel opens, so the quick-look key came back once recording ended.
4. Click a recorder, then switch to another app. Recording stops, and Space in Finder opens the panel again.

## 4. Moved code still behaves (K4, K8)

Code that moved without a behavior change, but whose drawing only a screen shows:

1. Open an animated GIF. It plays, a click pauses it on its frame, and another click plays on (`AnimationPlayer`, `aaf0779`).
2. Open a text file, then write a NUL byte into it, which the text plugin refuses. The window shows the reason and a Reopen button (`FailureView`, `8b7aafc`). To press Reopen before the file watcher reloads by itself, replace the file with good content in a mode-000 file (the watcher can't open it), then `chmod 644` and press Reopen.
