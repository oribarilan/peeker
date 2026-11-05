# Design

## Context

`TextDocument` keeps `fontSize` (default 12, 6 to 72) and `wraps` (default on); `MarkdownEditor` keeps `baseSize` (default 14). Both start from defaults every time. Plugins have no place to keep settings, and unit tests run inside the app, so a plugin writing `UserDefaults.standard` in a test would change the maintainer's real preferences. The host already handles that for its own state (`TipStore`, `SidebarMemory`): it takes optional `UserDefaults`, nil in tests and benchmarks.

## Decisions

**`PluginPreferences` in PeekerKit, passed in `OpenContext`.** A small `Sendable` struct over `UserDefaults` that prefixes every key with `plugins.<id>.` and offers `double`, `bool` and `set`. `OpenContext.preferences` is optional and defaults to nil; only `DocumentViewController` passes one, built on `.standard`. With nil, a plugin starts from its defaults and keeps changes only in the open view. Considered a global the test bundle swaps: tests in one bundle run in parallel, so a shared global could leak between them; passing it in can't.

**Values from preferences are validated.** A stored size outside the allowed range, or of the wrong type, is ignored and the default used, since anything can write the preferences file.

**One setting per plugin, read at open.** A change is written at once; views already open don't follow it, as in TextEdit and Preview. Plain text keeps `fontSize` and `wraps`; Markdown keeps `baseSize`. Markdown always wraps, so it has no wrap setting.

**Actual Size means the default size.** With a remembered size, "the size it opened at" would make Cmd+0 do nothing after a reopen; the default (12 or 14 points) is what Actual Size means elsewhere.

## Risks / Trade-offs

- [The Peek panel shows text at the remembered size] → intended: one setting everywhere; the panel can't change it.
