# Tasks

## 1. Finding local images

- [x] 1.1 Write failing tests in `Tests/MarkdownPluginTests.swift` for resolving a source against a Markdown file's folder: a relative path, a subfolder, `..`, a percent-encoded name, a `<…>` destination with spaces, an absolute path, a `file:` URL, a `file:` URL with another host, a query or fragment ignored, `~` not expanded; `http:`, `https:`, `data:` and a custom scheme resolve to nothing. Then add the resolver in a new file in `Plugins/markdown/`; verify the tests pass
- [x] 1.2 Write failing tests for the check, using generated PNGs from `Tests/TestImages.swift` in a temporary folder: a PNG gives its pixel size; a JPEG with EXIF orientation 6 gives its turned size; a missing file, a folder, a text file named `.png`, a file over 20 MB (sparse file) and a header claiming over 50 megapixels give nothing. Then add the check (resource values, then an ImageIO header read with no cache, type conforming to `UTType.image`); verify the tests pass
- [x] 1.3 Write failing tests for `MarkdownPlugin.parse`: `Parsed.images` holds an entry per usable source as written, checks a repeated source once, skips images in table cells, stops after 50 usable images, and is empty without touching the disk for a file with no images. Then add the walk to `parse`; verify the tests pass

## 2. Rendering pictures

- [x] 2.1 Write failing tests for `MarkdownRenderer.render` with an `images` lookup: a known image becomes one attachment character with no `[alt]`, holding a transparent image of its pixel size and the alt text as its accessibility description; an unknown image still renders `[alt]` in the marker color; outline anchors after a picture point at their headings. Then add the attachment subclass and the lookup parameter; verify the tests pass and the existing Markdown tests still pass
- [x] 2.2 Write failing tests for the attachment's bounds under TextKit 2 and TextKit 1 text views: a 3000×1500-pixel picture in a 600-point line is 600×300 points and grows when the view widens, up to 3000×1500; a 120×40 picture stays 120×40 in any width. Then implement both bounds overrides; verify the tests pass

## 3. Decoding in the background

- [x] 3.1 Write failing tests in `MarkdownDocumentTests` (open with `editing: false`): right after opening, the text is laid out with the picture's space and `renderedText` contains no `[alt]`; the decoded image arrives afterwards at no more pixels than the drawn size times the backing scale (capped at 4,096 on the longest side) without changing the text or the attachment's bounds; a theme change refills the new attachments from the decoded cache without decoding again; releasing the document cancels the decode task before later pictures decode; a file whose header passes but whose data is damaged falls back to `[alt]` with the outline still jumping to the right headings. Then wire `MarkdownDocument`: pass `images` to every render, start one decoding task after the first render, fill attachments and redraw their ranges on the main thread, keep the cache by URL and modification date, cancel on deinit and on a newer render; verify the tests pass
- [x] 3.2 Write a failing test that a reload after the Markdown file changes keeps already-decoded pictures and decodes only new ones. Then make reload reuse the cache; verify the test passes

## 4. Printing

- [x] 4.1 Write failing tests in `Tests/PrintTests.swift` (`MarkdownPrinting`): printing from the Editor a file with a local image yields print text holding an attachment with a decoded image, sized to the page's text width for a wide image; a web image prints as `[alt]`; unsaved edits that add an image line print the picture. Then make `MarkdownEditor.printText` take the page width from the print info, find and decode images synchronously at twice the drawn size, and render with them; do the same in `MarkdownDocument.printJob`; verify the tests pass

## 5. Docs and version

- [x] 5.1 Add a CHANGELOG line under Unreleased ("The Peek panel and printing show images stored on your Mac in Markdown files; web images still show their alt text, so nothing is fetched."); remove "images show as their alt text;" from the Markdown line in `openspec/gaps.md`, leaving the rest of the line; verify `openspec validate --all --strict` passes
- [x] 5.2 In its own commit after the change's, bump `MARKETING_VERSION` in `project.yml` to the next minor `-dev` version (from `0.6.1-dev`, `0.7.0-dev`, unless another change bumped it first); verify `scripts/build.sh` shows the new version in the built app's Info.plist

## 6. Screen flow

- [x] 6.1 Add a step to `scripts/screen/markdown-edit-flow.sh`: put a generated PNG beside `notes.md` and an `![logo](logo.png)` line in it, then in the Peek panel step check that the text view's value holds no `[logo]`, and capture a screenshot as evidence; update the flow's expected files for the extra line; verify `bash -n scripts/screen/markdown-edit-flow.sh`
- [x] 6.2 Add "Markdown local images: run `scripts/screen-test.sh` (or just the Markdown flow) and look at the picture in the Peek panel" to `.local/screen-queue.md` and ask the maintainer for a go before running it, since it takes over the screen; verify every flow passes once run

## 7. Integration

- [x] 7.1 Run `scripts/build.sh` and `scripts/build.sh test`; verify all tests pass with no new warnings and the plugin import check passes with the new `ImageIO` and `UniformTypeIdentifiers` imports
- [x] 7.2 With the maintainer's go, run `scripts/bench-ab.sh` against the commit before this change; verify opening the Markdown fixtures (which have no images) doesn't regress. Then time the Peek panel by hand on a Markdown file with five photos against the same file with the image lines removed, and report both numbers with the change

The four changes landed together, so they share one bump, to `0.7.0-dev` (8a40ced).
