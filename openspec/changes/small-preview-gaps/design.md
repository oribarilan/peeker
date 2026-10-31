# Design

## Context

`PDFPlugin.check` opens the file with CoreGraphics and throws "This PDF is password protected." for a locked file. The host then shows that message with Reopen. The image document is a layer-backed canvas in a magnifying scroll view, with magnification 1 meaning fit and a minimum of 1. The decoder reads one frame. The Space panel is a non-activating panel that never takes the keyboard, so Finder keeps arrows and Space.

## Goals / Non-Goals

**Goals:**
- Open locked PDFs view-only.
- Actual size and zoom below fit.
- Play animations.

**Non-Goals:**
- Editing or saving locked PDFs.
- Sharp zoom on big photos: decoding stays at screen size, so Actual Size on a big photo is soft. That's gap #3.
- Find and Print in the Space panel.

## Decisions

**Lock screen as its own document.** The check reports a locked file instead of throwing. `open` then returns a `LockedPDFDocument`:
- Its content view is the lock form. It has no sidebar or commands, and its edit mode is `.none`.
- Unlock opens a `PDFDocument`, calls `unlock(withPassword:)`, reads the info through a CoreGraphics document unlocked with the same password, and builds a `PDFPluginDocument` with the view-only reason.
- It hands that to the host through `onReplace`, and nothing keeps the password.
- In the Space panel the form shows only the message.

`PluginDocument.onReplace: ((any PluginDocument) -> Void)?` defaults to doing nothing. `DocumentViewController` sets it in `show` to call `show` again with the replacement. That already installs the sidebar, commands and toolbar. Considered: making the PDF document switch states internally. The host would still need to hear about the new sidebar and commands, so a replacement hook is simpler.

**Zoom.**
- A centering clip view (`constrainBoundsRect` centers when the document view is smaller than the clip) keeps a zoomed-out image in the middle.
- `minMagnification` is the smaller of 1/8 and the Actual Size magnification. Actual Size is the full image's pixel width divided by the backing scale and by the fitted image's width in points.
- New command `zoom-actual` (Cmd+0), from the read view too.

**Animation.**
- The decoder marks a file animated when it has several frames and its type is GIF, PNG, WebP or HEICS.
- The document runs `CGAnimateImageAtURLWithBlock`, which follows the file's delays and loop count, and puts each frame on the canvas.
- The block stops when the document is gone or paused. Pausing remembers the frame index, and resuming starts again from it (`kCGImageAnimationStartIndex`).
- A click on the canvas toggles pausing when it isn't in Edit mode. Animated files can't be edited anyway, since they have several frames.

## Risks / Trade-offs

- **Actual Size on a big photo** looks soft until sharp zoom exists. That's accepted.
- **Large animated WebPs** decode every frame at full size while playing. Typical animations are small.
- **Unlocking** happens on the main thread. `unlock(withPassword:)` is quick; a huge PDF is loaded the same way an ordinary open loads it.
