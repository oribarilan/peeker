# Tasks

## 1. PDF find bar below the toolbar (D1)

- [x] 1.1 Write a failing test in `Tests/PDFFindTests.swift`: put the find container in a window with a full-size content view and a toolbar, show the bar, and check its frame in window coordinates lies within `window.contentLayoutRect`; then pin the bar to `safeAreaLayoutGuide.topAnchor` in `PDFFindContainer` and verify the test and the existing find tests pass

## 2. Rotate & Resize below the toolbar (I1)

- [x] 2.1 Write a failing test in `Tests/ImageToolsTests.swift`: in a window with a full-size content view and a toolbar, the popover's anchor rect for the image scroll view, in window coordinates, lies within `window.contentLayoutRect`; then build the anchor from `safeAreaRect` in a static function used by `TransformPanel.show(below:)` and verify the test and the existing panel tests pass

## 3. Crop and Cancel buttons (I3)

- [x] 3.1 Add the placement function for the crop controls with tests in `Tests/ImageToolsTests.swift`: below the selection's bottom-right with the trailing edges aligned, inside the corner when there's no room below, clamped into the visible rect horizontally; verify the tests pass
- [x] 3.2 Add `CropControls` (Cancel, Crop as default with Return, Cancel with Escape) as a subview of the image scroll view, hidden until a selection exists and repositioned on drags, scrolling, zooming and resizing; `ImageDocument.startCrop()` passes the scroll view; verify with tests: no controls before a drag, visible after one, clicking Crop crops as one edit, clicking Cancel changes nothing, controls are removed after either, their size doesn't change with magnification, and the existing Return and Escape tests still pass
- [x] 3.3 Update the doc comment on `CropOverlay` to mention the buttons; verify it reads correctly

## 4. Loading spinner (W1)

- [x] 4.1 Write failing tests in `Tests/DocumentLifecycleTests.swift` with a stub plugin whose open takes about a second: a spinning progress indicator is in the content after about 600 ms and gone once the document shows; a stub that fails slowly ends with the failure view and no spinner; a fast open never adds one. Then add the delayed spinner task to `DocumentViewController.load()` and verify the tests pass

## 5. Screen tests

- [x] 5.1 Give `press` in `scripts/screen/drive.swift` an optional role to search within, and update its usage comment; verify by building the driver as the screen-test script does
- [x] 5.2 Image-edit flow: crop with the Crop button inside `AXScrollArea` instead of Return, and after opening Rotate & Resize check the popover's top is below the toolbar's bottom; viewer flow: after Cmd+F check the find field's top is below the toolbar's bottom; verify the scripts pass `bash -n`

## 6. Wrap-up

- [x] 6.1 Add a line under Unreleased in `CHANGELOG.md` and mark D1, I1, I3 and W1 in `docs/design-review-2026-11-01.md` as in progress (the commit hash goes in once committed); verify `openspec validate --all --strict`
- [x] 6.2 Run `scripts/build.sh` and `scripts/build.sh test`; verify all tests pass with no new warnings
- [x] 6.3 With the maintainer's go, run `scripts/screen-test.sh`; verify the new steps pass and look at the crop, popover and find captures
- [x] 6.4 With the maintainer's go, run `scripts/bench-ab.sh main` once; verify no regression on the open benchmarks

## Workflow follow-up

- Once committed (on the maintainer's request), set D1, I1, I3 and W1 to fixed with the commit hash in the design review.
- Archive the change with `/opsx:archive`.
