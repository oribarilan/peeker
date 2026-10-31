# Proposal

## Why

Three small gaps from `openspec/gaps.md` still send the maintainer to Preview: password-protected PDFs don't open at all, images can't be seen at actual size or smaller than fit, and animated images show only their first frame. Decided on 2026-10-31, after ranking the gaps.

## What Changes

- **Password-protected PDFs:**
  - In a window, the tab shows a lock, the file name, a password field and Unlock. A wrong password says so, and the password is never stored.
  - Once unlocked, the PDF shows as usual: pages, thumbnails, info, Find and Print. Edit is greyed out with the reason.
  - The Space panel says the PDF is password protected and that Open unlocks it in a window.
- **Image zoom:**
  - Actual Size (Cmd+0) shows one image pixel per screen pixel, centered.
  - Zoom Out can go below fit, down to an eighth (or less, when actual size is smaller). A zoomed-out image stays centered.
- **Animated images:** GIFs, animated PNGs, WebPs and HEIC sequences play in a loop as their files say, in windows and the Space panel. A click on the image pauses and resumes.
- **Host:** a document can hand the host a replacement for itself, which is how an unlocked PDF takes over from its lock screen.
- **Not included:** Find and Print in the Space panel. The panel never takes the keyboard from Finder, so the keys would need routing through the global key monitor and focus handed back and forth. That's left as future work in gaps.md.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `pdf`: opening password-protected PDFs.
- `image`: Actual Size, zooming out below fit, animated images.
- `plugin-host`: a document can replace itself.

## Impact

- `Sources/PeekerKit/Plugin.swift`: an optional `onReplace` on `PluginDocument`.
- `Sources/Host/Documents/DocumentViewController.swift`: shows the replacement.
- `Plugins/pdf/`: a lock-screen document, and the check and open learning about passwords.
- `Plugins/image/`: a centering clip view, the Actual Size command, playing animations.
- The open path is unchanged for ordinary files: the lock check reuses the CoreGraphics document the check already opens, and animation starts only for files with several frames.
