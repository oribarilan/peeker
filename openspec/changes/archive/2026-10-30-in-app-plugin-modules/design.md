# Design

## Context

See proposal.md for why. Today each plugin is a command-line tool in `Contents/Helpers`, built from `Plugins/<id>` plus `Sources/Shared` (typed protocol) and `Sources/PluginSDK` (read loop, safe write). The host talks to it through `PluginProcess` and draws replies with its own views in `Sources/Host/Components` (`Component` protocol: view, verbs, pending edits, restore, save bookkeeping). Edits are a host enum (`Edits.text`, `Edits.pdfHighlights`) that the recovery store journals as JSON. The benchmark (`BenchRunner`, `bench/ppbench.py`) records plugin-process fields: reply time, process launch time, plugin memory, and a third open with the process stopped.

Constraints: Swift 6 with main-actor default isolation, XcodeGen, no new dependencies, the A/B bench gate against `main`, and the safe-write rules in `FileReplacement`.

## Goals / Non-Goals

**Goals:**
- Each plugin compiles as its own module that can see only the shared kit.
- Opening gets faster or stays the same: no process spawn, no JSON, no shared files.
- The host knows nothing format-specific, apart from the list of plugins it ships.

**Non-Goals:**
- An Edit mode, editor UI or new plugin features.
- Settings, config format changes (roadmap items 2 and 3).
- Rethinking text formats (parked).
- Publishing new README numbers (that needs the reference Mac).

## Decisions

### 1. One static framework per plugin, plus a shared kit

