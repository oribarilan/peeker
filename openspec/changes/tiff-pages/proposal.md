# Proposal

## Why

A multi-page TIFF (a scanned document, a fax, a multi-page export) shows only its first page in Peeker, while Preview shows them all. It's listed under "Missing next to Preview" in `openspec/gaps.md`, and it blocks using Peeker as the daily image viewer for scans.

## What Changes

- In the Editor, a multi-page TIFF shows one page at a time with a thumbnail of every page in the sidebar; a click on a thumbnail shows that page.
- Next Page and Previous Page, new view tools in the View menu, move between pages, on Page Down and Page Up by default and rebindable like other tools. They appear only for a multi-page TIFF.
- Moving to another page keeps the zoom: fit stays fit, a set zoom stays, scrolled to the top left.
- The info panel describes the page shown and says which page of how many.
- File > Print prints every page, each on its own sheet by the rules a single image follows.
- The Peek panel keeps showing the first page. Editing stays read-only for a multi-page TIFF, as today.
- Shortcuts gain Page Up and Page Down (`pageup`, `pagedown` in the config), which a view tool may use without Command, Option or Control since they type nothing.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `image`: pages for multi-page TIFFs (a new requirement), page details in the sidebar, printing every page, and the animated-images requirement no longer saying a TIFF shows only its first page.
- `plugin-host`: the shortcut rules allow Page Up and Page Down alone for view tools.

## Impact

- `Plugins/image/`: decoding by page in `ImagePlugin`, page state and tools in `ImageDocument`, a new thumbnail list view, a multi-page print view.
- `Sources/Host/App/Shortcut.swift` and the Settings key recorder: the two new keys.
- Tests in `ImagePluginTests`, `ImageDocumentTests`, `ShortcutTests`, `PrintTests`; a multi-page TIFF test helper in `TestImages.swift`.
- `config/schema` text if it lists key names; `CHANGELOG.md`; `openspec/gaps.md`; a minor version bump.
