# Preview++ (exploration)

An open-source, plugin-based replacement for Preview.app. The app is only a host: windows, tabs, routing, config and commands. Every format, including text, Markdown and PDF, is a plugin. This repo holds the product-fit and feasibility study plus a working POC.

Start with [REPORT.md](REPORT.md). Raw research is in [research/](research), benchmark output in [bench/results/](bench/results).

## Build and run

Needs Xcode 26+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
xcodegen generate
xcodebuild -project PreviewPP.xcodeproj -scheme PreviewPP -configuration Release -derivedDataPath build/dd build
open -a build/dd/Build/Products/Release/PreviewPP.app path/to/file.md
```

Two app targets share the host code. `PreviewPP` compiles the first-party plugins in. `PreviewPPLean` compiles none and loads the same plugins as bundles from `Contents/PlugIns`.

Community plugins load from `~/Library/Application Support/PreviewPP/Plugins`, any `plugins.dir` in the config, or `$PPP_PLUGINS_DIR`. Try the samples with `PPP_PLUGINS_DIR=$PWD/ExternalPlugins`.

## Config

`~/.config/previewpp/config` (or `$PPP_CONFIG`):

```
disable = csv                      # plugin ids to turn off
open.csv = csv-proc                # default plugin per extension; "Open With" in the toolbar switches per tab
key.markdown.toggle-source = cmd+shift+e
plugins.dir = ~/my-plugins
```

## Writing a plugin

- **Native (Swift):** conform to `PreviewPPKit.Plugin` and return a `Viewer` (content view controller, optional sidebar, commands). See `Sources/Plugins/`.
- **Web:** a `name.pppweb` folder with `manifest.json` and an HTML entry. The page fetches the opened file from `/__ppp__/file` and posts `{type: "ready"}` to `webkit.messageHandlers.ppp`. See `ExternalPlugins/csv-web.pppweb`.
- **Process:** a `name.pppproc` folder with `manifest.json` and any executable that speaks newline-delimited JSON on stdio and returns a view tree the host renders natively. See `ExternalPlugins/csv-proc.pppproc`.

## Benchmarks

```sh
swift bench/make-fixtures.swift
swiftc -O bench/winwait.swift -o build/winwait
bench/run.py                       # quits Preview and TextEdit between runs; refuses to start if they're open
bench/signing.sh "<codesigning identity>"
```
