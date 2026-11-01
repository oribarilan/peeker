# Tasks

## 1. Password-protected PDFs

- [x] 1.1 Add `PluginDocument.onReplace` and have the host show a replacement; verify with a test using a stub document that replaces itself: the window then shows the new content and commands
- [x] 1.2 Have the PDF check report a locked file, and add `LockedPDFDocument` with the lock form (window) or message (Space panel); unlocking builds a view-only `PDFPluginDocument` with info and hands it over; a wrong password says so and clears the field; verify with tests on a PDF written with a user password: open gives the lock screen, a wrong password keeps it with the message, the right one replaces it with a document showing the pages, `.unavailable` edit mode with the reason, and a print job

## 2. Image zoom

- [x] 2.1 Add the centering clip view, Actual Size (`zoom-actual`, Cmd+0) and the lower minimum magnification; verify with tests: Actual Size magnification for a known image and window, minimum magnification at most 1/8, the clip centers a smaller document view

## 3. Animated images

- [x] 3.1 Mark animated files in the decoder and play them with `CGAnimateImageAtURLWithBlock`, pausing and resuming on click; verify with tests on a generated three-frame GIF: frames advance, a click pauses (frame stays), another resumes; a two-page TIFF isn't animated

## 4. Wrap-up

- [x] 4.1 Update README, `openspec/gaps.md` (remove the closed gaps, correct the highlight line, explain why Find and Print in the Space panel wait) and `openspec/config.yaml`; verify `openspec validate --all --strict`
- [x] 4.2 Run `scripts/build.sh test` and `scripts/check-plugin-imports.sh`; verify all pass with no warnings
- [x] 4.3 In the built app (needs the maintainer's hands-off go): unlock a PDF, Actual Size and zoom out on an image, play and pause a GIF; verify by screenshots
