# Preview++ (exploration)

An open-source, plugin-based replacement for Preview.app. The app is only a host: windows, tabs, routing, config and a quick-look panel on Space. Every format is a plugin running in its own process, so a plugin that crashes or hangs can't take the app down. Plugins come from contributions to this repo; users turn them on and off and choose which file types each one opens.

The study behind it is in [REPORT.md](REPORT.md) and [decisions/](decisions). Raw research is in [research/](research).

## Performance

<!-- bench:start -->
| Opening, app not running | Apple | Preview++ | |
|---|---|---|---|
| PDF, 2,000 pages | Preview 661 ms | 305 ms | **2.2× faster** |
| JPEG, 12 MP | Preview 394 ms | 368 ms | about the same |
| PNG, 48 MP | Preview 1102 ms | 675 ms | **1.6× faster** |
| Markdown, 1 KB | TextEdit 286 ms | 285 ms | about the same |

Space in Finder shows a PDF in 14 ms and a 12 MP photo in 125 ms, with every format running in its own plugin process.

Apple M6, macOS 27.0.1, 2026-10-29. Apple's apps are timed until their window appears, Preview++ until its content is drawn. Every file, method and caveat: [BENCHMARKS.md](BENCHMARKS.md).
<!-- bench:end -->

## Build and run

Needs Xcode 26+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
scripts/build.sh                     # Release build into build/dd; scripts/build.sh test runs the unit tests
open build/dd/Build/Products/Release/PreviewPP.app
```

## Use it every day

1. Build, then copy the app: `cp -R build/dd/Build/Products/Release/PreviewPP.app /Applications/`.
2. In Finder, select a `.txt` file, press Cmd+I, pick Preview++ under Open With and click Change All. Repeat for `.pdf` and the image types you want. Preview++ stays an alternate handler, so nothing changes until you do this.
3. Launch it from /Applications. macOS asks for Accessibility (to see the quick-look key) and, on first use of Space, for permission to control Finder (to read the selection). `scripts/build.sh` signs with your Apple Development certificate when you have one, so those grants survive rebuilds.
4. Choose Preview++ > Open at Login. Space in Finder only works while the app is running.

Space on a supported file in Finder opens a panel. Open there moves it into a window, where text files are editable and Cmd+S saves.

## Config

`~/.config/previewpp/config` (or `$PPP_CONFIG`), read at launch. Preview++ > Reload Config applies changes to documents opened afterwards; a file that can't be read leaves the current settings in place.

```
disable = image                      # plugins to turn off
open.md = markdown                   # which plugin opens an extension; for a type macOS knows, it must support it; "Open With" switches per tab
open.conf = text                     # extensions macOS has no type for (.conf) go only to the plugin named here
open.none = text                     # same, for files with no extension (.zshrc, .env)
key.pdf.highlight = cmd+shift+h      # rebind a plugin command
quicklook.key = space                # bare key: only in Finder, not while typing; with modifiers: anywhere; "off"
plugin.idle = 60                     # seconds an unused plugin process stays alive
```

## Plugins

A plugin is an executable in `Plugins/<id>/` plus a `manifest.json` naming the file types it supports. The host starts it on the first matching file, talks newline-delimited JSON over stdin/stdout, and stops it after `plugin.idle` seconds unused. Plugins never draw: they answer with a description of what to show (a Markdown block tree, a PDF, decoded pixels, text, sidebar panels, commands), and the host renders it with native views.

Messages are typed. The host sends `open`, `command` and `save`; the plugin replies with the matching result or an error. `save` carries the edited content (text, or PDF highlights) and the plugin writes the file itself, so a plugin that owns a format also owns its encoding and line endings. The protocol is documented at the top of `Sources/Shared/Protocol.swift`.

- `Plugins/text` opens plain text, JSON, XML, YAML and TOML, plus untyped files the config routes to it (`open.conf`, `open.none`). Edits keep the file's encoding and line endings. Files over 10 MB open read-only, and files over 16 MB show only their first 16 MB (4 MB when a line is over 1 MB, which text layout handles slowly). Saving asks first if the file changed on disk or was deleted since you opened it.
- `Plugins/pdf` saves highlights through Cmd+S.
- `Plugins/markdown` is the fullest example of a viewer plugin.

If a plugin crashes or stops answering, the host kills it and keeps the window and any unsaved edits. Unsaved edits are also copied to `~/Library/Application Support/<bundle id>/Recovery/` two seconds after the last change. After a force quit or crash, the next launch reopens them; if the file is gone, the text goes to the clipboard.

## Benchmarks

`bench/ppbench.py` serves two purposes:

- **Published numbers.** `bench/ppbench.py run` measures the current build on this Mac (quit Preview and TextEdit first; it relaunches them between runs). `bench/ppbench.py publish` then writes the highlights above and the full results in [BENCHMARKS.md](BENCHMARKS.md). It refuses CI or partial results. In Claude Code, the repo's `publishing-benchmarks` skill runs the whole flow.
- **Regression gate.** `scripts/bench-ab.sh <base-ref>` builds the base in a git worktree, measures base and head interleaved on the same machine, and fails if any Preview++ metric got worse by more than 15% and 10 ms (5 MB for memory). CI runs exactly that on every pull request (`.github/workflows/bench.yml`).

Fixtures are generated (`bench/make-fixtures.swift`), not committed. `bench/spacebench.swift` times pressing Space in Finder for Quick Look and for Preview++; it needs Accessibility for the app running it, so it stays out of CI.
