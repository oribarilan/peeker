# Config

Settings live in `~/.config/peeker/config.json` (or `$PEEKER_CONFIG`). Change them in the Settings window (from the menu bar icon, or Cmd+,) or edit the file by hand. Every key is optional, and a missing one keeps its default. Saving the file applies it at once, open windows included; there's nothing to reload.

An agent can edit it for you too. Point it at `schema.json` in the same folder, which lists every key with its allowed values, its default and what it does.

```json
{
  "$schema": "schema.json",
  "peekPanel": { "key": "space" },
  "updates": { "automatic": "check", "showWhatsNew": true },
  "textTheme": "paper",
  "appearance": "system",
  "textAppearance": "light",
  "showShortcuts": true,
  "plugins": {
    "image": { "enabled": false },
    "markdown": { "extensions": ["markdown", "mdown"] },
    "text": { "extensions": ["txt", "md", "conf", "noExtension"] },
    "pdf": { "tools": { "highlight": { "shortcut": "cmd+shift+h" } } }
  }
}
```

- `peekPanel.key`: the key that opens the Peek panel. A bare key works only in Finder and not while typing; one with modifiers works anywhere; `"off"` turns the Peek panel off.
- `updates.automatic`: `"check"` (the default) looks for a new version once a day and offers it with its release notes; `"download"` also downloads it and installs it, relaunching quietly once no Peeker window is open; `"off"` checks only when you choose Check for Updates…. An update found while you work in another app waits behind a dot on the menu bar icon instead of opening a window.
- `updates.showWhatsNew`: `false` stops the window that lists what's new after Peeker updates.
- `textTheme`: the colors of Markdown and text files, in windows and the Peek panel: `system` (the default), `paper`, `slate`, `graphite`, `ink`, `catppuccin`, `tokyo-night` or `high-contrast`. Each has a light and a dark look. Settings > Appearance shows them as cards to pick from. Catppuccin and Tokyo Night use their projects' colors under the MIT license ([notices](THIRD_PARTY_NOTICES.md)).
- `appearance`: `system` (the default) follows the Mac; `light` or `dark` holds Peeker's windows in that look.
- `textAppearance`: which look of the text theme Markdown and text files use: `app` (the default) matches Peeker's appearance, and `light` or `dark` holds it, so a page can stay light in a dark app.
- `showShortcuts`: `false` takes the keys off the toolbar buttons; they stay in the tooltips, the menus and Settings.
- `plugins.<id>`: each entry is a format in Settings, such as `pdf` or `markdown`. Its keys below match that format's pane.
- `plugins.<id>.enabled`: `false` turns a format off. Peeker then opens none of its files; no other format takes them.
- `plugins.<id>.extensions`: every extension the format opens, without the dot, replacing its default list (`schema.json` lists each default). `noExtension` matches files with none, such as `.zshrc` and `Makefile`, and is on Plain Text's list. An extension belongs to one format: listed twice, it stays with the format that has it by default (above, `md` moves to Plain Text because Markdown's list drops it). Open With in a window can still switch one tab to another enabled format that reads the file, such as Plain Text for a Markdown file.
- `plugins.<id>.tools.<tool>.shortcut` rebinds a tool; `"off"` leaves it without one. Besides letters and digits, keys can be `space`, `esc`, `tab`, `enter`, `pageup` and `pagedown`.

Peeker writes `schema.json` next to the config at launch, so editors that read `$schema` autocomplete and check the keys. A key it doesn't know or a value it can't use is skipped and listed under Settings > Config file, and the menu bar icon shows a red dot until it's fixed; a file that isn't valid JSON changes nothing. Settings > Open in Text Editor creates the file when there's none.

Peeker never writes `config.json` on its own. A change made in the Settings window rewrites the whole file: every setting, defaults included, with sorted keys, so hand formatting and keys Peeker doesn't know are dropped then. A symlinked config stays a symlink. While the file isn't valid JSON, Settings locks until it's fixed.

Peeker lives in the menu bar while no files are open and gets a Dock icon and menus while they are.
