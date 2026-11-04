# Design

## Context

`DocumentWindowController.toolbar(_:itemForItemIdentifier:willBeInsertedIntoToolbar:)` makes each tool an image `NSToolbarItem` (label and tooltip = the tool's title), except tools that report an on state, which get an `NSButton` (`pushOnPushOff`, bezel `.toolbar`) as the item's view. The active tool is shown with `toolbar.selectedItemIdentifier`. The sidebar button is the system `.toggleSidebar` item; Back and Forward are made in `DocumentWindowController+Navigation.swift` with the title as tooltip. View tools and edit tools sit in separate glass groups, split by a `.space`. Tool shortcuts come from `Config.shortcut(for:of:)`; `Shortcut.displayText` renders them ("H", "⌃⌘S"). Single-key edit tools already run through `handleToolKey` unless a text view has the keyboard, and their menu items show the key in the title instead of as a key equivalent. The screen tests press toolbar buttons by their Accessibility names ("Text Box", "Highlight").

## Goals / Non-Goals

**Goals:**
- One way a toolbar button is made, so captions, tooltips, the selected look and the tip's anchor live in one place, and hover (the next change) can be added there.
- Keep what the native items gave: glass groups, the overflow menu, Customize Toolbar, Accessibility names, the active tool's selected look.

**Non-Goals:**
- Hover feedback (`hover-feedback`, the next change).
- Changing keys outside the PDF plugin, or tips for tools that act at once.

## Decisions

**Each tool stays a native image item, and its image is "icon | key" drawn as one picture.** `ToolbarImage.make` draws the symbol, a thin separator and the key (`Shortcut.displayText`) into one template image, so the toolbar tints it like any icon and greys it with the item; the image's Accessibility description and the item's label stay the tool's name, so VoiceOver, the overflow menu, Customize Toolbar and the screen tests keep "Highlight". Without a key, or with captions off, the image is the plain symbol. Tried first, on screen (task 1.1): an `NSButton` view per item with the key as a title under the image. With bezel `.toolbar` every button drew its own small pill and the icons were clipped; with a bordered item and a borderless button, the same pills; with a plain item and a borderless button, no glass and no on look at all. Image items are the only ones that keep the toolbar's glass. The key under the icon, drawn the same way, shrank the icons to fit the item's height, and the maintainer picked "icon | key" from screenshots.

**A space between tools puts each on a capsule of its own,** the maintainer's choice over one shared piece of glass. `apply(_ config:)` rebuilds the toolbar when `showShortcuts` or a tool's key changes.

**The active tool is shown with `style = .prominent`,** which fills its capsule with the accent color (macOS 26). The old `selectedItemIdentifier` look needs selectable items, and selectable items lose their capsules. Switch tools (Wrap Lines) keep their push-on button view as before.

**The sidebar, Back and Forward show no key in the toolbar,** only in their tooltips ("Sidebar (⌃⌘S)"). "icon | ⌃⌘S" is too wide for the space above the sidebar, and the toolbar moves the button into the overflow menu. The sidebar item is Peeker's own, before `.sidebarTrackingSeparator`, with the action `toggleSidebar(_:)`, so it can carry that tooltip.

**Tooltips come from one function, `Shortcut.tooltip(title:shortcut:)`**: "Title (key)", or the title alone. `validateToolbarItem` keeps putting the unavailable reason first. In Settings, the icon-only buttons (a shortcut's clear button, an extension token's remove button) get `.help` with their names.

**Tips are a plugin's words, kept by the host.** `ToolSpec` gains `tip: String?` (default nil). After any run of a tool with a tip (toolbar, menu or key: `runTool` and `handleToolKey` both end in `DocumentViewController.run`, so the check sits right after it in the window controller), the window asks `TipStore.shouldShow(plugin:tool:)`. The store keeps a set of `plugin.tool` ids under `seenTips` in the app's preferences. When the tool's item is in the window (the toolbar visible and the item not in the overflow menu, `isVisible`), the window shows an `NSPopover` with `behavior = .transient` (it closes on the next click outside it) anchored to the item with `show(relativeTo:)`, sized to its text, and only then marks the tip seen. Settings' Show Tips Again clears the key, its enabled state read live with `@AppStorage("seenTips")` as Reset Panel Size does. Tests give the store a throwaway `UserDefaults`.

**The keys are only defaults.** `PDFPlugin.tools` changes Text Box to `t`, Sign to `s`, Highlight to `h`, and drops Rotate Left's `cmd+l` and Rotate Right's `cmd+r`. A config that names a key keeps it, through the existing override, and a config saved from Settings, which writes every tool's current key, keeps the old defaults until Reset, as Wrap Lines did.

## Risks / Trade-offs

- [View-based toolbar items might not sit on the glass the way image items do] → they don't (task 1.1), so the tools stay image items with drawn images.
- [Capsules with keys take more width, so a narrow window sends tools to the overflow menu sooner] → accepted for the readable key; `showShortcuts` false narrows them.
- [Single letters can fire by accident] → they run only while no text field, text view or text box has the keyboard, as Crop's C already does; every PDF edit is undoable.

## Migration Plan

None. Configs keep any key they set; users of the old defaults get the new single keys unless their config, saved from Settings, already lists the old ones.
