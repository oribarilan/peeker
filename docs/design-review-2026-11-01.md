# Design review, 2026-11-01

A read-only review of every surface a user meets: document windows and tabs, the toolbar, the menu bar, the menu bar icon, Settings, the Space panel, alerts and sheets, and each plugin's views. The yardstick is a macOS design checklist built from Apple's Human Interface Guidelines (HIG) for macOS 26, the Liquid Glass guidance and common Mac practice. Line numbers refer to commit `e221f45`.

Each finding says where its rule comes from: **Apple** (a HIG page, linked), **practice** (common Mac convention, not Apple's text) or **taste**. Where a finding goes against an OpenSpec spec, it says so: those are product calls for the maintainer, not bugs.

Status values: **open**, **in progress**, **fixed** (with the commit), **won't fix** (with the reason).

## How this was checked

- **Code**: every file under `Sources/Host/`, `Sources/PeekerKit/` and `Plugins/` that draws UI, plus the specs in `openspec/specs/`.
- **Screen-test captures**: the screenshots that `scripts/screen-test.sh` saved under `build/evidence/` on 2026-11-01 (dark mode, macOS 27, commits from the same day). They show real windows with their toolbars and glass. They aren't committed.
- **Offscreen renders**: the signature pad and the failure view, in light and dark, and a layout check of a full-size-content window with a toolbar and a sidebar. Harness and images live in `build/design-review/`, which git ignores.
- **Preview.app**: its menus and shortcuts were read from `MainMenu.nib` in the copy that ships with macOS 27. Comparisons below rely only on that.

Nothing here comes from running Peeker by hand; VoiceOver, keyboard focus and the accessibility display settings are listed under "Needs a screen check".

## Verdict

The foundation is native: a standard `NSToolbar` with plain symbols, a split-view sidebar that gets the system glass, sheets for the save prompts, a SwiftUI Settings window that applies changes at once, and honest disabled states with reasons. The gaps fall into three groups. Two visible layout bugs: the PDF find bar hides under the toolbar, and the Rotate & Resize popover covers the toolbar. Some commands can't be reached the Mac way: there's no View menu, Open With is toolbar-only, a crop can't be applied with the mouse, and the sidebar can't be hidden. And there are missing basics a careful Mac user notices: no loading state, no app icon, Settings forgetting its pane, and two default shortcuts that take standard meanings.

## Suggested order

Highest user impact first; sizes in the tables.

1. D1, the PDF find bar under the toolbar.
2. I3, a crop that can't be applied with the mouse.
3. W1, a loading state for slow opens.
4. I1, the Rotate & Resize popover covering the toolbar.
5. W2 and M1, sidebar show/hide and a View menu.
6. M3, Open With in the menu bar.
7. G1, an app icon.
8. S1, S2 and S3, Settings fit and finish.
9. D2, the signature line in dark mode.
10. M6, the ⌘E and ⌥⌘W shortcuts.
11. M4 and M5, the missing standard menu items.
12. W3, toolbar groups.
13. T1 and M7, toggle state and zoom across plugins.
14. A1, keyboard access to edit tools.
15. Everything else.

## Windows, toolbars and alerts

| ID | Finding | Where | Rule | Direction | Size | Status |
|---|---|---|---|---|---|---|
| W1 | No loading state. The content area stays empty until the plugin returns, so a large log or scan opens to a blank window that looks broken. The plugin-host spec asks for this: "While a file opens, its tab SHALL show that it's loading". | `Sources/Host/Documents/DocumentViewController.swift:97-130`; `Sources/Host/Components/HolderViewController.swift` | Apple, [HIG: Loading](https://developer.apple.com/design/human-interface-guidelines/loading); also a spec requirement the code misses | Put a spinning `NSProgressIndicator` in the holder only once an open has taken about half a second, so fast opens never draw it and the open benchmark doesn't move. Remove it in `show` and `fail`. | S | open |
| W2 | The sidebar can only be hidden by dragging its divider: no toolbar button, no View > Hide Sidebar. And because the sidebar item is removed and inserted again after every save and reload, a collapsed sidebar comes back and its width resets. | `DocumentViewController.swift:376-389` (`installSidebar`), called at 240, 327 and 404 | Apple, [HIG: Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars) (show/hide button and View menu items) | Add the system `.toggleSidebar` toolbar item and a View menu item with `toggleSidebar:` (AppKit flips its title). On refresh, replace the content of the existing split item instead of the item, and give the split view an `autosaveName` so width and collapse survive. | S–M | open |
| W3 | Every plugin command lands in one run after the flexible space, so the system draws them on one piece of glass. A PDF in Edit mode shows eight buttons in one capsule: zoom in and out, Text Box, Sign, Highlight, Rotate Left, Rotate Right and Delete Page. Seen in the PDF and image Edit mode captures. | `Sources/Host/Documents/DocumentWindowController.swift:321-325` | Apple, [HIG: Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars) (group by function, about three groups) | Insert a `.space` between commands that aren't edit tools and those that are. The host already has `isEditTool`, so it stays format-free. | S | open |
| W4 | Document windows have no minimum size, so they can be shrunk until the toolbar and content have no room. | `DocumentWindowController.swift:29-37` | Practice | Set `window.contentMinSize`, about 480 × 320. | S | open |
| W5 | Open windows don't come back after quitting and relaunching. Preview restores them, subject to the system's "Close windows when quitting an application" setting. No spec covers it. | `DocumentWindowController.swift:29-37`; `Sources/Host/App/AppDelegate.swift` | Practice | Maintainer's call. If wanted, AppKit's window restoration (`restorationClass`, encoding a bookmark to the file and the plugin id) reopens through `openInWindow` and already follows the system setting. | M | open |
| W6 | The "No enabled plugin opens …" alert tells the user to edit "your config", though Settings now edits extensions and turns plugins on. It offers only OK. | `AppDelegate.swift:252-258` | Practice (an error alert names the fix and offers it) | Point at Settings and add an Open Settings button that opens the matching plugin pane. | S | open |
| W7 | Recovery notices and save failures put the whole sentence in the alert's title and leave the message empty. | `DocumentWindowController.swift:84-112, 251-255` | Taste ([HIG: Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts) favors a short title with details in the message) | Short title ("Couldn't save “notes.txt”"), the reason as `informativeText`. | S | open |

## Menus and shortcuts

| ID | Finding | Where | Rule | Direction | Size | Status |
|---|---|---|---|---|---|---|
| M1 | There's no View menu. Show/Hide Sidebar, Show/Hide Toolbar and Enter Full Screen have no menu home, and zoom and Wrap Lines live in Commands. Preview's View menu holds its sidebar, toolbar, full-screen and zoom items. | `Sources/Host/App/MainMenu.swift:30-82` | Apple, [HIG: The menu bar](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar) ("Provide a View menu even if your app supports only a subset of the standard view functions") | Add a View menu with the standard selectors `toggleSidebar:`, `toggleToolbarShown:` and `toggleFullScreen:`; AppKit keeps their titles current. See M2 for the plugin commands. | S | open |
| M2 | The plugin menu is titled "Commands" and mixes view commands (Zoom In, Actual Size, Wrap Lines) with Edit Mode and edit tools (Crop, Text Box, Rotate Left, Delete Page). Mac menus are named for what they hold; Preview puts zoom in View and rotate and crop in Tools. | `MainMenu.swift:5-28` | Apple (menu bar: app-specific menus between View and Window, short titles); the View/Tools split is practice | Route by the existing `isEditTool`: other commands into View, Edit Mode and edit tools into a Tools menu. The Settings conflict check skips the plugin menu by its title and would need the new names (`Sources/Host/Settings/KeyRecorder.swift:17`). | M | open |
| M3 | Open With exists only as the toolbar pop-up, so it's out of reach with the toolbar hidden or from the keyboard. In icon-only mode its "Open With" label never shows and it has no tooltip, so it reads as a bare "PDF" beside a subtitle that also says "PDF". | `DocumentWindowController.swift:338-348`; subtitle at 72 | Apple, [HIG: Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars) (every toolbar item is also a menu command) | Add File > Open With, a submenu built from `catalog.openWithChoices` with the current plugin checked, through the same `reopenWith` path. Give the pop-up a tooltip. Keeping the plugin name as the subtitle is taste. | S | open |
| M4 | Standard items are missing: Hide Others and Show All in the app menu; Zoom and Bring All to Front in Window; no Help menu. The HIG asks for Minimize and Zoom in the Window menu so Full Keyboard Access can reach them. Preview has all of these. | `MainMenu.swift:47-54, 76-80` | Apple, [HIG: The menu bar](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar) | Add `hideOtherApplications:` (⌥⌘H), `unhideAllApplications:`, `performZoom:` and `arrangeInFront:`. A Help menu with one item opening the project's docs, set as `NSApp.helpMenu` so macOS adds its search field. | S | open |
| M5 | File has no Open Recent, though every open already calls `noteNewRecentDocumentURL`, and no Revert to Saved, though Don't Save already has the code (`discardEdits`). Preview has both. | `MainMenu.swift:55-61`; `AppDelegate.swift:275`; `DocumentViewController.swift:245` | Apple, [HIG: The menu bar](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar) (File menu) | Open Recent: a submenu holding a Clear Menu item (`clearRecentDocuments:`); AppKit fills it. Revert to Saved…: ask first, then `discardEdits()`. Whether Revert is wanted is the maintainer's call. | S | open |
| M6 | Two defaults take standard meanings. ⌘E is Edit Mode, but Apple's standard ⌘E is "Use the selection for a find operation", which Preview keeps; Preview shows its Markup toolbar with ⇧⌘A. ⌥⌘W is Wrap Lines, but ⌥⌘W means "Close all windows in the app". Also, Sign's ⌃⌘S is Strike Through Text in Preview, while Peeker's Highlight (⌃⌘H) and Text Box (⌃⌘T) match Preview. | `Sources/Host/App/Shortcut.swift:14`; `Plugins/text/TextPlugin.swift:18`; `Plugins/pdf/PDFPlugin.swift:14` | Apple, [HIG: Keyboards](https://developer.apple.com/design/human-interface-guidelines/keyboards) (standard shortcuts) | ⌘E is in the documents spec, so it's the maintainer's call; ⇧⌘A would match Preview. Give Wrap Lines no default, or a free combination. Consider Sign without a default so ⌃⌘S stays free for a later strike-through tool. | S | open |
| M7 | Zoom differs per plugin. Image has Zoom In, Zoom Out, Zoom to Fit (⌘9) and Actual Size (⌘0); PDF and text have only In and Out, so ⌘0 does nothing there; Markdown has no zoom at all. Preview's View menu has all four. | `Plugins/pdf/PDFPlugin.swift:11-12`; `Plugins/text/TextPlugin.swift:16-17`; `Plugins/markdown/MarkdownPlugin.swift:9`; `Plugins/image/ImagePlugin.swift:18-21` | Practice (one app, one set of zoom commands) | PDF: Actual Size (`scaleFactor = 1`) and Zoom to Fit (`autoScales = true`). Text: Actual Size back to the default font size. Markdown: zoom through the scroll view's magnification. Each is a small change inside its plugin. | S each | open |
| M8 | The menu bar icon can't be turned off from Peeker; the HIG says people, not the app, decide whether an extra is in the menu bar. With no window open it's Peeker's only menu, and it has no Open…. The app-presence spec requires the icon whenever Peeker runs. | `Sources/Host/App/MenuBarItem.swift:49-60` | Apple, [HIG: The menu bar](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar) (menu bar extras); spec decision | Maintainer's call. Smallest step: add Open… to the icon's menu. A "Show in menu bar" setting would rely on reopening from the Dock or Spotlight, which already shows Settings. | S–M | open |
| M9 | Spec drift: the quick-look-panel spec says Open at Login is "in the menu bar icon's menu and in the app menu", but the app menu has none and a test asserts it doesn't. | `openspec/specs/quick-look-panel/spec.md` (The app can open at login); `Tests/MainMenuTests.swift:5-12` | Spec accuracy | Update the spec to match the code. | S | open |

## Settings

| ID | Finding | Where | Rule | Direction | Size | Status |
|---|---|---|---|---|---|---|
| S1 | Settings always opens on General. The model, and its selection, is made fresh each time the window opens, so the last pane is forgotten even within one session. | `Sources/Host/Settings/SettingsWindowController.swift:20`; `AppDelegate.swift:202-213` | Apple, [HIG: Settings](https://developer.apple.com/design/human-interface-guidelines/settings) ("Restore the most recently viewed pane") | Keep the selected pane in `UserDefaults` as a short string (`general`, `plugin.pdf`) and read it when the model is made. | S | open |
| S2 | The zoom button is active, because the window is resizable; minimize is already dimmed. Visible in the Settings captures. | `SettingsWindowController.swift:67` | Apple, [HIG: Settings](https://developer.apple.com/design/human-interface-guidelines/settings) ("Dim a settings window's minimize and maximize buttons") | Keep resizing and disable the button: `window.standardWindowButton(.zoomButton)?.isEnabled = false`. | S | open |
| S3 | The field for adding an extension is a blank box: `labelsHidden()` hides its title and without a `prompt` there's no placeholder. Visible in the plugin pane capture. | `Sources/Host/Settings/ExtensionTokens.swift:37-41` | Practice (a field says what it takes) | `TextField("Extension", text: $draft, prompt: Text("Add an extension"))`. | S | open |
| S4 | All four plugin panes use the same symbol, `puzzlepiece.extension`, so the sidebar shows four identical icons. | `SettingsWindowController.swift:94` | Taste (one symbol per meaning) | Let each plugin name its own symbol (a `symbol` on the `Plugin` protocol with a default), so the host still knows no formats. | S | open |
| S5 | One feature has several names: the General toggle says "Quick look panel", the Permissions header and the menu bar line say "Space in Finder", the docs say "Space panel", and the toggle's lowercase "look" differs from "Quick Look" in its own footer. | `Sources/Host/Settings/GeneralPane.swift:13, 22`; `Sources/Host/Settings/PermissionsPane.swift:30`; `MenuBarItem.swift:31` | Practice (copy) | Pick one name and use it everywhere. Product call. | S | open |
| S6 | The Permissions pane also holds Open at Login and the Default app list. Someone looking to make Peeker their PDF app won't look under Permissions. | `PermissionsPane.swift:32-55` | Taste (group settings by the user's task) | Move Open at Login and Default app to General, leaving Permissions for Accessibility and Finder control. Maintainer's call. | S | open |

## Space panel

| ID | Finding | Where | Rule | Direction | Size | Status |
|---|---|---|---|---|---|---|
| P1 | The panel is always 55% × 75% of the main screen's visible area, centered. A resize lasts only until quit, and the shape ignores the file: on a portrait display it's a tall column even for a wide photo. | `Sources/Host/QuickLook/QuickLookPanel.swift:10-14` | Taste (the app remembers) | Remember the frame with `setFrameAutosaveName`. Sizing to the content is a bigger call and must not slow the panel down. | S | open |

## Text and Markdown

| ID | Finding | Where | Rule | Direction | Size | Status |
|---|---|---|---|---|---|---|
| T1 | Wrap Lines doesn't show its state: no checkmark in the menu, no selected look in the toolbar, and its title never changes. The only way to tell is to look at the text. | `DocumentWindowController.swift:186-189` (menu state comes only from `activeCommand`); `Plugins/text/TextDocument.swift:175-178` | Practice (a toggle shows its state with a checkmark); [HIG: The menu bar](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar) asks the same of show/hide items | Let a document report whether a command is on, one optional contract method next to `unavailableReason`, and set the menu item's state from it. | S–M | open |
| T2 | Zoom and wrap reset for every file and every launch. | `TextDocument.swift:20-21` | Taste (the app remembers) | Keep the last font size and wrap setting in `UserDefaults`, inside the plugin. | S | open |
| T3 | Task boxes are the characters ☐ and ☑ carrying a link. To VoiceOver this is most likely a link named after a ballot-box character rather than a checkbox with a state, and the target is one 15 pt glyph. A click writes the file at once with no Undo, which the Markdown spec chose. | `Plugins/markdown/MarkdownRenderer.swift:76-79`; `Plugins/markdown/MarkdownDocument.swift:93-107` | Apple, [HIG: Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility); Undo is a spec decision | Check with VoiceOver first. Then consider symbol attachments (`square`, `checkmark.square`) with an accessibility label per task, and an undo that ticks the task back. | M | open |

## PDF

| ID | Finding | Where | Rule | Direction | Size | Status |
|---|---|---|---|---|---|---|
| D1 | The find bar sits under the toolbar. It's pinned to the top of the content, which in a full-size-content window runs under the toolbar, so the search field overlaps the window title and the match count hides behind the toolbar buttons. Seen in the viewer flow's Find capture; the offscreen layout check puts a view pinned this way inside the toolbar's 52 points. | `Plugins/pdf/PDFFindContainer.swift:87-92` | Apple, [HIG: Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars) and [Materials](https://developer.apple.com/design/human-interface-guidelines/materials) (content and bars sit below the toolbar, separated by the scroll edge effect); also a plain bug | Pin the bar to `safeAreaLayoutGuide.topAnchor`, as the text plugin's note bar does (`TextDocument.swift:254`). A little more work: hand the bar to the PDF view's own scroll view (`findBarView`, `isFindBarVisible`; `NSScrollView` is a find bar container), so it sits where the system find bar sits in text files. | S | open |
| D2 | On the signature pad, the signature line uses `separatorColor` on a canvas that's always white. In dark mode the line is invisible; in light mode the white canvas has no edge against the sheet. Seen in the offscreen renders and the pdf-edit capture. | `Plugins/pdf/SignaturePad.swift:119-126` | Apple, [HIG: Color](https://developer.apple.com/design/human-interface-guidelines/color) (don't repurpose semantic colors; they assume the system's own backgrounds) | The canvas is paper, so draw the line and a 1 pt border in fixed grays, such as black at 25%. | S | open |

## Image

| ID | Finding | Where | Rule | Direction | Size | Status |
|---|---|---|---|---|---|---|
| I1 | The Rotate & Resize popover hangs from the top middle of the image area, not from its toolbar button. The image area runs under the toolbar, so the popover sits on the toolbar and covers the Open With pop-up. Seen in the image-edit capture. | `Plugins/image/TransformPanel.swift:66-71`; `Plugins/image/ImageDocument.swift:142-145` | Apple, [HIG: Popovers](https://developer.apple.com/design/human-interface-guidelines/popovers) (point to the element that revealed it; don't cover it or other essential content) | Show it from the toolbar item with `NSPopover.show(relativeTo:)` (macOS 14), which needs the host to pass the item. Until then, anchor it to `scrollView.safeAreaRect` so it at least clears the toolbar. | S–M | open |
| I2 | ⌘R does two things: in a PDF it rotates the page right (⌘L rotates left); in an image it opens Rotate & Resize, and images have no direct rotate or ⌘L. In Preview ⌘L and ⌘R rotate images too, and Adjust Size… has no shortcut. The image spec defines ⌘R this way. | `Plugins/image/ImagePlugin.swift:24`; `Plugins/pdf/PDFPlugin.swift:16-17` | Practice (one shortcut, one meaning); spec decision | Maintainer's call. Give images Rotate Left (⌘L) and Rotate Right (⌘R) as edit tools, and leave Rotate & Resize without a shortcut. | S | open |
| I3 | A crop can only be applied with Return. Choosing Crop dims the image and waits for a drag; nothing on screen says Return crops and Escape cancels, and there's no Crop or Cancel button. Choosing Crop again from the toolbar or menu cancels and starts over, so a mouse-only user can't finish a crop. | `Plugins/image/CropOverlay.swift:92-106`; `ImageDocument.swift:128-140` | Practice (honest state; no action hidden behind a key) | Small Crop and Cancel buttons by the selection, with Return and Escape as their key equivalents. Or make choosing Crop while a selection exists apply it. | S–M | open |
| I4 | Animated images play and loop whatever the Reduce Motion setting, and pausing takes a click on the image, with no menu item or key. The image spec chose autoplay and click to pause. | `Plugins/image/AnimationPlayer.swift:15-20`; `Plugins/image/ImageCanvas.swift:15-18` | Apple, [HIG: Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) (Reduce Motion); spec decision | Start paused when `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` is on, and add a Play/Pause command so the menu and keyboard reach it. | S | open |

## Accessibility

| ID | Finding | Where | Rule | Direction | Size | Status |
|---|---|---|---|---|---|---|
| A1 | Some edit tools work only with a mouse. PDF marks (highlights, text boxes, signatures) are selected, moved and resized only by clicking and dragging, with no arrow-key nudge and no accessibility elements; the crop rectangle is the same (see I3). | `Plugins/pdf/EditController.swift:206-307`; `EditOverlay` at 311; `CropOverlay.swift:55-98` | Apple, [HIG: Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) (Full Keyboard Access) | Start small: arrow keys move the selected mark (Shift for larger steps) and Tab cycles marks on a page; crop starts with a rectangle around the whole image that the keyboard can shrink. Accessibility elements for marks can follow. | M–L | open |
| A2 | When the shortcut recorder refuses a key ("⌘P is used by Print."), the reason shows as red caption text for three seconds and disappears. VoiceOver isn't told. | `Sources/Host/Settings/KeyRecorder.swift:89-95` | Apple, [HIG: Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) | Post an announcement with the reason (`NSAccessibility.post` with `.announcementRequested`) and keep the text until the next recording. | S | open |

## Liquid Glass and icons

| ID | Finding | Where | Rule | Direction | Size | Status |
|---|---|---|---|---|---|---|
| G1 | Peeker has no app icon: no asset catalog and no Icon Composer file. The Dock, Finder, the About panel, Login Items and every Open With menu show the generic app icon. | `project.yml` (no icon setting); no `.icon` or `.xcassets` in the repo | Apple, [HIG: App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons) (a layered icon with default, dark, clear and tinted appearances) | Design a layered icon in Icon Composer and add it to the app target. The look is the maintainer's call. | M | open |

## What already holds up

Keep these when working through the list.

- **The save prompt** is AppKit's convention: a sheet on its window with Save, Don't Save (⌘D) and Cancel, and quitting walks each edited window in turn (`DocumentWindowController.swift:229-244`, `AppDelegate.swift:117-133`).
- **Edited state** shows in the close button through `isDocumentEdited`, and Save is enabled only while there's something to save.
- **Recovery copies instead of autosave** keep typing safe without writing the user's file behind their back.
- **The toolbar is a standard `NSToolbar`** in the unified style, with plain SF Symbols, labels and accessibility descriptions, no custom backgrounds, and one tinted item: the Edit toggle while it's on (captures).
- **The sidebar is a split-view sidebar item**, so it gets the system glass, and the info panel at its foot is information, not controls.
- **Unavailable commands are disabled with their reason** as the tooltip (Delete Page on a one-page PDF), and when a file can't be edited, Edit Mode in the menu stays enabled so choosing it says why, while the toolbar button is dimmed with the reason as its tooltip.
- **Waiting tools show that they're waiting**: the toolbar item stays selected and the pointer becomes a crosshair or a highlighter.
- **Settings** is a grouped SwiftUI form with a sidebar of panes, a window title that follows the pane, changes applied at once, footers that explain, and a locked-config notice that says why controls are off. Turning a plugin off keeps its extensions and shortcuts.
- **Permission states** show a symbol and a word, never color alone, and refresh while System Settings is open beside them.
- **The menu bar icon** is a template symbol with a short menu ending in Settings… and Quit; its red dot comes with a menu line and a VoiceOver label.
- **The Dock icon appears only with windows**, and reopening Peeker from the Dock or Spotlight with nothing open shows Settings.
- **Text files** use the system find bar, the system monospaced font, and smart quotes and dashes off; a read-only note sits at the top.
- **The locked-PDF screen** is centered, focuses the password field, unlocks on Return and says "Wrong password." in place.
- **The signature sheet** puts Done on the trailing side as the default with Cancel beside it on Escape, and Done stays disabled until something is drawn.
- **The Space panel** never takes focus from Finder, and unsupported files still get Finder's Quick Look.

## Needs a screen check

Code reading and the existing captures can't settle these. All captures were in dark mode.

- **VoiceOver**: what it says for the Open With pop-up, the Edit toggle and its state, PDF thumbnails, the Markdown outline, the info panel, Markdown task boxes (T3) and the crop overlay.
- **Keyboard focus**: Tab order through Settings panes, the PDF find bar, the signature sheet and the Rotate & Resize popover (focus starts on the panel, not a field); reaching the toolbar with Control-F5.
- **Light mode**: every surface, especially Markdown code blocks (`quaternarySystemFill`), the crop size label and the text box size controls over a page.
- **Reduce Transparency, Increase Contrast and the Clear and Tinted glass setting**: the sidebar over content, the toolbar capsules, the Edit tint, and the Space panel's transparent title bar over text and thumbnails.
- **Scroll edge effect in text files**: `TextDocument.swift` notes that TextKit 2 registered with the title bar's edge effect; with TextKit 1, check whether text scrolling under the toolbar still gets it.
- **Toolbar groups after W3**: how the system groups the glass once a space splits the commands.
- **Disabled switches**: in the locked-config capture, the disabled toggles look the same as enabled ones.
- **Settings title on first open**: one capture shows "Settings" rather than "General" before any pane was clicked.
- **Proxy icon and title menu**: whether the document icon and the path menu appear on hover in the macOS 26 title area.
- **Menus AppKit adds by itself**: which tab and full-screen items appear in Window and View once a View menu exists (M1).
