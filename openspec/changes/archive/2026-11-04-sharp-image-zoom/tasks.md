# Tasks

## 1. Full-resolution decode

- [x] 1.1 Write failing tests in `Tests/ImagePluginTests.swift`: `ImagePlugin.fullSide(for:)` gives 4000 for 4000 × 3000, at most 16,384 for 30,000 × 1,000, and for 20,000 × 15,000 a side whose scaled size stays within 100 MP; `decodeFull` of a 2000 × 1000 PNG returns a 2000 × 1000 image in premultiplied sRGB; `decodeFull` of a PNG tagged with orientation 6 returns it upright, matching `decode`. Then move `decode`'s thumbnail-and-`displayReady` step into a helper and add `fullSide` and `decodeFull`; verify the new tests and `decodesNoLargerThanTheScreenNeeds` pass with `scripts/build.sh test`

## 2. Swapping it in

- [x] 2.1 Write failing tests in `Tests/ImageDocumentTests.swift` (suite `ImageZoom`, `offscreenWindow`, opened with `maxPixels: 1000`): opening a 2000 × 1000 PNG shows a 1000-pixel-wide image and starts no decode; after `zoom-actual` and awaiting `sharpening`, the canvas holds a 2000-pixel-wide image while the magnification and `canvas.imageRect` are unchanged; `zoom-in` does the same; `zoom-fit` then `zoom-in` starts no second decode and keeps the same image; `zoom-out` alone starts none; a 64 × 64 icon and an animated GIF never start one; setting magnification 2 and posting `NSScrollView.didEndLiveMagnifyNotification` starts one. Verify they fail for the right reason
- [x] 2.2 Write failing tests for edits and stale results: cropping to the left half after the full decode shows a 1000-pixel-wide image; rotating, then undoing before the decode finishes, ends with an unrotated 2000 × 1000 image; a save that finishes while a decode started before it is running ends with the saved file's size, then a fresh decode of it; dropping the last reference to a document with a running decode frees it (a weak reference goes nil) and the decode's end touches nothing. Verify they fail for the right reason
- [x] 2.3 Implement `sharpenIfNeeded()`, `sharpening`, `full`, the `generation` counter, `redraw()` from `full ?? base`, the save and `deinit` handling and the pinch observer in `Plugins/image/ImageDocument.swift`, as design.md describes; update the doc comments on `base` and `shownSize`. Verify every test from 2.1 and 2.2 and the existing image tests pass with `scripts/build.sh test`
- [x] 2.4 Measure a rotate preview on a 48 MP full decode on the main thread (a timed run in a test, not committed if it's flaky) and write the number into design.md's Risks. If it's over 100 ms, stop and bring it to the maintainer before going on

## 3. Docs and version

- [x] 3.1 Add an Unreleased line to CHANGELOG ("Photos stay sharp when zoomed in or at Actual Size."); in openspec/gaps.md cut the zoom part of the Images line and keep the multi-page TIFF part; check README.md says nothing about decoding at screen size (it didn't when this was written). Verify `openspec validate --all --strict`
- [x] 3.2 Bump `MARKETING_VERSION` in `project.yml` to `0.6.2-dev` (a fix), in its own commit after the change's, when the maintainer asks for the commits; verify `scripts/build.sh` succeeds

## 4. Screen test

- [x] 4.1 In `scripts/screen/viewer-flow.sh`, generate a photo larger than any screen (about 6000 × 4000) of one-pixel black and white stripes, open it, press Cmd+0, wait a second, screenshot the window and check a crop from its middle is sharp: neighbouring pixels differ by most of the black-to-white range on average, where an enlarged screen decode would read as grey. Keep the screenshot as evidence. Verify `bash -n scripts/screen/viewer-flow.sh`, and add "viewer flow, sharp Actual Size step" to `.local/screen-queue.md` until it has run

## 5. Wrap-up

- [x] 5.1 Run `scripts/build.sh` and `scripts/build.sh test` twice; verify all tests pass with no warnings
- [x] 5.2 Waiting for the screen: run `scripts/bench-ab.sh main` (with the maintainer's go); verify the gate passes and the open timings and memory for every image fixture are unchanged
- [x] 5.3 Waiting for the screen: run the viewer and image-edit screen flows (with the maintainer's go); verify they pass and look at the Actual Size capture

## Workflow follow-up

- Archive with `/opsx:archive` once done.

The four changes landed together, so they share one bump, to `0.7.0-dev` (8a40ced).
