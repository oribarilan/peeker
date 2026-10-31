# Tasks

## 1. Host

- [x] 1.1 Add `PluginDocument.printJob` (nil by default) to `Sources/PeekerKit/Plugin.swift`; verify `scripts/build.sh test` passes with no plugin changed
- [x] 1.2 Add File > Print… (Cmd+P) and Edit > Find Previous (Shift+Cmd+G, `.previous` tag) to `MainMenu`; add `printDocument(_:)` to `DocumentWindowController` (finish typing, take the job with a copy of the shared print info, title it with the file name, run it as a sheet) with its menu check; make `finishTyping()` refocus `focusView ?? contentView`; verify with tests that the menu has both items with their keys, that Print is enabled only for an opened document with a print job, and that `shortcutConflict` names Print for Cmd+P and Find Previous for Shift+Cmd+G

## 2. Printing per format

- [x] 2.1 Add the shared text-printing helper to PeekerKit (offscreen text view at the printable width, light appearance, white background, header and footer on, fit horizontal pagination); verify with a test that prints an attributed string to a PDF file and finds its text and the job title in the output, on more than one page for long text
- [x] 2.2 Text: `printJob` prints the current text, unsaved edits included, in the current font, black, wrapped even when Wrap Lines is off; verify with tests: unsaved typing appears in the printed PDF, the print view's text is black on white in the light appearance, and a line wider than the page wraps (the printed PDF is no wider than the paper and holds the whole line)
- [x] 2.3 Markdown: `printJob` prints a copy of the rendered text in the light appearance; verify with a test that the printed PDF holds "Title" and no `#` for a `# Title` file
- [x] 2.4 Image: the decoder also returns the image's size in points (resolution and EXIF orientation applied); `printJob` prints it centered, fit pagination, landscape for wide images; verify with tests: size for a 72 dpi image, a 144 dpi image and an orientation-6 image, landscape for a wide image and portrait for a tall one, and a 64 × 64 icon printed to PDF is drawn at 64 × 64 points, not enlarged
- [x] 2.5 PDF: `printJob` prints the view's document fitted to the paper with auto-rotate; verify with a test that an unsaved text box reading "Approved" appears in the printed PDF's text

## 3. PDF find bar

- [x] 3.1 Put the PDF view in a plain container (`contentView`), set `focusView` to the PDF view; verify the existing PDF and edit-mode tests pass
- [x] 3.2 Add the find bar (search field, count, previous and next, Done), made on first use and placed above the pages; search with PDFKit's background search, case- and accent-insensitive, restarting on each keystroke; highlight all matches and select and scroll to the current one; "Not found" when nothing matches; verify with tests on generated PDFs: count and "1 of 3" for 3 matches across pages, "cafe" finds "Café", a PDF with no text says "Not found", and a search in Edit mode leaves the pending edits and undo history empty
- [x] 3.3 Next and previous with wrap-around from Return and Shift+Return in the field, the buttons, and Find Next and Find Previous from the menu with the field focused or not; Escape and Done close the bar, clear the highlights and keep the selection; Cmd+G after closing uses the last search; Find is refused in the Space panel; verify with tests for each

## 4. Wrap-up

- [x] 4.1 Update `openspec/gaps.md` (PDF search and printing leave "Missing next to Preview"; Find and Print in the Space panel go under future work) and the README's feature lines if they list what each plugin does; verify `openspec validate --all --strict` passes
- [x] 4.2 Run `scripts/build.sh test` and `scripts/check-plugin-imports.sh`; verify all tests pass and the build has no warnings
- [ ] 4.3 In the built app (needs the maintainer's hands-off go): Cmd+F in a PDF finds and steps through matches, Cmd+P opens the print panel sheet for each format and its preview shows the expected page; verify by screenshots

## Workflow follow-up

- Archive after settings-window and pdf-fill-and-sign, which change the same specs.
- `scripts/bench-ab.sh main` once with the maintainer's go, to confirm the container view didn't slow opening a PDF.
