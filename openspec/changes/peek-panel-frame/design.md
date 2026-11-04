# Design

## Context

`PeekPanel` is created once per run (lazily, on the first Space) with a frame of 55% × 75% of `NSScreen.main`'s visible frame, centered. `show(_:)` keeps whatever frame the panel has, so a resize lasts until quit. Editor and Settings windows use `setFrameAutosaveName`, which keeps a frame under `NSWindow Frame <name>` in the app's preferences. The screen tests share those preferences with an installed Peeker; `scripts/screen/common.sh` saves and restores a list of single-word keys around a run (`PREF_KEYS`) and forgets them for the run. The Space path today does no screen work beyond the panel's own `orderFrontRegardless`; the benchmark has Peeker 1.1–2.5× faster than Quick Look and that margin must hold.

## Goals / Non-Goals

**Goals:**
- Keep the frame rules in one pure function, so they're tested without windows or displays.
- Add nothing measurable to the Space path: a pointer read and some rectangle math.

**Non-Goals:**
- Fitting the panel to the file's shape.
- A config key for the frame, or a frame per display.
- Remembering anything about the Editor or Settings windows beyond what they do now.

## Decisions

**The frame lives under its own key, `peekPanelFrame`, written by Peeker, not by `setFrameAutosaveName`.** Autosave restores the frame when the name is set and saves on every move, including the panel's own re-centering on another display, which would make Reset Panel Size light up without the user touching the panel. Peeker writes `NSStringFromRect` of the frame when the user moves or resizes the panel (`windowDidMove`/`windowDidResize` while Peeker isn't setting the frame itself), and reads it when the panel shows. A single-word key also fits `PREF_KEYS` in the screen tests, which split the list on spaces. Considered autosave with a flag to ignore its writes: it fights AppKit for no gain.

**Placement is a pure function: `PanelPlacement.frame(saved:screen:)`** taking the saved frame (or nil) and the visible frame of the pointer's display, returning the frame to use. Saved and inside the display → saved. Saved, outside it, but its size fits → that size centered on the display. No saved frame, or a size that doesn't fit → the default, centered. The default is `min(55% of width, 900)` × `min(75% of height, 700)`, and never below the 400 × 300 minimum. "Inside" means the whole frame lies within the visible frame, so a panel half off a display after an arrangement change counts as outside and gets re-centered.

**The pointer's display is `NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }`, falling back to `NSScreen.main`.** It's a local read, unlike asking Finder or the window list for Finder's window, which the interview weighed and set aside for cost.

**The panel places itself in `show(_:)` only when it isn't already showing.** Arrow keys and links swap the document in a visible panel, and the panel must not jump while the user browses. `show` replaces today's "keep the current frame" with the placement result when the panel is hidden, then sets `contentMinSize` once in `init` to 400 × 300.

**Reset goes through the app.** `PeekPanel` gets `resetFrame()`, which removes the key and, when the panel exists, sets the default frame on the pointer's display. `SettingsModel` gets a `resetPeekPanel` closure, which the app wires to the panel (creating nothing when the panel was never made), and a `hasSavedPeekPanelFrame` value read from the defaults it already takes, for tests. The button's enabled state comes from `@AppStorage("peekPanelFrame")` on the same defaults, so it lights up as soon as the user resizes the panel, even with Settings open, with no notification plumbing.

**Tests use their own defaults.** `PeekPanel(defaults:)` takes a `UserDefaults`, `.standard` in the app, so tests never read or write the user's saved frame.

## Risks / Trade-offs

- [Pressing Space by keyboard while the pointer rests on the other display opens the panel there] → accepted in the interview as the price of a free check; the user moves the pointer or the panel.
- [Re-centering on another display doesn't update the saved frame] → intended: the saved spot stays the one the user chose; only their own moves change it.
- [The Space benchmark could move] → the work added is a defaults read on the first show and arithmetic; task 5 runs `bench/ppbench.py space` and compares with the 2026-11-04 table.

## Migration Plan

None. A user's first Space after updating opens at the new capped default.
