# Proposal

## Why

The maintainer's rule for default shortcuts (2026-11-08): uncommon operations such as rotating get no default key, and common tools get a single key with no modifier unless there's a strong reason. Rotate & Resize in images still opens with Cmd+R, the last default that breaks it. The PDF spec also still names Cmd+L and Cmd+R for rotating pages, which an earlier change already removed.

## What Changes

- Rotate & Resize has no default key. It opens from its toolbar button or Tools > Rotate & Resize, and a key can still be set in Settings or the config. Its L, R, H and V keys while the panel is open stay.
- The PDF spec's Page tools requirement drops the old Cmd+L and Cmd+R, matching the app.

## Capabilities

### Modified Capabilities

- `image`: Rotate & Resize opens without a default key.
- `pdf`: the page tools are described without keys.

## Impact

`Plugins/image/ImagePlugin.swift` (the tool's shortcut), its tools test, the `image-edit` screen flow (presses the button instead of Cmd+R), README and CHANGELOG. Patch version bump.
