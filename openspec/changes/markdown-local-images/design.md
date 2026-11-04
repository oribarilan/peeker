# Design

## Context

See proposal.md for why. Today `MarkdownTree` turns an image into a span with the alt text, style `.image` and the image's source as its link; `MarkdownRenderer` draws it as `[alt]` in the marker color. `MarkdownPlugin.parse` runs off the main thread and has the file's URL; `MarkdownDocument` (the Peek panel's view) renders on the main thread, the first 150 blocks at once and the rest a frame later, and keeps a map from heading lines to character offsets for the outline. Print runs from the Editor: `MarkdownEditor.printText` parses the current text and renders it with the System theme, synchronously, because the plugin contract's `printJob` returns an `NSPrintOperation` directly. The Peek panel's text view is TextKit 2; `TextPrinting` asks for the layout manager, which puts its view on TextKit 1. Plugins may import Apple frameworks, so `ImageIO` and `UniformTypeIdentifiers` are available; `Plugins/image/ImagePlugin.swift` already decodes with `CGImageSourceCreateThumbnailAtIndex`.

## Goals / Non-Goals

**Goals:**
- A file without local images opens exactly as fast as today.
- With local images, the first paint costs at most a quick header read per image, and the text never moves when a picture arrives.
- Memory per picture bounded by what it's drawn at.

**Non-Goals:**
- Pictures in the Editor's source view.
- Web images, `data:` URIs, pictures inside table cells, animated pictures (the first frame shows), and HTML `<img>` tags (HTML stays shown as code).
- What clicking an image does. It keeps the link its `[alt]` text carries today; `markdown-link-navigation` owns link behavior.

## Decisions

### Find and check images during the parse

`MarkdownPlugin.parse` already runs off the main thread with the file's URL. After building the blocks it walks them in document order (skipping table cells), and for each image span looks up its source once (the same source used twice is checked once). A usable image becomes a `LocalImage`: the resolved file URL, its pixel size (turned for EXIF orientations 5 to 8), and the file's modification date. `Parsed` gains `images: [String: LocalImage]`, keyed by the source as written. The walk stops looking after 50 usable images.

The check, in order, each step cheap and none touching the network:

1. Resolve the source (below). Anything that isn't a local file path stops here.
2. Read the file's resource values: it must be a regular file (so a FIFO or device can't block the read), at most 20 MB, and not an iCloud item whose download status is anything but current (reading one would start a download).
3. Open it with `CGImageSourceCreateWithURL` (`kCGImageSourceShouldCache: false`), require a type that conforms to `UTType.image`, and read the pixel width and height from its properties; at most 50 megapixels. This reads the header, not the pixels.

A file with no image spans skips all of this, so its open does no extra work.

Alternative: render `[alt]` first and swap in pictures as they decode. Rejected: every picture would push the text below it down while the user reads, and replacing `[alt]` with one attachment character would shift the outline's character offsets and those of every later picture. Knowing the size before the first paint avoids both, for the price of one header read per image.

### Resolving a source

- A source with a scheme: only `file:` counts, with an empty host or `localhost`; its percent-decoded path is used. `http:`, `https:`, `data:` and every other scheme keep `[alt]`.
- A source starting with `/` is an absolute path.
- Anything else is relative to the Markdown file's folder: `URL(string:relativeTo:)`, falling back to appending the raw text as a path when it isn't a valid URL (a destination written in `<…>` with spaces). A query or fragment (`?raw=true`, `#gh-dark-mode-only`, common in READMEs) is ignored. `~` is not expanded, as in a browser. `..` may leave the folder, and symlinks are followed.

### Any local path, like a browser opening a local page

The app isn't sandboxed, so a Markdown file could name any picture the user can read, such as one under their home folder. It only shows on their own screen or printout; nothing is sent anywhere. A browser treats a local HTML page the same way. Limiting pictures to the Markdown file's folder tree would break docs that share an `../assets` folder and absolute paths people write by hand. This is the recommendation; the maintainer may still prefer the folder-tree limit (see Open Questions).

### A picture is an attachment that knows its size

`MarkdownRenderer.render` takes the `images` lookup. For an image span with an entry it appends one attachment character instead of `[alt]`; otherwise it draws `[alt]` as today. The attachment is a small `NSTextAttachment` subclass holding the pixel size and the alt text. It overrides both bounds methods (TextKit 2's for the Peek panel, TextKit 1's for printing): width is the smaller of the pixel width and the proposed line fragment's width, height keeps the proportions. So pictures fit on any panel or page width, refit when the panel resizes, and never draw larger than one point per pixel.

Until decoded, the attachment holds a transparent image of that size, because an attachment with no image may draw a generic icon. The alt text becomes the image's `accessibilityDescription`, so VoiceOver reads it. A paragraph holding only an image lays out like any paragraph, so the picture sits on a line of its own; an image inside text sits on the baseline.

