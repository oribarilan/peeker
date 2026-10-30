# Foundation and plain text plugin

Status: draft for review, 2026-10-29. "Preview++" is still the working name (see `decisions/naming.md`); this work doesn't rename anything.

## Intent

Preview++ replaces Preview.app with a host app where every format is a plugin running in its own process. The POC proved the model and the speed. This work turns it into a codebase the owner can use every day and build on: one plugin taken all the way to MVP quality, on a foundation that the next plugins (image markup, PDF fill and sign) reuse without rework.

Plain text goes first because it's the smallest feature that still runs the whole loop: open, view, edit, save through the plugin, crash and hang recovery, Space in Finder. Keeping the feature small puts the effort into the foundation.

## Goals

1. **Plain text plugin at MVP quality.** View and quickly edit text files: notes, logs, config, source, JSON. Fast on small files, usable on a 90 MB log.
2. **A foundation worth building on.** Typed protocol, a plugin SDK that makes a new plugin short to write, robust process handling, a document model that never loses edits, and tests that cover the parts that can break.
3. **Daily use.** The owner builds it, puts it in /Applications, makes it the default app for text files, and uses Space in Finder on text files instead of Quick Look.

## Non-goals

- Image markup and PDF text boxes or signatures. Those come next, each with its own design.
- New features for the Markdown, PDF and image plugins. They move to the new protocol and keep doing what they do today, nothing more. The one exception is PDF saving, which moves to the new save flow (see "PDF joins the save flow").
- Syntax highlighting, line numbers, multiple cursors, or anything else that makes this an editor rather than a viewer with quick edits.
- A settings window. Config stays a dotfile.
- Plugins from outside the repo, renaming the app, notarization, the DMG and the Homebrew cask.

## Anti-goals

These count as failure even if everything else works:

- **Losing or corrupting text.** An edit lost on close, quit, a plugin crash, a crash or force-quit of the app itself, or a failed save, or a save that changes the file's encoding, byte-order mark, line endings or trailing newline without the user asking.
- **Being slower than TextEdit.** Opening a text file must not be slower than TextEdit showing its window, measured by the existing benchmark.
- **A plugin freezing the app.** A plugin that crashes, hangs or sends garbage gets an error in its own tab. Other tabs and the app keep working.
- **A big file freezing the UI.** Opening a 90 MB log can't beachball the app.

## Constraints

- Native Swift on macOS 26+, Swift 6 with main-actor default isolation, XcodeGen, built by `scripts/build.sh`. No new dependencies unless the builder can show the platform doesn't cover it.
- Every format is a plugin, and every plugin runs in its own process, started on first use and stopped after `plugin.idle` seconds. Plugins never draw: they reply with a description of what to show, and the host renders it with its own native components. Plugins own reading and writing their files.
- Plugins ship inside the app and come from contributions to this repo. The host and plugins are always built together, so the protocol needs no version negotiation.
- The bench gate in CI (`scripts/bench-ab.sh`, more than 15% and 10 ms worse fails) has to stay green, and the existing benchmark has to keep running.
- Git: the owner's rules require an explicit request for each commit, push or merge. Work happens on a branch and is left uncommitted until the owner asks.

## The plain text plugin

### What it opens

The manifest claims `public.plain-text` (which covers `.txt`, `.log`, `.csv`, shell scripts, Swift and other source code, and extensionless files like `LICENSE`) plus `public.json`, `public.xml`, `public.yaml` and `public.toml`, which don't conform to plain text on macOS 27 (checked with `UTType`).

Markdown conforms to plain text, so the existing routing makes Plain Text a second choice for `.md` files in Open With, while Markdown stays the default because exact matches win. No routing change needed.

Files the system has no real type for get a config route (my call): `.conf` and `.env` come back as dynamic types, and dotfiles like `.zshrc` come back as `public.data`. Today a config route only counts when the plugin claims the type, so `open.conf = text` does nothing. The change: when the file's type is dynamic or plain `public.data`, a config route may name any enabled plugin. If the file turns out not to be text, the plugin says so in the tab. The config syntax for files with no extension is left to the builder. Without a route, Space on these files still falls through to Finder's Quick Look, as it does today for any type no plugin claims.

### Reading

