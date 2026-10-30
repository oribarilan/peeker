# Peeker

An open-source, plugin-based replacement for Preview.app. The app is only a host: windows, tabs, routing, config and a quick-look panel on Space. Every format is a plugin, a Swift module built into the app that owns its views and its file reading and writing. Plugins come from contributions to this repo; users turn them on and off and choose which file types each one opens.

The study behind it is in [REPORT.md](REPORT.md) and [decisions/](decisions). Raw research is in [research/](research).

## Performance

<!-- bench:start -->
| Opening, app not running | Apple | Peeker | |
|---|---|---|---|
| PDF, 2,000 pages | Preview 661 ms | 305 ms | **2.2× faster** |
| JPEG, 12 MP | Preview 394 ms | 368 ms | about the same |
| PNG, 48 MP | Preview 1102 ms | 675 ms | **1.6× faster** |
| Markdown, 1 KB | TextEdit 286 ms | 285 ms | about the same |

Space in Finder shows a PDF in 14 ms and a 12 MP photo in 125 ms.

Apple M6, macOS 27.0.1, 2026-10-29. Apple's apps are timed until their window appears, Peeker until its content is drawn. Every file, method and caveat: [BENCHMARKS.md](BENCHMARKS.md).
<!-- bench:end -->

## Build and run

Needs Xcode 26+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
scripts/build.sh                     # Release build into build/dd; scripts/build.sh test runs the unit tests
open build/dd/Build/Products/Release/Peeker.app
```

## Use it every day

1. Build, then copy the app: `cp -R build/dd/Build/Products/Release/Peeker.app /Applications/`.
2. In Finder, select a `.txt` file, press Cmd+I, pick Peeker under Open With and click Change All. Repeat for `.pdf` and the image types you want. Peeker stays an alternate handler, so nothing changes until you do this.
3. Launch it from /Applications. macOS asks for Accessibility (to see the quick-look key) and, on first use of Space, for permission to control Finder (to read the selection). `scripts/build.sh` signs with your Apple Development certificate when you have one, so those grants survive rebuilds.
4. Choose Peeker > Open at Login. Space in Finder only works while the app is running.

Space on a supported file in Finder opens a panel. Open there moves it into a window, where text files are editable and Cmd+S saves.

## Config

`~/.config/peeker/config` (or `$PEEKER_CONFIG`), read at launch. Peeker > Reload Config applies changes to documents opened afterwards; a file that can't be read leaves the current settings in place.

```
disable = image                      # plugins to turn off
open.md = markdown                   # which plugin opens an extension; for a type macOS knows, it must support it; "Open With" switches per tab
open.conf = text                     # extensions macOS has no type for (.conf) go only to the plugin named here
open.none = text                     # same, for files with no extension (.zshrc, .env)
key.pdf.highlight = cmd+shift+h      # rebind a plugin command
quicklook.key = space                # bare key: only in Finder, not while typing; with modifiers: anywhere; "off"
```

## Plugins

A plugin is a Swift module in `Plugins/<id>/`. Its entry type conforms to `Plugin` in `Sources/PeekerKit/Plugin.swift`: it names the file types it supports and opens a file into a `PluginDocument`, which provides the content view, sidebar panels and commands, and handles edits, saving and reloading. Plugins read and decode off the main thread, and the plugin that owns a format writes it, so it also owns the encoding and line endings. A plugin can import only `PeekerKit`, Apple frameworks and its own packages; `scripts/build.sh test` checks that.

- `Plugins/text` opens plain text, JSON, XML, YAML and TOML, plus untyped files the config routes to it (`open.conf`, `open.none`). Edits keep the file's encoding and line endings. Files over 10 MB open read-only, and files over 16 MB show only their first 16 MB (4 MB when a line is over 1 MB, which text layout handles slowly). Saving asks first if the file changed on disk or was deleted since you opened it.
- `Plugins/pdf` shows pages with thumbnails and saves highlights through Cmd+S as standard annotations that Preview can read.
- `Plugins/markdown` renders Markdown with an outline; ticking a task checkbox writes the file at once.
- `Plugins/image` shows images fitted to the window, with zoom and the photo's details.

Unsaved edits are copied to `~/Library/Application Support/<bundle id>/Recovery/` two seconds after the last change. After a crash or force quit, the next launch reopens them; if the file is gone, the text goes to the clipboard.

## Benchmarks

`bench/ppbench.py` serves two purposes:

- **Published numbers.** `bench/ppbench.py run` measures the current build on this Mac (quit Preview and TextEdit first; it relaunches them between runs). `bench/ppbench.py publish` then writes the highlights above and the full results in [BENCHMARKS.md](BENCHMARKS.md). It refuses CI or partial results. In Claude Code, the repo's `publishing-benchmarks` skill runs the whole flow.
- **Regression gate.** `scripts/bench-ab.sh <base-ref>` builds the base in a git worktree, measures base and head interleaved on the same machine, and fails if any Peeker metric got worse by more than 15% and 10 ms (5 MB for memory). CI runs exactly that on every pull request (`.github/workflows/bench.yml`).

Fixtures are generated (`bench/make-fixtures.swift`), not committed. `bench/spacebench.swift` times pressing Space in Finder for Quick Look and for Peeker; it needs Accessibility for the app running it, so it stays out of CI.
