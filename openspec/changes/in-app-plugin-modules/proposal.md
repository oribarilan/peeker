# Proposal: in-app plugin modules

## Why

Each plugin runs as a separate process that can't draw, so every editing feature needs a new host view, a protocol message and shared-memory plumbing before the plugin can use it. The editors on the roadmap (PDF fill and sign, image editing) would each pay that cost. What the maintainer wants from plugins is code isolation and a user toggle, not process isolation, so plugins become Swift modules compiled into the app that own their views and their file reading and writing.

## What Changes

- Each plugin (text, markdown, pdf, image) becomes its own Swift module in the app. It provides its own native views for content and sidebar panels, and reads and writes its files directly. The host's per-format views move into their plugins.
- A plugin module can import only a small shared kit: the plugin contract, the safe file write, and view pieces meant for sharing. It can't reach the host's internals or another plugin.
- The contract leaves room for a plugin to offer an editor mode later; no Edit button is added in this change.
- Reading, decoding and saving run off the main thread. Closing a tab cancels its pending work.
- **BREAKING**: plugin processes, the JSON protocol, the plugin SDK main loop, shared-memory handoff, request timeouts and the `plugin.idle` config key are removed. A crash in plugin code now quits the app; unsaved edits come back on relaunch through the existing recovery copy.
- Unchanged for users: routing, enable/disable, Open With, the error view with Reopen, saving and its prompts, crash recovery, the Space panel.
- Space vs Finder's Quick Look is measured on every benchmark file and the results recorded in `openspec/gaps.md`. Misses don't block this change.
- AGENTS.md architecture rules and code layout, the README's plugin and config sections, and a new decision record superseding `decisions/plugin-architecture.html`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `plugin-host`: plugins become in-app modules that own their views; process, protocol, shared-file, timeout and plugin-log requirements are replaced by module isolation, off-main-thread work with cancellation, and errors that stay in their tab.
- `documents`: a failed save no longer involves a plugin process crash or timeout; a plugin crash during editing is covered by crash recovery.
- `pdf`: the pre-check in a separate process goes away; a PDF that crashes the parser can quit the app.
- `image`: decoding moves into the app; a malformed image that crashes the decoder can quit the app.

## Impact

- Code: `Sources/Host/Plugins/` (catalog, process), `Sources/Host/Components/` (views move to plugins), `Sources/Host/Documents/DocumentViewController.swift`, `Sources/Shared/` (protocol and shared files), `Sources/PluginSDK/`, `Plugins/*`, `Sources/Host/App/Config.swift`, `Sources/Host/Bench/`.
- Build: `project.yml` gains one module target per plugin plus the shared kit; the helper executables in `Contents/Helpers` go away.
- Tests: `PluginProcessTests`, `ProtocolTests`, `SharedFileTests` and `Tests/TestPlugin` go; plugin tests call the modules directly.
- Benchmarks: the "plugin started on demand" measurements disappear; the A/B gate against `main` must stay green.
- Docs: AGENTS.md, README.md, `decisions/`.
