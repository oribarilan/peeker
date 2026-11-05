# Proposal

## Why

Animated images play and loop whatever the Reduce Motion setting, and pausing takes a click on the image, with no menu item (design review finding I4). People who turn on Reduce Motion ask apps not to move things on screen by themselves, and a menu command is what keyboard and VoiceOver users can reach.

## What Changes

- With Reduce Motion on (System Settings > Accessibility > Display), an animated image opens paused on its first frame, in the Editor and the Peek panel. A click plays it, as before.
- View > Play Animation plays and pauses the animation in a window, checked while it plays. It shows only for animated images and has no default shortcut; one can be set in Settings or the config like any tool's.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `image`: the animated-images requirement gains Reduce Motion and the Play Animation command.

## Impact

- `Plugins/image/AnimationPlayer.swift`, `ImageDocument.swift`, `ImagePlugin.swift` (a new view tool).
- Tests: `ImageDocumentTests` (ImageAnimation), the tool lists in `PluginToolsTests` and `ToolbarTests`.
- `scripts/screen/viewer-flow.sh`, CHANGELOG, the backlog's I4 line, the design review's I4 status. Minor version bump.
