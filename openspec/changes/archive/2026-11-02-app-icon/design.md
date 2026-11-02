# Design

## Context

The app target has no resources yet: no asset catalog and no icon file. `project.yml` builds the `Peeker` target from `Sources/Host`, and `HostTests` compiles `Sources/Host` too. The menu bar item sets its image in `Sources/Host/App/MenuBarItem.swift` from the SF Symbol `eye` as a template image, with the accessibility description "Peeker".

Tools checked on the development Mac (Xcode 27.2, XcodeGen 2.46):

- XcodeGen picks up a `.icon` folder as a single `wrapper.icon` file in Resources, and an `.xcassets` folder as an asset catalog. No special `project.yml` entry is needed beyond the build settings.
- Icon Composer ships with Xcode, along with `ictool`, which renders an `.icon` document to PNG for any rendition (Default, Dark, Clear, Tinted), so the icon can be checked from the command line.
- The SF Symbols `viewfinder` and `viewfinder.rectangular` exist.

## Goals / Non-Goals

**Goals:**
- Build the icon and accent from source files that live in the repo and diff cleanly (SVG layers and JSON), so a later tweak doesn't need a binary asset.
- Leave the system to draw glass, lighting, the Clear and Tinted styles, and the icon mask.

**Non-Goals:**
- No icon in the README or website, and no document icons for file types Peeker opens. Separate calls for later.
- No custom colors in Peeker's own views. The accent goes through the system's accent color only.

## Decisions

### The icon is an Icon Composer document with SVG layers

`Sources/Host/Resources/AppIcon.icon/`, holding `icon.json` and SVG layers in `Assets/`. macOS 26 icons need layers to get the glass treatment; a flat PNG `.appiconset` can't have it. SVG keeps the layers editable and reviewable.

The geometry, on a 100-unit square (scale by 10.24 to the 1024 px canvas; the system applies the rounded mask, so layers draw on the full square):

- Brackets: four stroked paths, width 5, round caps and joins:
  `M18 31V24a6 6 0 0 1 6-6h7`, `M69 18h7a6 6 0 0 1 6 6v7`, `M82 69v7a6 6 0 0 1-6 6h-7`, `M31 82h-7a6 6 0 0 1-6-6v-7`.
- Card stack, wrapped in `translate(50 50) scale(.68) translate(-52.25 -50.35)`:
  - back card: `rect x=18 y=28 w=46 h=60 rx=6`
  - middle card: `rect x=22 y=24 w=46 h=60 rx=6`, with lines `rect x=28 y=36|45|54 w=20|15|18 h=4 rx=2`
  - top card: the middle card's rect inside `rotate(18 68 84)` (it pivots on its bottom-right corner and tilts right), with lines `rect x=28 y=34 w=22 h=4 rx=2` and `rect x=28 y=42 w=15 h=4 rx=2`

Layers are grouped for depth: group 1 is the back and middle cards with the middle card's lines, group 2 the top card and its lines, group 3 the brackets. Each layer is one color, so its dark value can be set as a fill. The two card groups have the glass's see-through turned off; with it on, the middle card's lines showed through the top card.

Colors (indigo `#4a52d4` throughout):

| Part | Default | Dark |
|---|---|---|
| Background fill, top to bottom | `#5c63d8` to `#343994` | `#2b2d31` to `#141518` |
| Brackets, top card | `#ffffff` | `#b7baee` |
| Middle card | `#cccff3` | `#8086e1` |
| Top card's lines | `#9ba0e7` | `#535bd6` |
| Back card, middle card's lines | `#6e75dd` | `#343994` |

The background is the document's fill, not a layer, so the system can tint it. Dark colors go in as Icon Composer's dark-appearance values for the fill and each layer.

Alternative considered: a PNG `.appiconset` exported from the sketches. Rejected, because it gets no glass, no Clear or Tinted styles, and can't be edited without redrawing.

### Write `icon.json` by hand, check it with `ictool`

An agent can't easily drive Icon Composer's window, so the implementer writes `icon.json` and renders it with `ictool` (Default, Dark, Clear and Tinted renditions, macOS) to PNGs to look at. If the hand-written format gets rejected or renders wrong, the fallback is to ask the maintainer to open the layers in Icon Composer and save the document once, about two minutes, and then edit the saved JSON.

### The accent is an `AccentColor` color set

`Sources/Host/Resources/Assets.xcassets/AccentColor.colorset` with an Any value of `#4a52d4` and a Dark value of `#7d82e0`, named by `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor`. Xcode then writes `NSAccentColorName` into Info.plist, and AppKit's `controlAccentColor` uses it under a Multicolor system accent. The values come from the design session: white text on `#4a52d4` measures 6.1:1, and `#7d82e0` on a dark window background (`#232428`) measures 4.5:1.

### Build settings

On the `Peeker` target: `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` (the `.icon` file's name) and the accent setting above. `HostTests` excludes `Resources/**` from its copy of `Sources/Host`, because the test bundle doesn't need the icon and building it twice slows the tests.

### Menu bar symbol

`viewfinder`, the square-cornered one, which matches the icon's frame. It stays a template image, so the red problem dot drawn on top and the light and dark menu bar handling don't change.

## Risks / Trade-offs

- [The hand-written `icon.json` format is undocumented and may change between Xcode versions] → Check every rendition with `ictool` before building; the fallback above.
- [The thin lines on the cards blur at 16 pt] → Accepted in the sketches; check the 16 and 32 px `ictool` renders, and drop the middle card's third line if it muddies.
- [The glass treatment may lighten indigo more than the sketches showed] → Compare the Default render with the sketch colors, and adjust the fill if it drifts.
- [`ASSETCATALOG_COMPILER_APPICON_NAME` with an `.icon` file needs Xcode 26 or later] → The project already requires Xcode 26+.
