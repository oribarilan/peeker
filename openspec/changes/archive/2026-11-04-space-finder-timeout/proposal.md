# Proposal

## Why

Space and the arrow keys ask Finder for its selection with an Apple Event that has no time limit, on the main thread. While Finder is busy, Space does nothing; a hung Finder could freeze Peeker until the system's default timeout. The risk is listed in `openspec/gaps.md` and was seen in the recorded screen flow.

## What Changes

- Reading Finder's selection gives up after half a second.
- When it gives up on Space, the key goes on to Finder, so Quick Look opens, as it does for a file no plugin opens.
- When it gives up on an arrow key while the panel shows, the panel stays on the file it shows.
- The selection is read with one Apple Event sent directly to Finder instead of a compiled AppleScript, which is what makes a sub-second limit possible.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `peek-panel`: adds a requirement that Space and the arrow keys wait at most half a second for Finder.

## Impact

- `Sources/Host/PeekPanel/FinderBridge.swift`: sends the Apple Event with a timeout.
- `Sources/Host/App/AppDelegate.swift`: unchanged paths; an empty selection already passes Space to Finder and leaves the panel alone on arrows.
- Tests for the bridge; `openspec/gaps.md` loses the "Space waits on Finder" risk.