The plugin detects the encoding: UTF-8 with or without a BOM, UTF-16 with a BOM, then Foundation's encoding detection for legacy files (Windows-1252, Mac Roman and so on). A file with NUL bytes that isn't UTF-16 is "not a text file", shown as an error in the tab. The plugin remembers what it found (encoding, BOM, dominant line ending, trailing newline) so a save can write it back the same way.

Decoded text reaches the host the way image pixels already do, through a mapped file under the temp directory and never through the JSON pipe, so a 90 MB log costs a memory map, not a 90 MB JSON string. The host validates that file the way `SharedBitmapReader` does today.

### Showing

A host-owned `text` component: a native text view in the system monospaced font with the native find bar (Cmd+F, Cmd+G), wrap on by default with a command to toggle it, and Cmd+plus and Cmd+minus for font size. The sidebar gets an info panel with lines, encoding, line endings and size.

Large files are the hard part. Targets:

- `small.txt` (10 KB): content on screen no slower than TextEdit's window, and a warm Space in Finder under 20 ms (PDF is 14 ms today).
- `medium.log` (11 MB) and `large.log` (90 MB): no beachball, first screen of text no slower than TextEdit's window on the same file, and scrolling stays smooth.

How to hit those (TextKit 2 viewport layout, loading the first screen before the rest, a cap past which only part of the file loads) is left to the builder, who should measure before choosing. If 90 MB can't meet the target in full, showing a clearly labeled first part of the file is acceptable.

### Editing and saving

Editing works in document windows. The Space panel is view-only, since it never takes keyboard focus away from Finder; its Open button moves the file into a window for editing.

Files above an edit limit open read-only with a visible note. Starting value: 10 MB (my call). The builder can move it based on measurements.

Behavior (my calls, matching TextEdit except where noted):

- Undo and redo come from the text view.
- The window shows the standard edited state (the dot in the close button, "Edited" in the title).
- Cmd+S saves. There's no autosave and no version history: an explicit save suits configs and logs, where a half-typed change written to disk can break something. This is where it differs from TextEdit.
- Closing a tab or window, or quitting, with unsaved edits asks Save / Don't Save / Cancel.
- The host sends the edited text to the plugin (through a mapped file again), and the plugin writes it in the original encoding, BOM, line endings and trailing-newline style. The write is atomic and keeps the file's permissions. Saving through a symlink writes the target.
- If the text can't be represented in the original encoding (an emoji typed into a Windows-1252 file), the save asks whether to save as UTF-8 or cancel.
- If the plugin crashes or times out while saving, the save reports failure and the edits stay in the window, so the user can retry or copy them out.
- If the file changes on disk: with no unsaved edits the tab reloads and keeps its scroll position (useful for logs); with unsaved edits, saving asks before overwriting the newer file.

### Recovering from an app crash

