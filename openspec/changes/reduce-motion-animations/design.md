# Design

## Context

`AnimationPlayer` starts `CGAnimateImageAtURLWithBlock` in its initializer and toggles on a canvas click. Tools can report an on state through `isOn(_:)`, which the host shows as a menu checkmark (as Wrap Lines does).

## Goals / Non-Goals

**Goals:** honor Reduce Motion when a file opens; reach play and pause from the menu.

**Non-Goals:** pausing animations already playing when the setting changes; a default shortcut.

## Decisions

**The player reads `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` when it's made, through a static closure tests replace.** Considered passing the setting through the plugin contract: nothing else needs it, and the plugin may use Apple frameworks directly.

**Play Animation is a view tool with no default shortcut.** A bare key isn't allowed for view tools except Page Up and Page Down, Space already scrolls an image, and a modifier combination would be invented. Users can bind one.

**The tool shows only for animated images**, the way the page tools show only for multi-page TIFFs.

## Risks / Trade-offs

- [Turning Reduce Motion on while a GIF plays doesn't stop it] → it applies to the next open; following the change live would need a notification observer per player, left for later if asked.
