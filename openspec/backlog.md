# Backlog

Ideas not yet started, one line each. Details live in [docs/design-review-2026-11-01.md](../docs/design-review-2026-11-01.md) (by ID), [gaps.md](gaps.md) and the roadmap in [config.yaml](config.yaml). An idea becomes an OpenSpec change when it's picked up; drop its line once that change is archived.

## Design review leftovers

- M6: Opt+Cmd+W (Wrap Lines vs Close All); Cmd+E goes away with the editor-always-editable change.
- M7: zoom parity: Actual Size and Zoom to Fit in PDF and text, zoom in Markdown.
- M8: menu bar icon: add Open…, maybe a setting to hide it.
- I2: Cmd+R in images (rotate like Preview vs Rotate & Resize).
- I4: animated images respect Reduce Motion; Play/Pause command.
- D2: signature pad line invisible in dark mode.
- P1: Peek panel remembers its size and position.
- T2: text zoom and wrap remembered per file or globally.
- T3: Markdown task boxes readable by VoiceOver.
- A1: keyboard-only use of PDF marks and crop.

## Product and release

- Themes and syntax highlighting for Markdown and text, in viewing and editing.
- Open With picker: list only plugins that can read the file, and hide the picker when only one can. Today it lists every enabled plugin, as the routing-and-config spec says, so this changes the spec.
- First release, v0.1.0: Apple Developer setup in [docs/releasing.md](../docs/releasing.md), then the maintainer tags.
- Optional author name on PDF marks (`openspec/changes/annotation-author-setting`, parked until it's discussed).
- Decide whether to drop recovery records written before plugins moved into the app (`readsRecordsWrittenBeforePluginsMovedIntoTheApp`).
- Text formats: how plain text, logs, code, JSON/YAML/XML, CSV and Markdown split into plugins (open question in config.yaml).

## Format gaps and risks

- Everything under "Requirements the code misses", "Missing next to Preview", "Future work" and "Risks" in [gaps.md](gaps.md), including the Peek panel being slower than Quick Look.
- Refresh the published benchmark numbers on the reference Mac.