`project.yml` gets a `PeekerKit` target and one target per plugin (`PeekerText`, `PeekerMarkdown`, `PeekerPDF`, `PeekerImage`), each `framework.static`, depending only on `PeekerKit` (Markdown also on swift-markdown). The app links all of them without embedding anything. The modules are named `Peeker…` because a type with its module's name breaks qualified lookups; the entry types inside keep the names `TextPlugin`, `PDFPlugin` and so on. A plugin can't `import` the host (an app target isn't importable) or a plugin it doesn't depend on.

- *Static over dynamic frameworks:* dynamic frameworks add dyld work at launch for every plugin, and launch time is gated. Static frameworks still give a real module boundary.
- *Over a local Swift package:* XcodeGen already drives the build and the plugin targets; a package would split the build configuration in two for no gain.
- *Over folders in the app target:* rejected by the maintainer; nothing would stop cross-plugin references.

Xcode can let a target import a module that merely sits in the same build folder without a declared dependency. To make "the build enforces it" hold regardless, `scripts/build.sh test` also runs a small check that fails when a file under `Plugins/<id>/` imports another plugin's module or anything but `PeekerKit`, Apple frameworks and its declared packages.

The name `PeekerKit` avoids Apple's private `PluginKit` framework, which crashed the test runner when shadowed (REPORT.md section 6).

### 2. What the kit holds

Only what more than one side needs:

- `Plugin` protocol: static `id`, `name`, `fileTypes` (UTTypes), and `open(_ url: URL, context:) async throws -> any PluginDocument`. Plugin file types move from `manifest.json` into Swift, so they're compiler-checked and nothing is parsed at launch. The manifests go away.
- `PluginDocument` protocol (main actor), replacing `Component`: `contentView`, optional `focusView`, `sidebar` (views, plus whether each sizes to fit or fills), `commands` (`CommandSpec`: id, title, symbol, default shortcut), `perform(_:)`, `reload()` to re-read the file in place after a change on disk (returning false makes the host open it again), and the edit lifecycle: `onEdit`, `unsavedEdits() -> UnsavedEdits?`, `restore(encoded:) -> Bool`, `save(_:accepting:) async throws`, `revertEdits()`. `Plugin.recoveryText(from:)` gives the clipboard fallback.
- `UnsavedEdits` wraps the plugin's own `Encodable` value. Taking one is cheap; encoding it to JSON happens on the recovery store's queue, because 10 MB of text takes about 40 ms to encode and as long again to parse back.
- `PluginError` (message, a code such as `cannotEncode` or `notWritable`, and an optional `SaveOffer`) replacing `PluginFailure`. A save offer is how a plugin proposes another way to save, such as "Save as UTF-8"; the host shows it and calls `save` again with the offer accepted, without knowing about encodings.
- `FileReplacement`, moved from `PluginSDK` unchanged.
- The info sidebar panel builder. All four plugins use it, which meets the third-copy rule for extraction.

Nothing for an Edit mode is added. `PluginDocument` is an object the plugin owns, so an editor can be added to it later without changing how the host holds documents.

### 3. Edits become plugin-owned bytes

The host stops knowing edit shapes. A document hands the host an `UnsavedEdits` snapshot; the recovery record stores `pluginID` plus the encoded JSON, kept as JSON inside the record. Restoring hands the plugin those bytes back. Saving is a call on the document, which writes through `FileReplacement` itself.

The text and PDF plugins encode their edits in the same JSON shape the old enum used (`{"text": …}`, `{"pdfHighlights": …}`), so recovery records written by the previous version still restore after an upgrade.

### 4. Threading and cancellation

`Plugin.open` is `async` and `nonisolated`: file reading, decoding (text codec, image decode, Markdown parse, the CoreGraphics PDF check) run on the cooperative pool. Building views happens back on the main actor. `DocumentViewController` holds the open in a `Task` and cancels it in `close()`, and when the Space panel moves on. Plugins check `Task.isCancelled` between stages, and the host drops any result that arrives after cancellation. A decode already inside ImageIO isn't interruptible; its result is simply discarded.

The old code applied replies in a callback because resuming an awaiting task cost a main-actor turn, about 10 ms of first paint at launch. The new path must not reintroduce that: the background stage ends by scheduling the view install directly on the main queue (`MainActor.assumeIsolated` inside a main-queue callback), not by resuming an awaiting caller. Measured before and after with the bench.

Saving runs the same way. `save()` encodes off the main thread and writes atomically through `FileReplacement`. If the window closes during a save, the close prompt is shown as usual and its Save waits for the running save rather than starting a second one. An atomic rename means a cancelled or interrupted save leaves the old file.

Markdown task toggles stay immediate and run off the main thread too.

### 5. Host changes

- `PluginCatalog` keeps routing and enable/disable, but its entries come from a static list of plugin types instead of manifests, and it hands out plugins, not processes.
- `DocumentViewController` loses the protocol, process attach, timeouts, `pluginNeedsReopen` and shared-file cleanup. It keeps the error view with Reopen (now for thrown `PluginError`s), edited state, journaling, reload on change, and the save flow.
- `Sources/Host/Components/*Component.swift` move into their plugins. `Sidebar.swift` keeps only the stacking of panels the plugin provides.
- `Config` drops `plugin.idle`. The key then falls into the existing unknown-key warning, and `Config.unknownKeys` records it.
- The file watcher starts a turn after the content appears, so the host checks the file once when it starts; the old process round trip had hidden that gap.
- `project.yml`: the helper tool targets, `TestPlugin` and the manifest copy phases go. `CFBundleDocumentTypes` stays as is.

### 6. Benchmarks

`BenchRunner` keeps three opens per launch (cold app, warm, warm again) and records `openToReadyMs` and the app's memory. The third open no longer stops a process, so `cold_plugin_open` becomes a plain second warm open.

`bench/ppbench.py` (head's copy runs against both builds in `bench-ab.sh`) changes like this:
- `plugin_startup`, `plugin_memory` and `cold_plugin_open` are retired, so neither build reports them and the "missing in head" rule doesn't fire. Each launch now opens the file twice (cold app, then warm).
- A new `app_memory` metric is the app's footprint, or host plus plugin memory for a build from before this change. Each memory number records which of the two it is, and the gate shows but doesn't count a pair measured differently. The old host showed decoded images from a shared file that a footprint doesn't count, so for photos the old sum left out about one screen-sized bitmap, which the in-app plugin now holds in ordinary memory (+13 to +35 MB, capped by the screen-size decode). Once `main` has in-app plugins, both sides measure the same way and memory is gated again.
- The publish layout drops the "plugin started on demand" column.

Space vs Quick Look gets its own command, `bench/ppbench.py space`, running `spacebench` per fixture for both and printing a table. It isn't gated and isn't run in CI, since it needs Accessibility. Its first results go into `openspec/gaps.md`.

### 7. Tests

`HostTests` links the plugin frameworks and uses `@testable import`. The suites move like this:
- Text codec, Markdown tree and PDF save tests keep their cases against the module APIs.
- The text save integration tests drop the process and drive `PluginDocument` through `DocumentViewController`.
- `PluginProcessTests`, `ProtocolTests`, `SharedFileTests` and `TestPlugin` are deleted with the code they cover.
- New tests cover cancellation (a closed document never gets content), recovery records in the old format still restoring, and the import check script.

## Risks / Trade-offs

- [A malformed PDF or image that crashes PDFKit or ImageIO now quits the app] → Accepted by the maintainer. Crash recovery keeps unsaved edits, and the error is visible rather than silent.
- [A hung decode can't be killed] → It runs off the main thread, so the app stays usable, and closing the tab drops the result. The stuck thread is leaked until the decode returns; acceptable for a rare case.
- [Main-actor hops add a run-loop turn to first paint] → Install views from a main-queue callback, as the current code does (decision 4), and watch `warm_open` in the A/B gate.
- [Xcode lets a module import an undeclared neighbor] → The import check in `scripts/build.sh test` (decision 1).
- [Bench history across the change isn't comparable for retired metrics] → Retired metrics are dropped from the gate on purpose. `warm_open` and launch metrics carry on unchanged, and those are the ones the README publishes.
- [Recovery records from the old version] → Same JSON shape for edits (decision 3), with a test.

## Migration Plan

Work lands on one branch in reviewable commits:
1. Add PeekerKit and the import check.
2. Move image, the smallest plugin, to prove the contract end to end.
3. Move PDF, which brings saving and recovery.
4. Move Markdown.
5. Move text.
6. Delete the process layer, protocol, SDK and TestPlugin.
7. Update the benchmark tooling and run the A/B gate.
8. Update the docs.

Each step keeps the app building and tests passing, so a bad step can be reverted on its own. Rollback for users means not merging the branch; there's no persisted state to migrate, apart from recovery records, which keep their format.

## Open Questions

- Whether Xcode 26's explicitly built modules already reject undeclared imports. If so, the import check is a second line of defense rather than the only one. Either way, the check stays.
