# Proposal

## Why

Peeker has no app icon (design review G1, `docs/design-review-2026-11-01.md`): the Dock, Finder, the About panel, Login Items and every Open With menu show the generic app icon. The maintainer chose an icon and a color for the app in a design session, and the first release shouldn't ship without them.

## What Changes

- An app icon, "Framed Lift": four rounded viewfinder corners around a small stack of three cards, the top card tilted to the right so the lines on the card under it show. It reads as "looking at files". One hue, indigo, with a dark appearance; macOS makes the Clear and Tinted appearances from its layers.
- An app accent color, indigo: `#4a52d4` in light windows and `#7d82e0` in dark ones. macOS uses it only for people whose system accent is Multicolor; everyone else keeps their own.
- The menu bar icon changes from the eye to the system's viewfinder symbol, the icon's frame without the cards, so the menu bar stays simple.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `app-presence`: the menu bar icon is the viewfinder symbol; Peeker shows its own app icon wherever macOS shows an app; Peeker's controls take the indigo accent under a Multicolor system accent.

## Impact

- New resources in the app target: an Icon Composer file (`AppIcon.icon`, with SVG layers) and an asset catalog holding `AccentColor`.
- `project.yml`: the app icon and accent color build settings, and keeping the new resources out of the `HostTests` bundle, which also compiles `Sources/Host`.
- `Sources/Host/App/MenuBarItem.swift`: the symbol name.
- `CHANGELOG.md` under Unreleased; G1 marked in the design review.
- No config, plugin contract or file-handling change. The menu bar item keeps its accessibility name "Peeker", so screen flows that find it are unaffected.
