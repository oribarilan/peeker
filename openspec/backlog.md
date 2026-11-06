# Backlog

Ideas not yet started, one line each. Details live in [docs/design-review-2026-11-01.md](../docs/design-review-2026-11-01.md) (by ID), [gaps.md](gaps.md) and the roadmap in [config.yaml](config.yaml). An idea becomes an OpenSpec change when it's picked up; drop its line once that change is archived.

## Design review leftovers

- M8: maybe a setting to hide the menu bar icon (Open… is in its menu now).
- I2: Cmd+R in images (rotate like Preview vs Rotate & Resize).
- T3: Markdown task boxes readable by VoiceOver.
- A1: keyboard-only use of PDF marks and crop.

## Product and release

- First release, v0.1.0: Apple Developer setup in [docs/releasing.md](../docs/releasing.md), then the maintainer tags.
- Recolor a PDF highlight already on the page (select it, pick a color); highlight colors only set the next one.
- Optional author name on PDF marks (`openspec/changes/annotation-author-setting`, parked until it's discussed).
- Data editor for JSON (+JSONC), YAML, XML (+plist) and TOML: tree first with a sidebar outline, tree editing for JSON first (decided 2026-11-06; the next change after the table editor).
- Editable password-protected PDFs (decided 2026-11-06; after the data editor).
- Find and Print in CSV/TSV tables.
- Open With from the Peek panel: next to Open in Peeker, a drop-down of the other installed apps that open the file. The panel's main button opens the default app for that extension or type, which you set in the config (Peeker unless you change it). Picking a different app from the drop-down asks "Make it the default for .ext files?" with Yes, No, and "Don't ask again" for this type or for all types. Open question: whether this default stays inside Peeker's panel only, or also sets the macOS default app.

## Format gaps and risks

- Everything under "Requirements the code misses", "Missing next to Preview", "Future work" and "Risks" in [gaps.md](gaps.md), including the Peek panel being slower than Quick Look.
- Refresh the published benchmark numbers on the reference Mac.
- A PDF form field changed through VoiceOver isn't recorded until the next click, so Save stays greyed and closing doesn't ask.
