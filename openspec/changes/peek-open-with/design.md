# Design

## Context

The Peek panel (`Sources/Host/PeekPanel/PeekPanel.swift`) is a non-activating `NSPanel` with one titlebar accessory, an `NSButton` titled Open in Peeker that calls `onOpenInWindow`. `AppDelegate` makes the panel lazily, warms it up after launch and shows files through `showInPanel`. Config is read by `ConfigReader` in `Config.swift`, rendered whole by `Config.json(plugins:)` when Settings saves, and described by `ConfigSchema`. `ConfigStore.save` is the one write path, and it refuses while the file can't be used. The panel must stay at least as fast as Quick Look, so nothing new may run on the Space path when no default is set.

## Goals / Non-Goals

**Goals:**
- Open the peeked file in another app, once or by default per extension, without leaving the panel's keyboard model.
- Zero added work on Space for files whose extension has no `openWith` entry.

**Non-Goals:**
- Changing the macOS default app, or Settings UI for these defaults.
- Other apps in the Editor's File > Open With.
- Defaults for files with no extension.

## Decisions

- **`NSComboButton` with the split style** replaces the `NSButton`. It's AppKit's own split button (macOS 13+): a click on the title runs the main action and the arrow shows its `menu`. A pull-down `NSPopUpButton` was the alternative, but it can't have a separate main action. The property keeps the name `openButton` so the existing test and any screen flow reading the title still work.
- **The menu fills itself on open.** The panel sets itself as the menu's delegate and rebuilds the items in `menuNeedsUpdate(_:)`, so `urlsForApplications(toOpen:)`, icons and names cost nothing on Space.
- **The menu's order and contents come from a small pure type** (`PeekOpenWithMenu`) that takes the apps macOS lists (bundle ID, name, URL), the Mac's default app for the file, the panel's default bundle ID and Peeker's own bundle ID, and returns the items in order. Tests cover it without LaunchServices. It drops Peeker and the button's own app, and keeps one entry per bundle ID (the first, which is LaunchServices' preferred copy).
- **Looking up the button's app** goes through one injected function, `appFor(bundleID:) -> (name, url)?`, defaulting to `NSWorkspace.urlForApplication(withBundleIdentifier:)` plus `FileManager.displayName(atPath:)`. It runs only when the file's extension has an entry, so the default path is unchanged. Tests swap the function, which also covers a missing app.
- **Opening in another app** uses `NSWorkspace.open(_:withApplicationAt:configuration:)` with `activates = true`, after `dismiss()`, so the app comes to the front over Finder.
- **Other… is an `NSOpenPanel` sheet** on the Peek panel: `/Applications`, `allowedContentTypes = [.application]`, packages not browsable, and an accessory view with the Always checkbox (left out for files with no extension), shown disclosed. A sheet needs the panel to be key and Peeker active, so Other… calls `NSApp.activate()` first. On Cancel, the panel brings Finder back with `NSRunningApplication` for `com.apple.finder` so the arrow keys keep reaching it. This has to be checked in the real app first (task 1.1). If the sheet doesn't work on the non-activating panel, stop and ask the maintainer rather than switching to a standalone dialog.
- **The panel doesn't write the config itself.** It gets `openWith: [String: String]` from `AppDelegate` when a file is shown, and reports choices through `onSetDefault: (ext, bundleID?) -> Void`, where nil means Always Open in Peeker. `AppDelegate` saves through `ConfigStore.save` and shows a failure in an alert on the panel. The file is opened whether or not the save works.
- **Config shape:** `Config.peekPanelOpenWith: [String: String]`. The reader takes each key through `Config.extensionEntry`, refusing `noExtension` and anything that isn't an extension, and each value as a non-empty string with no whitespace. Each bad entry is its own problem at `peekPanel.openWith.<key>`, and the rest still apply. Rendering always writes `openWith`, as `{}` when empty, as it writes every other default. The schema describes it as an object of strings.

## Risks / Trade-offs

- [A sheet on a `.nonactivatingPanel` may not take the keyboard, or activating Peeker may drop the panel's floating behavior] → Prove it first in the real app (task 1.1). Ask before choosing another presentation.
- [Bringing Finder back after Cancel could pick the wrong Finder window] → Activating Finder restores its last key window, the one the user browsed. Check by hand with two Finder windows.
- [A bundle ID's app can be in several places, or be renamed] → LaunchServices picks the copy; the button shows its current display name.
- [Space with a default set does one LaunchServices lookup] → It happens only for extensions with an entry. Measure with `scripts/bench-ab.sh main` as usual; the fixtures have no entry, so that only guards the default path.
