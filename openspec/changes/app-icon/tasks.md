# Tasks

## 1. App icon

- [ ] 1.1 Write the SVG layers in `Sources/Host/Resources/AppIcon.icon/Assets/` (back and middle cards with lines, top card with lines, brackets) from the geometry in design.md; verify each opens in a browser and the three stacked together match the Framed Lift sketch.
- [ ] 1.2 Write `AppIcon.icon/icon.json` with the indigo fill, the three groups and the dark-appearance colors from design.md; verify `ictool` renders Default, Dark, Clear and Tinted macOS renditions at 1024 px without error, and look at each PNG (if `ictool` rejects the file, use the Icon Composer fallback in design.md).
- [ ] 1.3 Render 32 px and 16 px Default images with `ictool`; verify the corners and the tilted card are still recognizable, dropping the middle card's third line if it muddies.
- [ ] 1.4 Set `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` on the `Peeker` target in `project.yml` and exclude `Resources/**` from `HostTests`' copy of `Sources/Host`; verify `scripts/build.sh` is warning-free, the built app's Info.plist has `CFBundleIconName` set to `AppIcon`, and Finder's Get Info on the built app shows the icon.

## 2. Accent color

- [ ] 2.1 Add `Sources/Host/Resources/Assets.xcassets` with `AccentColor.colorset` (Any `#4a52d4`, Dark `#7d82e0`) and set `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor`; verify the built Info.plist has `NSAccentColorName` set to `AccentColor`.
- [ ] 2.2 Add a unit test that loads `NSColor(named: "AccentColor")` from the app bundle and checks its light and dark values; verify it passes with `scripts/build.sh test` (if the test bundle can't reach the app's asset catalog, check the Info.plist key in the test instead).

## 3. Menu bar symbol

- [ ] 3.1 Change the symbol in `Sources/Host/App/MenuBarItem.swift` from `eye` to `viewfinder`, keeping it a template image and the accessibility description "Peeker"; verify the build, and that the red problem dot still sits at the icon's top right in a launched build.

## 4. Docs

- [ ] 4.1 Add a line under Unreleased in `CHANGELOG.md` ("Peeker has its own icon, and the menu bar icon is a viewfinder.") and mark G1 fixed in `docs/design-review-2026-11-01.md` with the commit; verify both read correctly.
- [ ] 4.2 Run `openspec validate --all`; verify it passes.

## 5. Check in the real app

- [ ] 5.1 With the maintainer's go, launch the built app: verify the Dock icon while a file is open, Peeker's icon in Finder's Open With menu, the Dark icon style (System Settings, Appearance, Icon and widget style), the viewfinder in light and dark menu bars, and the indigo selection and switches in Settings under a Multicolor accent and green under a Green accent. Capture screenshots for the record; the screen flows need no new step because the menu bar item keeps its accessibility name, which the commit message says.