### Decode in the background, at the drawn size

After the first render, `MarkdownDocument` starts one task that decodes the document's pictures one at a time, in document order, so the first picture arrives first and only one full-size decode is in memory at once. Each decode is `@concurrent` and uses `CGImageSourceCreateThumbnailAtIndex` with `kCGImageSourceCreateThumbnailWithTransform`, `kCGImageSourceCreateThumbnailFromImageAlways` and `kCGImageSourceThumbnailMaxPixelSize` set to the longest side the picture is drawn at, times the window's backing scale, never more than the image's own longest side or 4,096 pixels. The drawn size uses the text width when that picture's decode starts (the picture's own width if the view has no width yet); a panel widened later draws that decode scaled up slightly rather than decoding again.

Back on the main thread, the result replaces the attachment's transparent image and the document redraws that character range. The bounds don't change, so nothing is laid out again and the text doesn't move. The document keeps the decoded pictures by file URL and modification date, so a theme change or a reload of the Markdown file fills new attachments at once without decoding again.

The task holds the document weakly and checks for cancellation between pictures. The document cancels it on deinit (the panel closed) and before starting a newer one (a reload or theme change), and the existing `renders` counter drops results from an older render.

A decode that fails after the header read passed (a damaged file) puts `[alt]` back in place of the attachment and shifts the later outline offsets by the length change. That's the one case where the text moves.

The ImageIO options repeat a few lines of `ImagePlugin.decode`. Plugins can't import each other, and it's the second copy, so it stays local until a third user would justify moving it to PeekerKit.

### Print decodes before the job is built

`printJob` is synchronous, so `MarkdownEditor.printText` takes the page's text width from the print info, finds images the same way as the parse (with the Editor's URL as the base) and decodes them right away at twice the drawn size, then renders. Print is a deliberate action and the work is bounded by the same caps; for a typical document it's a few milliseconds. `MarkdownDocument.printJob` does the same. Alternative: make `printJob` asynchronous. Rejected: a host contract change for one plugin's corner case.

### Checks

Unit tests use generated PNGs from `Tests/TestImages.swift` in a temporary folder: a local image becomes an attachment of the expected bounds for a given width, `http:` and `data:` images stay `[alt]`, a missing file and a text file stay `[alt]`, a relative path resolves against the Markdown file's folder (a subfolder and `..`), the 51st image stays `[alt]`, an image in a table stays `[alt]`, the text renders with transparent attachments before the decode finishes and the decoded image arrives afterwards, and the print text holds a decoded picture. The A/B benchmark's Markdown fixtures have no images, so it confirms that a file without them pays nothing; the cost with images is measured once by hand (a file with five photos, Peek panel time against the same file with the images removed) and reported with the change rather than added to the gate.

## Risks / Trade-offs

- [Header reads sit on the open path for files with local images] → Only for such files, at most 50, each a stat and a small read; measured once by hand. If it shows, the fallback is the rejected swap-in approach for images past the first screen.
- [Files on a network volume are read over the network] → They're files the user's system already mounted, not web fetches; see Open Questions.
- [Reading a picture in another protected folder (Desktop, Documents, Downloads, removable volumes) can raise the system's access prompt during a peek] → The prompt is macOS asking on the user's behalf; images beside the Markdown file share its folder, which Peeker can already read.
- [Memory with many large pictures] → One decode at a time, each at most the drawn size (about 10 MB for a square picture on a wide panel) and 4,096 pixels on its longest side, at most 50 per document.
- [Find no longer matches the alt text of a picture] → Accepted; the alt text stays available to VoiceOver.
- [An attachment without an image draws a placeholder icon on some TextKit paths] → Every attachment starts with a transparent image of its size; a unit test checks the attachment's image before decoding.

## Migration Plan

None. Files are only read; nothing new is stored. Reverting the change brings `[alt]` back.

## Open Questions

These don't change the approach or the tasks; each answer changes at most a cap or one sentence of the spec.

- Any local path, or only the Markdown file's folder and its subfolders? The design allows any path (above).
- Should files on network volumes show, or stay `[alt]` unless the Markdown file is on the same volume?
- Are the caps right: 20 MB per file, 50 megapixels, 50 pictures per document, 4,096 decoded pixels on the longest side?
- Should pictures show in table cells later, fitted to the 150-point column?
- Should `data:` images show later? They involve no network, but they're decoded from the file's own text on the open path.
- With `markdown-link-navigation`: a picture keeps the link its `[alt]` text had, which is the image's own source (so a linked image `[![a](a.png)](b.md)` links to `a.png`, not `b.md`). That change should decide what clicking a picture does.
- Should the benchmark gain a permanent Markdown fixture with images?
