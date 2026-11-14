# Proposal

## Why

A slow file in the Peek panel, such as a 24,000-pixel PNG, leaves the panel empty for a second or more, with nothing to say it's working. Editor windows show a spinner after half a second; the panel was left out when that spinner was added, as a matter of scope.

## What Changes

- The Peek panel shows the same spinner as Editor windows: in the middle of its empty content once an open has taken about half a second, gone when the file or its failure shows. An open that finishes sooner still never draws one.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `plugin-host`: the slow-open requirement covers the Peek panel too.

## Impact

- Changed: one condition in `Sources/Host/Documents/DocumentViewController.swift`.
- Tests in `Tests/DocumentLifecycleTests.swift`. A CHANGELOG line.
- Every panel open starts the spinner's half-second task, as every Editor open already does; it's cancelled before it does anything on a fast open. One `scripts/bench-ab.sh` run checks the panel stays as fast.
