# Proposal

## Why

The first Space after Peeker launches took 83 to 124 ms to show the Peek panel, three to four times a later press (measured 2026-11-04). It paid for making the panel, the first Accessibility call (about 34 ms) and the first Finder Apple Event (about 17 ms against 6 ms). Peeker usually starts at login and the first Space of the day is the one people notice.

## What Changes

- A second after launch, with the Peek panel key on and Accessibility granted, Peeker makes the hidden panel, makes one Accessibility call and, when Finder automation is already granted, asks Finder for its selection once. The first Space then takes 40 to 50 ms instead of 90 to 100 ms; a later press takes 17 to 30 ms, the rest being the first document's own setup.
- The warm-up never asks for the Finder permission: it only checks it.
- `bench/spacebench.swift` can report the first press (`SPACEBENCH_FIRST=1`), so the gain can be measured again.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `peek-panel`: the first Space after launch is as quick as the rest, and getting ready asks for nothing.

## Impact

- `Sources/Host/App/AppDelegate.swift` (the warm-up), `Sources/Host/PeekPanel/HotkeyMonitor.swift` (`warmUp()`), `bench/spacebench.swift`. CHANGELOG. Patch version bump.
