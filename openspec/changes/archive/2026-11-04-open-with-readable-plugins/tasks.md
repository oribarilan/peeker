# Tasks

## 1. What each plugin reads

- [x] 1.1 Add `readableTypes: [UTType]` to `Plugin` in `Sources/PeekerKit/Plugin.swift`, defaulting to none, and copy it into `PluginEntry`; verify `scripts/build.sh` builds without warnings.
- [x] 1.2 Write failing tests for each built-in plugin's types: Plain Text reads `.md`, `.json` and `.swift` but not `.png` or `.pdf`; Markdown reads `.md` and `.markdown` but not `.txt` or `.json`; Image reads `.png` and `.cr2` but not `.svg` or `.pdf`; PDF reads only `.pdf`.
- [x] 1.3 Declare the types in `TextPlugin`, `MarkdownPlugin`, `PDFPlugin` and `ImagePlugin` (Image from `CGImageSourceCopyTypeIdentifiers()`, built once); verify the 1.2 tests pass and the plugin import check in `scripts/build.sh test` still passes.

## 2. The choices

- [x] 2.1 Rewrite `openWithListsTheOwnerFirstThenEveryOtherEnabledPlugin` in `Tests/RoutingTests.swift` as failing tests for `openWithChoices(for:showing:)`: `.md` gives Markdown then Plain Text; `.png` gives only Image; `.mp4` gives nothing; Markdown off gives only Plain Text for `.md`; `json` in Markdown's list gives Markdown then Plain Text; a real extensionless file holding text gives only Plain Text; a current plugin that doesn't read the type is still listed, unless it's disabled.
- [x] 2.2 Implement it in `PluginCatalog`: the type from the symlink-resolved file's `contentTypeKey`, falling back to `UTType(filenameExtension:)`; owner first, then enabled plugins in catalog order that read the type or are the current one. Verify the 2.1 tests pass.

## 3. The window

- [x] 3.1 Write failing tests: a photo window's toolbar has no Open With item and File > Open With validates to false; a Markdown window with Markdown and Plain Text in its catalog keeps both, with the current one checked; after following a link to another file, the list is that file's.
- [x] 3.2 Store the choices in `DocumentWindowController` when a document shows and when it takes a new config; have the popup, its action, `fillOpenWith`, `reopenWithMenu` and `validateMenuItem` read the stored list; leave `openWith` out of `toolbarDefaultItemIdentifiers` with fewer than two choices; grey out the File > Open With item then. Verify the 3.1 tests pass.
- [x] 3.3 Update the tests that assumed every window has Open With (`ToolbarLayoutTests`, `NavigationControlsTests`, `FileMenuTests`, `LinkNavigationTests`): give windows that need the control a second plugin that reads the file, and assert its absence where there's one choice. Verify `scripts/build.sh test` passes with no new warnings.

## 4. Screen flow and docs

- [x] 4.1 In `scripts/screen/record-flows.sh`, replace the "Image from the toolbar" step with a check that a Markdown window's Open With lists only Markdown and Plain Text, and add a step that a photo window has no Open With control; verify with `bash -n` now, and run the flow once the maintainer gives the go.
- [x] 4.2 Add a CHANGELOG line under Unreleased, drop the Open With picker line from `openspec/backlog.md`, and verify `openspec validate --all` passes.
- [x] 4.3 Run `scripts/bench-ab.sh main` once, after the maintainer's go, and verify no regression is flagged. Two runs against `aa7855d` on 2026-11-04 each flagged one different measurement (Peek panel small.md open, then window small.png memory) and neither repeated; accepted as noise.

## Workflow follow-up

- Commit the change, then bump `MARKETING_VERSION` in `project.yml` to 0.8.0-dev in its own commit, both only when the maintainer asks.
- Archive the change with `/opsx:archive`.
