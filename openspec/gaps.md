# Known gaps

Found while writing the baseline specs on 2026-10-30. Each is either a spec requirement the code doesn't meet yet, or something Preview does that Peeker doesn't. A change that fixes one removes it from this list.

## Unmeasured requirements

- **Space vs Quick Look** (quick-look-panel). `bench/spacebench.swift` times both the same way, but it has never been run per fixture, and neither CI nor the published numbers include it. It times the panel appearing, not content drawn.
- **Text vs TextEdit** (text). The published reference run predates the text plugin, so BENCHMARKS.md has no text rows. CI's A/B gate does cover text against `main`.

## Requirements the code misses

- **Large Markdown** (markdown) opens in 472 ms against TextEdit's 286 ms, 1.7× slower.

## Missing next to Preview

- **PDF:** no search (Cmd+F only reaches text views), no way to unlock a password-protected PDF, saved highlights can't be removed, one highlight color.
- **Images:** zooming in on a large photo shows upscaled screen pixels because decoding stops at screen size; no actual-size zoom; no zooming out below fit; only the first frame (no animated GIFs, first page of a TIFF).
- **Markdown:** images show as their alt text; relative links such as `other.md` most likely do nothing (untested); no editing except Open With > Plain Text.
- **Printing**, in every format.

## Small fixes

- The comment at the top of `Sources/Shared/Protocol.swift` says manifests live in `<id>.ppp` folders; they're read from `Resources/Plugins/<id>/`. The in-app migration rewrites that file anyway.
