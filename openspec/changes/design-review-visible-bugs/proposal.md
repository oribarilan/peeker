# Proposal

## Why

The design review of 2026-11-01 (`docs/design-review-2026-11-01.md`) found four problems a user sees right away: the PDF find bar hides under the toolbar (D1), the Rotate & Resize popover covers the toolbar (I1), a crop can only be finished with Return (I3), and a slow open shows an empty window that looks broken (W1). They're the first theme taken from the review; menus and Settings polish come as later changes. Decided with the maintainer on 2026-11-01.

## What Changes

- **PDF find bar (D1):** the bar sits below the toolbar instead of under it, so the search field and match count are fully visible.
- **Rotate & Resize (I1):** the popover stays a popover but hangs from just below the toolbar, the same whether it's opened from the toolbar, the menu or Cmd+R. It never covers the toolbar.
- **Crop (I3):** once a rectangle is dragged, Crop and Cancel buttons appear just below its bottom-right corner (inside it when there's no room below). Return and Escape stay as their keys. Before the first drag nothing changes.
- **Loading state (W1):** when opening a file in a document window takes longer than about half a second, a spinner shows in the middle of the content until the file or its failure appears. Fast opens never draw it. The Space panel is unchanged.
- **Screen tests:** the image-edit flow crops with the Crop button and checks Rotate & Resize clears the toolbar; the viewer flow checks the PDF find bar sits below the toolbar. The spinner gets no screen step, since a slow open is hard to stage reliably.
- **Report:** the four findings are marked fixed in the design review with their commits.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `plugin-host`: the loading state belongs to the document window, shows only after a short delay, and isn't shown in the Space panel.
- `image`: Crop and Cancel buttons by the crop rectangle; the Rotate & Resize panel appears below the toolbar.
- `pdf`: the find bar sits below the toolbar.

## Impact

- `Sources/Host/Documents/DocumentViewController.swift`: a delayed spinner while `load()` runs, removed by `show` and `fail`.
- `Plugins/pdf/PDFFindContainer.swift`: the bar pinned to the safe area.
- `Plugins/image/TransformPanel.swift`, `ImageDocument.swift`: the popover anchored to the scroll view's safe area.
- `Plugins/image/CropOverlay.swift` (and maybe a small new view for the buttons): Crop and Cancel buttons kept beside the selection through drags, scrolling and zoom.
- `scripts/screen/image-edit-flow.sh`, `scripts/screen/viewer-flow.sh`: new steps.
- No plugin contract change. The open path adds one scheduled check per open and no work on fast opens; one `scripts/bench-ab.sh` run confirms it.
