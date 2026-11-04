# Design

## Context

`FinderBridge.selection()` runs a compiled `NSAppleScript` (`selection as alias list`, then POSIX paths) on the main thread with no timeout. The event tap swallows Space before the read, and `peekFinderSelection` passes the key to Finder when the selection comes back empty; `followFinderSelection` returns quietly on an empty one. So returning an empty selection on a timeout already gives the decided behavior.

## Goals / Non-Goals

**Goals:**
- Bound the read at 0.5 s with no change to the callers.

**Non-Goals:**
- Moving the read off the main thread. Space waits for the answer either way, and 0.5 s on the main thread is the agreed ceiling.
- Making Space faster than today; that's the separate "Space vs Quick Look" gap.

## Decisions

**Send the get-data Apple Event directly with `NSAppleEventDescriptor.sendEvent(options:timeout:)`.** AppleScript's `with timeout` counts whole seconds, and `NSAppleScript` has no timeout setting. The event asks Finder for its `selection` property as an alias list, the same request the script made; Finder answers with a list whose items coerce to file URLs. Tried by hand on 2026-11-04: one selected file came back in 38 ms. Considered running the script on a background thread and abandoning it after 0.5 s: `NSAppleScript` should be used from the main thread, and an abandoned call would keep a thread blocked on a hung Finder.

**A timeout, an error or a denied permission all return an empty selection, logged as today.** The callers already treat empty as "let Finder handle it".

**The timeout is a parameter with a 0.5 s default**, so a test can use a short one.

## Risks / Trade-offs

- [A Finder that takes just over 0.5 s, say right after a big copy, hands that Space to Quick Look] → accepted in the interview; the next Space tries again.
- [Building the event by hand is less readable than the script] → kept to one small function with a comment naming the AppleScript it matches.
- [A hung Finder can't be reproduced in unit tests] → tests cover the reply parsing and the failure path with a target that isn't running; the busy-Finder case is in the screen queue.
