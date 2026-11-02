# Tasks

## 1. Toolbar (W3, menu-only zoom, timing)

- [x] 1.1 Write failing tests: `CommandSpec` has `showsInToolbar` (default true); the image plugin's four zoom commands and the PDF and text plugins' Zoom In and Zoom Out are menu-only; a menu-only command isn't in `toolbarDefaultItemIdentifiers` but is still in View. Then add the flag and mark the plugins' zoom commands; verify the tests pass and `scripts/build.sh test` passes the plugin import check
- [x] 1.2 Write failing tests for the groups: a document with view commands and edit tools in Edit mode has a `.space` between the two runs, and none when either is empty. Then change `toolbarDefaultItemIdentifiers`; verify the tests pass
- [x] 1.3 Write failing tests for the timing: while a file opens, the window's toolbar has no command items until the document has shown its content, and has them right after; a later commands change (Edit mode) rebuilds at once; the benchmark's `onReady` still fires. Then add `onContentShown` and defer the first rebuild; verify the tests and the existing toolbar, active-command and edit-mode tests pass

## 2. Window size (W4)

- [x] 2.1 Write a failing test that a document window's `contentMinSize` is 480 × 320; then set it; verify the test passes

## 3. Alerts (W6, W7)

- [x] 3.1 Write failing tests for `AppDelegate.settingsPane(forUnopenable:)`: a turned-off plugin listing the extension gives its pane, otherwise the Plain Text pane. Then give the no-plugin alert its new text and Open Settings button, opening that pane; verify the tests pass
- [x] 3.2 Write failing tests that the recovery notices and save failures have a short title naming the file and the reason as the detail (through a replaceable alert presenter, like `askToSave`); then change `report`, `showMessage` and `save`; verify the tests pass

## 4. Screen tests

- [x] 4.1 In `pdf-pages-flow.sh`, press Rotate Right and Delete Page in the toolbar again and check there's no Zoom In button; in `record-flows.sh`, add the no-plugin alert step (Open Settings shows Plain Text); in `viewer-flow.sh`, check a window stops at its minimum size; update the run-peeker skill; verify `bash -n` on each script

## 5. Wrap-up

- [x] 5.1 Add Unreleased lines to `CHANGELOG.md` and mark W3, W4, W6 and W7 in progress and W5 won't fix (with the reason) in `docs/design-review-2026-11-01.md`; verify `openspec validate --all --strict`
- [x] 5.2 Run `scripts/build.sh` and `scripts/build.sh test`; verify all tests pass with no new warnings
- [x] 5.3 With the maintainer's go, run `scripts/screen-test.sh`; verify every flow passes and look at the toolbar captures
- [x] 5.4 With the maintainer's go, run `scripts/bench-ab.sh <base>` once against the commit before this change; verify window opens for PDF, image and text get faster and nothing regresses

## Workflow follow-up

- Once committed (on the maintainer's request), set W3, W4, W6 and W7 to fixed with the commit hash in the design review.
- Archive the change with `/opsx:archive`.
