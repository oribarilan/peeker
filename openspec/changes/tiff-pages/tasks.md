# Tasks

## 1. Page Up and Page Down shortcuts

- [x] 1.1 Write failing tests in `ShortcutTests`: `pageup` and `opt+pagedown` parse and print back as config text; their display text is "Page Up" and "⌥Page Down"; their menu key equivalents are the page function keys; a view tool accepts bare Page Up while it still refuses a bare letter.
- [x] 1.2 Add `.pageUp` and `.pageDown` to `Shortcut.Key` (names, key codes, key equivalents, display text, reading them from key events) and let `Rules.viewTool` take them alone; mention them in the schema's shortcut description. Verify the 1.1 tests and the config schema tests pass.

## 2. Decoding by page

- [x] 2.1 Add a multi-page TIFF helper to `Tests/TestImages.swift` (pages of different sizes and colors) and write failing tests in `ImagePluginTests`: a three-page TIFF decodes with `pageCount` 3 and page 1 is the second picture; a GIF with several frames and a single TIFF have `pageCount` 1; the info rows of page 2 say "Page: 2 of 3" and give that page's dimensions.
- [x] 2.2 Pass a page index through `decode`, `decodeFull`, `info(of:)` and their helpers, add `pageCount` to `Decoded`, and add the page row. Verify the 2.1 tests and the existing image tests pass.

## 3. Pages in the Editor

- [x] 3.1 Write failing tests in `ImageDocumentTests`: a multi-page TIFF's tools include Next Page and Previous Page and a single image's don't; Next Page shows the second page (the canvas shows its picture, the info follows, `onSidebarChange` fires); Previous Page is unavailable on the first page and Next Page on the last; a page change at fit stays at fit and at another magnification keeps it.
- [x] 3.2 Add the page tools to `ImagePlugin.tools` and the page state, page switching and tool filtering to `ImageDocument`. Verify the 3.1 tests pass.
- [x] 3.3 Write failing tests for the thumbnail list: it has one row per page with the shown page selected; selecting a row shows that page; a page change from the tools moves the selection; the sidebar of a multi-page TIFF is the list above the info panel and a single image's is the info panel alone.
- [x] 3.4 Build the thumbnail list in `Plugins/image/` and return it from `makeSidebar()`. Verify the 3.3 tests pass.

## 4. Printing every page

- [x] 4.1 Write failing tests in `PrintTests`: a three-page TIFF's print operation has a page range of 1 to 3 and each page rect fits that page by the single-image rule; a single image's print job is unchanged.
- [x] 4.2 Build the paginating print view and use it in `printJob` for a multi-page TIFF. Verify the 4.1 tests pass and `scripts/build.sh test` passes with no new warnings.

## 5. Docs and checks

- [x] 5.1 Remove the multi-page TIFF line from `openspec/gaps.md`, add a CHANGELOG line under Unreleased, and verify `openspec validate --all` passes.
- [ ] 5.2 After the maintainer's go: check the queued "Multi-page TIFF pages" item in the real app (thumbnails, Page Up/Down, zoom, info, print panel, Peek panel), and run `scripts/bench-ab.sh main` once with no regression flagged.

## Workflow follow-up

- Commit when the maintainer asks, then bump the minor version in its own commit.
- Archive with `/opsx:archive`.
