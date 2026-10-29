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

On first launch macOS asks for Accessibility (to see the quick-look key) and, on first use, for permission to control Finder (to read the selection). `scripts/build.sh` signs with your Apple Development certificate when you have one, so those grants survive rebuilds.

## Config

`~/.config/previewpp/config` (or `$PPP_CONFIG`):

```
disable = image                      # plugins to turn off
open.md = markdown                   # which plugin opens an extension (must support it); "Open With" switches per tab
key.pdf.highlight = cmd+shift+h      # rebind a plugin command
quicklook.key = space                # bare key: only in Finder, not while typing; with modifiers: anywhere; "off"
plugin.idle = 60                     # seconds an unused plugin process stays alive
```

## Plugins

A plugin is an executable in `Plugins/<id>/` plus a `manifest.json` naming the file types it supports. The host starts it on the first matching file, talks newline-delimited JSON over stdin/stdout, and stops it after `plugin.idle` seconds unused. Plugins never draw: they answer with a description of what to show (a Markdown block tree, a PDF, decoded pixels, sidebar panels, commands), and the host renders it with native views. The protocol is documented at the top of `Sources/Shared/Protocol.swift`; `Plugins/markdown` is the fullest example.

## Benchmarks

`bench/ppbench.py` serves two purposes:

- **Published numbers.** `bench/ppbench.py run` measures the current build on this Mac (quit Preview and TextEdit first; it relaunches them between runs). `bench/ppbench.py publish` then writes the highlights above and the full results in [BENCHMARKS.md](BENCHMARKS.md). It refuses CI or partial results. In Claude Code, the repo's `publishing-benchmarks` skill runs the whole flow.
- **Regression gate.** `scripts/bench-ab.sh <base-ref>` builds the base in a git worktree, measures base and head interleaved on the same machine, and fails if any Preview++ metric got worse by more than 15% and 10 ms (5 MB for memory). CI runs exactly that on every pull request (`.github/workflows/bench.yml`).

Fixtures are generated (`bench/make-fixtures.swift`), not committed. `bench/spacebench.swift` times pressing Space in Finder for Quick Look and for Preview++; it needs Accessibility for the app running it, so it stays out of CI.
