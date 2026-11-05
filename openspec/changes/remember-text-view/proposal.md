# Proposal

## Why

Text zoom and Wrap Lines reset for every file and every launch (design review finding T2), so someone who reads logs unwrapped at a larger size sets both again for each file. The maintainer chose one remembered setting for all files, kept in the app's preferences.

## What Changes

- Plain text remembers its font size and whether Wrap Lines is on; the Markdown Editor remembers its text size. A change in any window is kept, across launches, and every text or Markdown view opened after it, in a window or the Peek panel, starts with it. Views already open keep their own until changed.
- Actual Size (Cmd+0) goes back to the default size (12 points for plain text, 14 for Markdown) and that is remembered too, rather than the size the file opened at.
- Plugins get a small place to keep settings like these: `PeekerKit.PluginPreferences`, handed to them when a file opens, keyed by the plugin's id in the app's preferences. Tests and benchmarks get none, so they never read or write the user's preferences.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `text`: font size and wrapping are remembered; Actual Size goes to the default size.
- `markdown`: text size is remembered; Actual Size goes to the default size.
- `plugin-host`: plugins can keep small preferences.

## Impact

- New `Sources/PeekerKit/PluginPreferences.swift`; `OpenContext` gains `preferences`; `DocumentViewController` passes the app's.
- `Plugins/text/TextPlugin.swift`, `TextDocument.swift`; `Plugins/markdown/MarkdownPlugin.swift`, `MarkdownEditor.swift` (and whatever builds it).
- Tests for the store, both plugins and the host passing it. CHANGELOG, the backlog's T2 line, the design review's T2 status. Minor version bump.
