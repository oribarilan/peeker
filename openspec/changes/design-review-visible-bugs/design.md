# Design

## Context

Document windows use a full-size content view with a unified toolbar, so every plugin's content view starts at the top of the window and runs under the toolbar. AppKit reports the covered strip through the safe area (`safeAreaLayoutGuide`, `safeAreaRect`, `window.contentLayoutRect`). The text plugin's read-only note already pins to it (`TextDocument.swift:254`); the PDF find bar and the Rotate & Resize popover don't, which causes D1 and I1.

The image canvas is the document view of a magnifying scroll view. The crop overlay is a subview of the canvas, so anything it draws scales with zoom. That's fine for the dimming and handles, but buttons drawn there would grow and shrink.

`DocumentViewController.load()` runs the plugin's open in a task and calls `show` or `fail`, both of which replace the content holder's only subview. Until then the holder is empty.

## Goals / Non-Goals

**Goals:**
- Fix D1, I1, I3 and W1 as the specs in this change describe.
- Keep the open path as fast as today.

**Non-Goals:**
- Moving PDF find to the system find bar.
- Pointing the Rotate & Resize popover at its toolbar button. That needs the host to hand the toolbar item to the plugin, a contract change.
- A spinner in the Space panel, or inside window tabs (system tabs have no place for one).
- Keyboard-adjustable crop rectangles (A1 in the review).

## Decisions

**D1: pin the find bar to the safe area.** `PDFFindContainer` pins the bar's top to `safeAreaLayoutGuide.topAnchor` instead of `topAnchor`. The pages keep starting at the container's top while the bar is hidden, so they still scroll under the toolbar's glass. While it shows, the pages start below the bar, as today. Considered: the PDF view's own scroll view as an `NSScrollView` find bar container. That would match text files, but the bar's count and buttons and their spec checks would all need redoing. The maintainer chose the pin.

**I1: anchor the popover to the scroll view's safe area.** `TransformPanel.show(below:)` builds its anchor rect from `view.safeAreaRect` instead of `view.bounds`: one point high, at the middle of the safe area's top edge, with the same preferred edge. The rect is a small static function so a test can check it against `window.contentLayoutRect` without showing a popover. The button, the menu item and Cmd+R all go through `showTransform()`, so they all get the fix.

**I3: Crop and Cancel buttons in the scroll view, not the canvas.** A small `CropControls` view (an `NSStackView` with Cancel and Crop, Crop trailing as the default button) is added by `CropOverlay` as a subview of the image's scroll view, above the clip view, so zoom never scales it. It's hidden until a selection exists.
- Crop has Return as its key equivalent, so it gets the default-button look, and Cancel has Escape. The overlay's existing `keyDown` stays for keypad Enter and for the time before a selection exists. Both paths end in `finish`, which removes the overlay and the controls once, so a key can't crop twice.
- Placement is a pure static function: given the controls' size, the selection rect and the visible rect, all in scroll-view coordinates, and whether those are flipped (`NSScrollView` is), it returns the frame. The controls' trailing edge lines up with the selection's right edge, 6 points below its bottom edge. When that would leave the visible rect, they go 6 points inside the selection's bottom-right corner instead. They're always clamped horizontally into the visible rect.
- The overlay repositions the controls after each drag step, when it's resized along with the image, and when the clip view's bounds change (scrolling, zooming). It observes the clip view through `NSView.boundsDidChangeNotification` and stops observing in `finish`.
- `ImageDocument.startCrop()` passes the scroll view to the overlay. Nothing outside the image plugin changes.

**W1: a delayed spinner in the content holder.** At the start of `load()`, when no plugin document is showing yet, the controller starts a second task that sleeps 500 ms and then, if the open is still running, puts a centered spinning `NSProgressIndicator` (accessibility label "Loading") in the holder. The open task cancels it before calling `show` or `fail`, and since both replace the holder's subview, a spinner that already showed goes away. A reload after a change on disk has a document showing, so it gets no spinner. Reopen after a failure does, which is right. Considered: a timer that's always armed. A task that's cancelled is less code and costs nothing on a fast open beyond creating it.

**Screen tests.** The driver's `press` takes an optional role to search within, so a step can press the Crop button inside the image area (`AXScrollArea`) rather than the toolbar's Crop item, which has the same title. The image-edit flow crops with that button instead of Return, and after opening Rotate & Resize checks the popover's top is below the toolbar's bottom (`frame` of `AXPopover` and `AXToolbar`). The viewer flow checks the find field's top is below the toolbar's bottom.

## Risks / Trade-offs

- [The crop controls are a foreign subview inside `NSScrollView`; `tile()` could lay out over them or the scrollers could draw on top.] → They're added last and positioned by frame. If the scroll view misbehaves, wrap it in a plain container view as the image document's content view and put the controls there.
- [The safe area of the image scroll view could come back zero if the scroll view adjusts its own insets.] → The anchor test runs in a real window with a toolbar and fails if the rect overlaps the toolbar. If it does, fall back to converting `window.contentLayoutRect`.
- [The spinner adds a task to every open.] → It's cancelled before it does anything on a fast open. Run `scripts/bench-ab.sh` once for the change (with the maintainer's go) to confirm there's no regression.
- [While the find bar shows, the strip under the toolbar above the bar shows the window background rather than pages.] → Same as the text plugin's note. Accepted.
