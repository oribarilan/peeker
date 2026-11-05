# Design

## Context

The panel is a lazy property of `AppDelegate`, made on the first Space. `HotkeyMonitor.isTextInputFocused()` makes a system-wide Accessibility call on every bare-key press, and `FinderBridge.selection()` sends Finder a get-data Apple Event. The first of each costs far more than later ones because the connections are set up then. `PermissionChecks.finderStatus(asking:)` reads the Automation permission without prompting when `asking` is false.

## Goals / Non-Goals

**Goals:** move the one-time costs off the first press; never prompt early; add nothing to launch itself.

**Non-Goals:** warming the window server or a plugin. Putting the panel on screen at zero opacity during the warm-up was tried and didn't shorten the first press; the rest of its extra 15-25 ms is the first document's own setup, which the host can't warm without knowing formats.

## Decisions

**One warm-up, a second after `applicationDidFinishLaunching`, on the main thread except the permission check.** By then the first window and Sparkle have started, so the warm-up doesn't delay either. It runs only when the hotkey is on and Accessibility is trusted, since otherwise Space can't reach Peeker anyway.

**Finder is asked only when the permission is already granted.** The check runs in a detached task (it can block), and the selection request goes on the main thread, where `FinderBridge` lives, with its usual half-second limit.

**No unit test for the timing.** The behavior is a duration; the check is relaunching and timing the first press with `SPACEBENCH_FIRST=1`. The no-prompt rule rests on `asking: false`, which the code passes literally.

## Risks / Trade-offs

- [A Finder Apple Event a second after login, while Finder may still be starting] → it's limited to half a second, and a failure is only logged.
