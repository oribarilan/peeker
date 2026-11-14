# Design

## Context

The Peek panel (`Sources/Host/PeekPanel/PeekPanel.swift`) is an `NSPanel` with a full-size content view and a transparent title bar. Its file name is the window's own title, which AppKit draws and cuts at the end; nothing keeps it clear of the trailing title-bar accessory that holds the folder button and Open in Peeker, whose width changes with the button's title ("Open in TextEdit"). On macOS 26 and later the title starts where the content's sidebar ends when there is one, and after the window buttons when there isn't.

The button is an `NSComboButton` whose menu is rebuilt in `menuNeedsUpdate`, with each app's icon from `NSWorkspace.icon(forFile:)`. The macOS 27 SDK says AppKit "determines the visibility of menu item images, and will typically hide images" unless an item's `preferredImageVisibility` is `.visible` (`NSMenuItem.h`, macOS 27). That's why the icons don't show on this Mac (macOS 27.0.1); File > Open Recent (`Sources/Host/App/RecentFiles.swift`) sets icons the same way. CI builds with Xcode 26.6, whose SDK lacks the property, and both toolchains report Swift 6.4.2, so a compiler check can't tell them apart.

## Goals / Non-Goals

**Goals:** the name never overlaps the buttons; middle truncation; icons visible on macOS 27; no change on macOS 26.

**Non-Goals:** the Editor window's title (it has a toolbar and a tab bar and cuts names itself); icons in other menus that don't set images today.

## Decisions

- **Our own title label.** The panel hides AppKit's title (`titleVisibility = .hidden`) but keeps setting `title`, so the Window menu, Mission Control and VoiceOver still get the full name. A one-line label (`lineBreakMode = .byTruncatingMiddle`, the title bar's font) goes in the same accessory view as the buttons, to their left. The accessory view grows to span from where the title should start to the window's trailing edge, and the label takes what's left before the folder button. Its frame is recomputed whenever the buttons are laid out (the file and the button's title change) and when the panel resizes, which it already observes. The start is the sidebar's trailing edge when the content shows a sidebar, else just after the zoom button, so a short name sits where it sits today. Alternative: keep AppKit's title and shrink the window title with a narrower accessory; rejected, as AppKit only cuts at the end and still overlaps a wide accessory after the button's title changes.
- **Asking for images by name.** A small helper on `NSMenuItem` sets `preferredImageVisibility` to visible when the item responds to it, through key-value coding, so the code compiles against the macOS 26 SDK on CI and does nothing there, where images already show. The Peek panel's app items and Open Recent's items use it. Alternative: `if #available(macOS 27, *)` with the real property; it doesn't compile against the macOS 26 SDK. Once CI builds with the macOS 27 SDK, the helper becomes the plain property.

## Risks / Trade-offs

- [The start point guess differs from where AppKit put the title] → A short name moves by a few points at most; the screen flow's screenshot shows it, and the start is one function to adjust.
- [AppKit can still hide an image marked visible "in some cases", says the header] → The unit test checks the preference is set; the screen flow's screenshot of the menu shows whether icons draw.
- [Key-value coding on a property that doesn't exist throws] → The helper checks `responds(to:)` first.
