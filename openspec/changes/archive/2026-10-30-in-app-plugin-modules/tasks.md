# Tasks

## 1. Kit, catalog and the import check

- [x] 1.1 Add the `PeekerKit` static framework target in `project.yml` with the `Plugin` and `PluginDocument` protocols, `PluginError`, `CommandSpec`, the info sidebar builder, and `FileReplacement` moved from `Sources/PluginSDK`; verify `scripts/build.sh` builds with no new warnings
- [x] 1.2 Teach `PluginCatalog` to list in-app plugin types next to manifest plugins, keeping routing and enable/disable rules, and let `DocumentViewController` hold either a `PluginDocument` or the old process path until group 6; verify `RoutingTests` pass unchanged
- [x] 1.3 Add the import check to `scripts/build.sh test` that fails when a file under `Plugins/<id>/` imports another plugin's module or anything besides `PeekerKit`, Apple frameworks and its declared packages; verify it fails on a deliberate bad import and passes on the tree
- [x] 1.4 Write `decisions/in-app-plugins.md` recording the move from process plugins to in-app modules and why, and add a "Superseded by" note at the top of `decisions/plugin-architecture.html`; verify both links resolve

## 2. Image plugin in-app

- [x] 2.1 Turn `Plugins/image` into the `ImagePlugin` static framework: decode off the main thread, move `BitmapComponent` into it as its own document view, declare its file types in Swift, and drop its helper tool, manifest and shared-bitmap handoff; verify an image opens in a window and in the Space panel with zoom and the info sidebar
- [x] 2.2 Cancel an in-flight open when its tab closes or the Space panel moves to another file, and drop late results; verify with a test where a document closed mid-open never gets content
- [x] 2.3 Add image tests against the module (orientation applied, corrupt file reports "isn't a readable image", decode capped at the requested pixel size); verify `scripts/build.sh test` passes

## 3. PDF plugin in-app

- [x] 3.1 Turn `Plugins/pdf` into the `PDFPlugin` framework: run the CoreGraphics readability check off the main thread, move `PDFComponent` with thumbnails and highlighting into it, and save highlights through `FileReplacement` from the document; verify open, highlight, Cmd+S, and that the highlight shows in Apple's Preview
- [x] 3.2 Move edits to plugin-owned bytes (`encodedEdits`, `restore(encoded:)`, `recoveryText`) with the recovery store keeping `pluginID` plus bytes, encoding PDF highlights in the old `{"pdfHighlights": …}` shape; verify `RecoveryStoreTests` and a new test restoring a record written in the old format
- [x] 3.3 Implement the save rules from the documents delta: a running save blocks a second one, and the close prompt's Save waits for it; verify with a test that closing during a slow save asks as usual and leaves the file either old or fully new
- [x] 3.4 Port `PDFSaveTests` to the module API; verify they pass, including the locked-PDF and not-a-PDF messages

## 4. Markdown plugin in-app

- [x] 4.1 Turn `Plugins/markdown` into the `MarkdownPlugin` framework: parse off the main thread, move `MarkdownComponent` and the outline panel into it, and keep task toggles writing the file immediately off the main thread; verify a README renders, the outline scrolls, and ticking a task changes only that line
- [x] 4.2 Port `MarkdownTreeTests` to the module; verify they pass

## 5. Text plugin in-app

- [x] 5.1 Turn `Plugins/text` into the `TextPlugin` framework: decode off the main thread, move `TextComponent` into it, keep the 10 MB, 16 MB and 4 MB limits, and save through `FileReplacement` with the encoding rules and the Save as UTF-8 prompt; verify editing and saving a UTF-16 CRLF file keeps its format
- [x] 5.2 Encode text edits in the old `{"text": …}` shape and wire `recoveryText` for the clipboard fallback; verify a test restoring an old-format text record
- [x] 5.3 Port `TextCodecTests`, `TextPluginTests`, `TextComponentTests` and `TextSaveIntegrationTests` to drive `PluginDocument` without a process; verify they pass, including reload on change and the can't-encode case

## 6. Remove the process layer

- [x] 6.1 Delete `PluginProcess`, the temporary bridge from 1.2, `Sources/Shared` protocol and shared-file code, `Sources/PluginSDK`, `Tests/TestPlugin`, `PluginProcessTests`, `ProtocolTests`, `SharedFileTests`, the helper and test tool targets, and the manifest copy phases; verify a clean build with no warnings and that `Contents/Helpers` is gone from the app
- [x] 6.2 Remove `plugin.idle` from `Config` and its tests; verify a config containing it logs an unknown-key warning and otherwise loads
- [x] 6.3 Rewrite the AGENTS.md architecture rules and code layout, and the README's plugin and config sections, for in-app modules; verify no remaining mention of plugin processes, the JSON protocol or `plugin.idle` with a search of both files

## 7. Benchmarks

- [x] 7.1 Update `BenchRunner` to record open-to-ready and app memory without process fields, and `bench/ppbench.py` to retire `plugin_startup`, `plugin_memory` and `cold_plugin_open`, add `app_memory` (host plus plugin when the build reports one), and drop the cold-plugin column from publish; verify `bench/ppbench.py compare` on a base and head result shows no "missing in head" rows
- [ ] 7.2 Add `bench/ppbench.py space`, running `bench/spacebench.swift` on every fixture for Quick Look and Peeker and printing a per-file table; verify it runs locally and writes its results into `openspec/gaps.md`
- [ ] 7.3 Run `scripts/bench-ab.sh main` and confirm no regressions; verify the gate's report shows `warm_open` and launch metrics no worse than `main`

## 8. Integration check

- [ ] 8.1 Run `scripts/build.sh test` and `openspec validate --all --strict`, then by hand: open each format in a window and in the Space panel, edit and save a text file, highlight and save a PDF, force-quit with unsaved edits and relaunch; verify everything behaves as the updated specs say

## Workflow follow-up

- Update the plugin-host spec's Purpose line at archive, since it still says plugins run as separate processes.
- Archive the change with `/opsx:archive` after review, then verify `openspec validate --all --strict` passes on the main specs.
