# Design

## Context

`PluginCatalog` routes by `UTType`: it asks macOS for the file's content type (a file-system call, following symlinks), ranks enabled plugins by exact versus parent-type match, and lets `Config.routes` override the ranking, with special cases for dynamic and `public.data` types. `Config` validates each route against the plugin's `fileTypes`, and `ConfigSchema` describes the `open` section. Open With, recovery and the Space panel all call `candidates(for:)` or `defaultPlugin(for:)`. See proposal.md for why this goes.

This change modifies requirements that `json-config` adds, so `json-config` is archived before this one.

## Goals / Non-Goals

**Goals:**
- One table, extension → plugin id, built once per config read; routing is a dictionary lookup.
- Every rule about lists (format, overlap) is enforced while reading the config, so the catalog never sees a conflict.

**Non-Goals:**
- Editing lists in the Settings window (next change, settings-window).
- Detecting text by content, or any fallback for files no list has.
- Reviewing what the text formats should be; Plain Text's list mirrors what it opens today.

## Decisions

**1. The contract declares `defaultExtensions: [String]`.** It replaces `fileTypes: [UTType]` in `Plugin`: lowercase, no dot, with `noExtension` (a PeekerKit constant) for files without one. The name says it's a default the user can replace. Alternative: a `FileExtension` wrapper type. Not worth it for four built-in lists; a test checks the format instead (lowercase, no dots, no spaces) and that no two default lists share an entry.

**2. The config resolves ownership; the catalog only looks it up.** `ConfigReader` reads `plugins.<id>.extensions` per plugin (array of strings; strip one leading dot, lowercase; skip and report empty entries and ones with `.`, `/` or whitespace). `Config.owners(of: plugins)` then builds the table, extension → plugin id, from every plugin's list (configured or default), visiting plugins in catalog order. It's a function rather than a stored table because a default `Config()` has no plugin list; `Config.read` adds its problems to the reading, and the catalog keeps the table it returns. On a duplicate, the plugin whose default list has the extension keeps it, otherwise the first one visited, and each loser gets a problem at `plugins.<id>.extensions`. Disabled plugins keep their entries in the table, and the catalog ignores them, so turning one off never hands its extensions to another. Alternative: resolve in the catalog. Then the problems list couldn't report overlaps, and the settings window would need its own copy of the rule.

**3. Catalog API.** `owner(for url:) -> PluginEntry?` returns the enabled owner of the file's extension, or nil. `openWithChoices(for url:) -> [PluginEntry]` returns that owner first, then every other enabled plugin in catalog order. `candidates(for:)`, `defaultPlugin(for:)` and `contentType(of:)` go. The extension comes from `url.resolvingSymlinksInPath()`. An empty `pathExtension` maps to `noExtension`, which already covers dotfiles (`.zshrc` has none). A folder matches nothing, so Space on a folder still goes to Finder's Quick Look instead of Plain Text.

**4. Catalog order is the sidebar order.** `PluginCatalog.builtIn` is already Image, Markdown, PDF, Text. It is reordered to Image, PDF, Markdown, Plain Text to match the planned sidebar, and the overlap rule's "first in sidebar order" uses it.

**5. Recovery reopens with the recorded plugin if it's enabled.** `AppDelegate` looked up the recorded plugin among `candidates(for:)`. Since Open With can now pick any enabled plugin, recovery looks it up among all enabled plugins, and otherwise falls back to `owner(for:)`.

**6. Default lists.** Image is the common subset of ImageIO's readable extensions: png, jpg, jpeg, jpe, heic, heif, hif, avif, gif, tif, tiff, webp, bmp, ico, icns, jxl, jp2, psd, exr, plus RAW: dng, cr2, cr3, crw, nef, nrw, arw, sr2, srf, raf, orf, rw2, rwl, pef, srw, erf, raw, 3fr, iiq. `svg` stays off every list, because ImageIO can't decode it. PDF is pdf. Markdown is md, markdown, mdown. Plain Text is txt, text, log, csv, tsv, json, jsonc, xml, yaml, yml, toml, ini, conf, cfg, env, properties, sh, bash, zsh, fish, py, rb, pl, js, mjs, cjs, ts, tsx, jsx, swift, c, h, m, mm, cc, cpp, hpp, go, rs, java, kt, sql, css, scss, diff, patch and noExtension. Each list lives in its plugin's entry file.

**7. Finder's Open With follows the default lists.** `CFBundleDocumentTypes` in `project.yml` stays type-based: public.plain-text, json, xml, yaml, toml, pdf, markdown and public.image cover most typed default extensions, and com.microsoft.ini and public.css are added for `ini` and `css`, which macOS types as text but not plain text. macOS types `ts` as an MPEG-2 video, so the test skips it: Plain Text opens TypeScript, but Peeker shouldn't offer itself for videos. A test resolves each default extension with `UTType(filenameExtension:)` and checks that every non-dynamic one conforms to a type the bundle declares. Dynamic ones (conf, env, noExtension) can't be declared without exporting new types, and the spec allows that gap.

**8. Schema.** `open` goes. Each `plugins.<id>` gains `extensions`: `{"type": "array", "items": {"type": "string"}}`, with the plugin's default list in the description and as `default`.

## Risks / Trade-offs

- [A format Plain Text opened through macOS's plain-text type (say `.lua` or `.tex`) no longer opens] → Add it to `plugins.text.extensions`. The README points to `schema.json` for each default list, and the text-formats interview will revisit Plain Text's list.
- [Compound names such as `.env.local` have the extension `local`] → Such a file opens only if `local` is added. That's accepted for now.
- [A config written before this change has `open`] → It's reported as an unknown key. The maintainer is the only user, and the change is greenfield.
- [Space path speed] → The lookup drops the content-type file-system call, so it should get faster, not slower. The Space benchmark is on the back burner, so this isn't measured here.

## Migration Plan

Archive `json-config` first, then apply this change. The maintainer moves any `open` entries into `plugins.<id>.extensions` by hand. To roll back, revert the commit.
