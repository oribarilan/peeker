# Proposal

## Why

Markdown images show as their alt text in brackets, so notes, docs folders and READMEs with screenshots read as a list of `[screenshot]` placeholders in the Peek panel and in print. It's one of the gaps the specs found (`openspec/gaps.md`), and the main thing that keeps the Peek panel short of what Quick Look and other Markdown viewers show for a local document.

## What Changes

- The Peek panel and printing show **local** images as pictures: a path relative to the Markdown file's folder, an absolute path, or a `file:` URL.
- Every other source (`http:`, `https:`, `data:` and any other scheme) keeps showing `[alt]`, so opening a Markdown file never fetches anything from the web.
- Pictures scale down to fit the text width and are never drawn larger than their pixel size, as a browser shows them.
- A missing, unreadable or undecodable image, one past the size limits, one past the 50th in a document, or one in a table cell keeps showing `[alt]`, as today.
- Opening stays as fast: the text, with space laid out for each picture, draws first; pictures are decoded off the main thread at the size they're drawn and appear as they're ready. A file with no local images does no extra work.
- The Editor keeps showing the image's Markdown source. No pictures there.
- Clicking an image does what clicking its `[alt]` text does today; link behavior is outside this change.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `markdown`: "Renders Markdown with native text" no longer says images always show as alt text; new requirements say which images show as pictures, when the alt text stays, that pictures never hold up the text, and that printing includes them.

## Impact

- `Plugins/markdown/`: `MarkdownPlugin.parse` resolves and checks local image sources against the file's folder; `MarkdownRenderer` places an attachment for each usable image; `MarkdownDocument` decodes pictures in the background and fills them in; `MarkdownEditor.printText` includes decoded pictures. A new file holds the image lookup and decoding.
- No change to PeekerKit, the host or the plugin contract. `ImageIO` and `UniformTypeIdentifiers` are Apple frameworks the plugin may import.
- Tests in `Tests/MarkdownPluginTests.swift` and `Tests/PrintTests.swift`, a step in a screen flow, a CHANGELOG line, the Markdown images line in `openspec/gaps.md`, and a minor version bump.
