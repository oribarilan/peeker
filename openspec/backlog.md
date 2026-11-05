# Backlog

Ideas not yet started, one line each. Details live in [docs/design-review-2026-11-01.md](../docs/design-review-2026-11-01.md) (by ID), [gaps.md](gaps.md) and the roadmap in [config.yaml](config.yaml). An idea becomes an OpenSpec change when it's picked up; drop its line once that change is archived.

## Design review leftovers

- M8: maybe a setting to hide the menu bar icon (Open… is in its menu now).
- I2: Cmd+R in images (rotate like Preview vs Rotate & Resize).
- T3: Markdown task boxes readable by VoiceOver.
- A1: keyboard-only use of PDF marks and crop.

## Product and release

- First release, v0.1.0: Apple Developer setup in [docs/releasing.md](../docs/releasing.md), then the maintainer tags.
- Optional author name on PDF marks (`openspec/changes/annotation-author-setting`, parked until it's discussed).
- Text formats: how plain text, logs, code, JSON/YAML/XML, CSV and Markdown split into plugins (open question in config.yaml).

## Format gaps and risks

- Everything under "Requirements the code misses", "Missing next to Preview", "Future work" and "Risks" in [gaps.md](gaps.md), including the Peek panel being slower than Quick Look.
- Refresh the published benchmark numbers on the reference Mac.
- A PDF form field changed through VoiceOver isn't recorded until the next click, so Save stays greyed and closing doesn't ask.
