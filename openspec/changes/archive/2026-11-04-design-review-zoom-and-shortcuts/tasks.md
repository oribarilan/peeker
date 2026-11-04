# Tasks

Test first throughout: write or change the test, see it fail, then change the code. `scripts/build.sh test` runs the suites; PDF tests run in their own bundle.

## 1. Wrap Lines without a default shortcut (M6)

- [x] 1.1 Change the expectations first: `TextPluginTests.documentListsTheViewTools` expects Wrap Lines with a nil shortcut, and a new test in `PluginToolsTests` checks `TextPlugin.tools` gives `toggle-wrap` no shortcut (like `signLeavesControlCommandSToTheSidebar`); see both fail
- [x] 1.2 Add a config test in `ConfigTests` (or `ConfigStoreTests`) that a config setting `plugins.text.tools.toggle-wrap.shortcut` to `opt+cmd+w` still gives Wrap Lines that shortcut, with no problem reported; it should pass before and after
- [x] 1.3 Remove `shortcut: "opt+cmd+w"` from `toggle-wrap` in `Plugins/text/TextPlugin.swift`; verify 1.1 and 1.2 pass and that `grep -rn "opt+cmd+w" Sources Plugins` finds nothing

## 2. PDF Actual Size and Zoom to Fit (M7)

- [x] 2.1 Write failing tests in `Tests/PDFPluginTests.swift`: `PDFPlugin.tools` has `zoom-actual` (Cmd+0, `1.magnifyingglass`) and `zoom-fit` (Cmd+9, `arrow.up.left.and.down.right.magnifyingglass`), both menu-only; `perform("zoom-actual")` leaves `autoScales` false and `scaleFactor` 1; after `perform("zoom-in")`, `perform("zoom-fit")` sets `autoScales` back to true. Update the tool lists in `PluginToolsTests.pluginsDeclareTheirTools`, `ToolbarTests` (menu-only tools), `ConfigSchemaTests.listsEveryPluginAndItsTools` and `PDFPluginTests.viewOnlyDocumentRefusesEditsAndHasNoEditTools`
- [x] 2.2 Add the two `ToolSpec`s after Zoom Out in `Plugins/pdf/PDFPlugin.swift`, copying the image plugin's ids, titles, symbols and shortcuts, and handle them in `PDFPluginDocument.perform(_:)` as design.md says; verify the 2.1 tests pass and the image plugin's tests still do

## 3. Text and Markdown Actual Size (M7)

- [x] 3.1 Write failing tests: in `TextDocumentTests`, `TextPlugin.tools` has `zoom-actual` (Cmd+0, menu-only, no `zoom-fit`), and after two `perform("zoom-in")` calls `perform("zoom-actual")` returns the view's font to 12 pt; in `MarkdownEditorTests`, `MarkdownPlugin.tools` has `zoom-actual` and no `zoom-fit`, and after `perform("zoom-in")` `perform("zoom-actual")` returns the body font to 14 pt with headings scaled from it. Update the tool lists in `PluginToolsTests`, `ToolbarTests` and `TextPluginTests.documentListsTheViewTools`
- [x] 3.2 Add `zoom-actual` after Zoom Out in `Plugins/text/TextPlugin.swift` and `Plugins/markdown/MarkdownPlugin.swift`, and handle it in `TextDocument.perform(_:)` and `MarkdownEditor.perform(_:)` by setting the default size, without a beep when it's already there; verify the 3.1 tests pass

## 4. Signature pad colors (D2)

- [x] 4.1 Write a failing test in `Tests/PDFEditToolsTests.swift` that draws a `SignatureCanvas` into a bitmap under the dark appearance (`NSAppearance(named: .darkAqua).performAsCurrentDrawingAppearance`) and checks that a pixel on the signature line and one on the edge are clearly darker than the white canvas, and match the same pixels drawn under the light appearance
- [x] 4.2 In `Plugins/pdf/SignaturePad.swift`, draw the signature line and a 1 pt border inside the canvas bounds in black at 25% alpha instead of `separatorColor`; verify 4.1 passes

## 5. Docs, flows and checks

- [x] 5.1 Add lines under Unreleased in `CHANGELOG.md`: PDFs gain Actual Size (Cmd+0) and Zoom to Fit (Cmd+9), text and the Markdown Editor gain Actual Size (Cmd+0); Wrap Lines no longer takes Opt+Cmd+W, the standard Close All key, and a config saved from Settings keeps it until it's cleared in Settings > Plain Text; the signature pad's line and edge show in dark mode. Verify against `git diff CHANGELOG.md`
- [x] 5.2 Extend `scripts/screen/viewer-flow.sh` and its header comment: in the PDF, press Cmd+0 and check the view changes from fit, then Cmd+9 and check it matches the fitted look again (the `looks` helper the image check uses). Check the script with `bash -n`; running it needs the screen, so add "viewer flow: PDF Actual Size and Zoom to Fit" to `.local/screen-queue.md` and ask the maintainer before running `scripts/screen-test.sh`
- [x] 5.3 Run `scripts/build.sh` and `scripts/build.sh test`; verify no new warnings and every suite passes
- [x] 5.4 Run `scripts/bench-ab.sh main` once; verify no regression (nothing should touch the open path)
- [x] 5.5 Run `openspec validate --all --strict`; verify it passes
- [x] 5.6 In `docs/design-review-2026-11-01.md`, set the status of M6, M7 and D2 to "fixed (commit)", filling in the short hash of the commit that lands this change at commit time

## Workflow follow-up

- Commit only when the maintainer asks. Then bump `MARKETING_VERSION` in `project.yml` from `0.6.1-dev` to `0.7.0-dev` in its own commit, since this change adds tools users see.
- At archive, drop the M6, M7 and D2 lines from `openspec/backlog.md`.