Unsaved edits survive a crash or force-quit of the app itself (owner's decision). The host keeps a recovery copy of each document with unsaved edits in `~/Library/Application Support/<bundle id>/Recovery/`, never next to or over the real file, which is still written only on Cmd+S. My calls: the copy is refreshed a couple of seconds after typing stops, and deleted on Save or Don't Save. On the next launch, each recovered document reopens in a window with its edits in place and marked edited; if the file changed on disk since, the tab says so before the user saves. This requirement tilts the document-model choice toward `NSDocument`, which has crash recovery built in, but the choice stays with the builder.

## The foundation

### Protocol

All messages get typed definitions in `Sources/Shared`, compiled into both host and plugins, replacing the `[String: Any]` dictionaries on both sides. The host should never index into untyped JSON again. The wire format stays one JSON object per line.

Changes beyond typing:

- A `save` method, separate from `command`, because every editing plugin needs it and the host must know when a save finished or failed. Its payload is plugin-specific (for text: the mapped file with the edited text).
- A `text` view type for the new component.
- Plugins can report that a document changed on disk or that its edit state changed, if the builder finds the host can't track that alone.

Typed decoding has to stay fast. Markdown replies can be megabytes, and the bench gate catches a slowdown.

### Plugin SDK

Writing a plugin should mean implementing typed `open`, `command`, `save` and `close` handlers and nothing about pipes, framing or JSON. Shared-memory helpers for bitmaps and text live in the SDK. The four existing plugins (text, Markdown, PDF, image) all use it.

### Process handling

What exists stays: start on demand, shared by all documents of a plugin, stopped when idle, restarted after a crash, a Reopen button in a failed tab.

Added:

- **Timeouts.** A request with no reply in time gets the process killed and its tabs failed with a clear message. Starting values (my call): 10 s for open and commands, 30 s for save.
- **Malformed replies** fail the request with a message instead of being dropped silently, which today leaves the tab waiting forever.
- **Logging.** The host logs through the unified log (`os.Logger`) under the app's bundle ID, and plugin stderr goes into that log line by line, tagged with the plugin ID.

### Documents and windows

The current window, tab and panel structure stays. Documents gain the edit state and save flow described above. Whether to adopt `NSDocument` or keep a small custom model is left to the builder. `NSDocument` gives prompts, edited state and recent files for free but assumes it does the reading and writing itself, which here belongs to the plugin.

### PDF joins the save flow

Owner's decision: PDF moves to the new save flow now, to prove the flow works for more than text before the PDF fill-and-sign design. Today the host writes highlights straight to disk (`PDFComponent.perform("save")`), which breaks "plugins own their files", and highlights are dropped on close without a prompt.

After this work: Highlight still runs in the host's PDF view, and it marks the document edited. Cmd+S sends the document's highlights (page, bounds, color) to the PDF plugin through `save`, and the plugin writes the file. Close and quit prompts, crash recovery and the failed-save behavior work as they do for text. The PDF plugin's own `cmd+s` command goes away, so File > Save is the only save. Loading PDFKit in the plugin only when saving is fine; open must stay on the fast CoreGraphics path.

### Daily use

- The app declares the text types in its Info.plist, so it shows up under Finder's "Open With" and can be set as default via Get Info. It stays an Alternate handler, as it is today.
- An "Open at Login" menu item (my call, using `SMAppService`), because Space in Finder only works while the app is running.
- The README gets a short "use it every day" section: build, move to /Applications, set as default, grant Accessibility and Finder access, turn on Open at Login.
- Config is read at launch, as today, plus a "Reload Config" menu item that applies to documents opened after it (my call).

### Code quality bar

- No silently swallowed errors. Every `try?` that hides a failure the user or log should see gets handled.
- Host code is organized by area (app and menus, plugins and processes, documents and windows, components, quick look, bench) instead of a flat folder.
- Bench mode stays isolated from the normal app paths.
- No new compiler warnings.

### Tests

Swift Testing, run by `scripts/build.sh test` and in CI. Cover what can break:

- Protocol: each message type encodes and decodes, and malformed input is rejected.
- Process handling, against a small test plugin executable built only for tests: crash mid-request, hang until timeout, malformed reply, idle stop and restart.
- Text plugin: encoding detection across UTF-8, UTF-8 with BOM, UTF-16 LE/BE and Windows-1252; save round-trips byte for byte when nothing changed; line endings, BOM and trailing newline survive an edit; NUL-byte files are rejected; the can't-encode case is reported.
- PDF save: highlights written by the plugin come back when the file is reopened.
- Crash recovery: a recovery copy is written, restored and deleted at the right times.
- Routing: the new rule for dynamic and `public.data` types.
- Config and shortcut parsing, as today.

The benchmark gets the text fixtures (`small.txt`, `medium.log`, `large.log`) with TextEdit as the Apple comparison, so the gate covers text from now on.

## Decided by the owner

- Plain text first, as one plugin taken to MVP quality, with Markdown as a separate plugin later.
- Text supports quick edits, not only viewing.
- Unsaved edits survive a crash of the app itself, not only a plugin crash.
- PDF saving moves to the new save flow in this work.
- Plugin isolation, contribution-only plugins, enable/disable and per-extension routing in config, all as in the POC.

## Left to the builder

- How to meet the large-file targets, after measuring.
- `NSDocument` or a custom document model.
- The config syntax for routing files with no extension.
- Exact type and file layout of the protocol and SDK, within the rules above.
- Whether the host or the plugin watches files for changes on disk.

## Done means

- `scripts/build.sh test` passes, and the build has no new warnings.
- The benchmark runs with the text fixtures, and the A/B gate against `main` is green.
- The owner can follow the README's daily-use section from a fresh clone and edit a config file from Space in Finder, then Open, edit and save, with encoding and line endings unchanged.
- Killing the text plugin while a document has unsaved edits leaves the edits in the window and the rest of the app working.
- Force-quitting the app with unsaved edits brings them back on the next launch.
- A PDF highlight saved with Cmd+S is in the file when reopened in Preview++ and in Apple's Preview.
