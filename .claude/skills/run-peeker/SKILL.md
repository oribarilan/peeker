---
name: run-peeker
description: Use when asked to run, launch, try or demo Peeker, to check a change in the real app rather than in unit tests, or to capture screenshots or a screen recording of its flows as evidence (Space in Finder, Open With, the menu bar icon, config problems).
---

# Run Peeker

Unit tests (`scripts/build.sh test`) check the parts. This skill checks the built app the way a user meets it. Build first with `scripts/build.sh`; the app lands in `build/dd/Build/Products/Release/Peeker.app`.

## 1. Routing check (works with the screen locked)

```sh
.claude/skills/run-peeker/e2e-routing.sh
```

Launches the app once per case in benchmark mode (`PEEKER_BENCH_OUT`), which opens a synthetic file through the real catalog and config, in a window and in the Space panel, and records which plugin opened it. It covers default lists, a dotfile, `Makefile`, a symlink, `.mp4` and a folder (no plugin), a config that moves `md` to Plain Text, a disabled plugin, and a clash. It needs no permissions. Add a line to `CASES` when routing changes. Quit any running Peeker first.

## 2. Flows on screen, with evidence

```sh
.claude/skills/run-peeker/record-flows.sh
```

Records the flows a user sees and writes everything to `build/evidence/<time>/` (gitignored):

- `results.txt`: one `ok` or `FAIL` line per check, so it's a test, not only a recording.
- `1-…8-*.png`: Space on a Markdown file and a dotfile (Peeker's panel), on an `.mp4` and a folder (Finder's Quick Look), a document window switched through Open With (Markdown, Plain Text, Image), and the menu bar icon reporting a config clash.
- `flows.mp4`: the whole run as a 1080p screen recording.

It takes over the keyboard and Finder for about a minute, so the screen must be unlocked and nobody should touch it; it refuses to start on a locked screen. It runs Peeker with a throwaway config through `PEEKER_CONFIG`, so the user's own `~/.config/peeker/config.json` is never read or written, and quits the app at the end. Share the PNGs and the MP4 with the user when they asked to see the flows.

## Driving by hand

`drive.swift` does the pieces, for flows the script doesn't cover. Build it once: `swiftc -O .claude/skills/run-peeker/drive.swift -o build/run-tools/drive`.

| Command | Does |
|---|---|
| `drive locked` | `yes` and exit 0 when the screen is locked |
| `drive windows [owner]` | on-screen windows: id, owner, size, title |
| `drive shot <owner> <out.png> [title]` | screenshot of one window |
| `drive select <path>` / `drive key space` | select a file in Finder, press a key |
| `drive tree <process>` | the Accessibility tree: roles, titles, values |
| `drive choose Peeker "Plain Text"` | pick an item in the front window's Open With pop-up |
| `drive menu Peeker File Close` | press a menu item |
| `drive menuextra Peeker [item]` | print the menu bar icon's menu, or press an item |

Launch the app yourself with `open --env PEEKER_CONFIG=<scratch config> -a <Peeker.app> [file]`. A full-screen capture is `screencapture -x out.png`, and a recording is `screencapture -v -V <seconds> -x -k -C out.mov`, then `avconvert --preset Preset1920x1080 --source out.mov --output out.mp4`.

## Requirements and traps

- **A locked screen blocks everything visual.** Screenshots come back black, `screencapture -l` fails, Accessibility reports no windows, and keys go to the lock screen. Check `drive locked` first; only the routing check runs while locked.
- The terminal running the scripts needs Accessibility (keys, the Accessibility tree) and Screen Recording (captures), and the first `drive select` asks to let it automate Finder.
- Peeker itself needs Accessibility for Space to reach it. Without it, every Space goes to Finder's Quick Look and the first two checks fail with `QuickLookUIService`. The build is signed with a team ID, so the permission survives rebuilds.
- A bare Space only reaches Peeker while Finder is frontmost and no text field has focus, which is why the script selects files through Finder first.
