# Checks that need a screen

Fixes and refactors from the 2026-10-31 code review that unit tests can't fully cover. Each needs the real app on an unlocked screen, left alone while it runs, with Accessibility and Screen Recording allowed for the terminal. Build first with `scripts/build.sh`.

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
2. Open a file, then make it unreadable (for example `chmod 000` on it) and change it on disk. The window shows the reason and a Reopen button; after `chmod 644`, Reopen shows the file again (`FailureView`, `8b7aafc`).
