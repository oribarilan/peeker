# Proposal

## Why

Relative links in Markdown (`other.md`, `./notes/a.txt`, `#install`) are colored like links but do nothing: `LinkOpener` drops any link without a scheme, and the markdown spec says it should. READMEs and notes folders lean on these links, so a Preview replacement that reads Markdown has to follow them, and once it does, the reader needs a way back.

## What Changes

- A link to a heading in the same file (`#install`) scrolls to that heading. Headings are matched by GitHub's slug rule (lowercase, spaces to hyphens, punctuation dropped, `-1`, `-2` for repeats). A link that names no heading beeps.
- A link to another file is resolved against the folder of the file it's in. A Markdown file opens in the same tab, like a browser, and `other.md#setup` scrolls to that heading. Any other file opens in its own tab when a plugin reads it, and otherwise in its default app after the same question `file:` links ask. A link to a missing file beeps.
- Editor windows keep a history per tab of these jumps, in-document and between files, with Back and Forward going any number of steps and returning to the same scroll position. Back and Forward are toolbar buttons, items in a new Go menu, and Cmd-[ and Cmd-]. A slim trail under the toolbar (`README.md › Install › other.md`) shows while the tab has more than one place in its history; clicking a crumb goes there.
- Leaving a file with unsaved edits through a link, Back, Forward or the trail asks Save, Don't Save or Cancel, with the sheet closing a tab uses. Jumps inside the file never ask.
- In the Peek panel a heading link scrolls, and a link to a file closes the panel and opens the file in an Editor window. The panel keeps no history.
- In the Editor links still open on Cmd-click; a plain click still places the cursor. Web, `mailto:` and other-scheme links behave as they do today.
- History isn't kept after a crash or after the tab closes.
- The host learns this as a format-agnostic contract: a document can hand the host a link to a local file, report where it is scrolled, and go to a named place. The Markdown plugin is the first to adopt it.

Not in this change: images (the parallel `markdown-local-images` change), explicit HTML anchors (`<a id="x">`), and links followed from Plain Text or PDF.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `markdown`: relative links are followed; heading links and their slug rule; what a link to another file does in the Editor and in the Peek panel.
- `documents`: a tab's history with Back, Forward and the trail; leaving a file through a link asks about unsaved edits; a file already open elsewhere comes forward instead.
- `plugin-host`: the contract for documents that follow links, and the Go menu, which makes the menu bar eight menus.

## Impact

- `Sources/PeekerKit/Plugin.swift`: a small `LinkFollowing` protocol beside `PluginDocument`.
- `Sources/Host/Documents/`: a per-tab `NavigationHistory`, link routing and Back/Forward in `DocumentWindowController` (split into a second file to stay under 500 lines), the trail as a titlebar accessory, `DocumentViewController` passing links up. The window controller's `url` becomes the tab's current file.
- `Sources/Host/App/`: `MainMenu` gains Go; `AppDelegate` opens files from links (own tab, or from the Peek panel with a heading).
- `Plugins/markdown/`: slug matching, link resolution in `LinkOpener`, `MarkdownEditor` and `MarkdownDocument` adopt the contract.
- Tests, a step in the Markdown screen flow, CHANGELOG, `openspec/gaps.md`, and a minor version bump.
