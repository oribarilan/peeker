# Tasks

Each code task starts with a failing Swift Testing test next to the existing suites in `Tests/`, then the code, then `scripts/build.sh test` passing with no new warnings.

## 1. Heading names and link resolution (Markdown plugin)

- [x] 1.1 Write failing tests for `HeadingNames`: `What's new?` → `whats-new`; ``The `peek` **command**`` → `the-peek-command`; non-ASCII letters kept (`Café au lait` → `café-au-lait`); emoji and punctuation dropped; two spaces give two hyphens; repeats get `-1`, `-2` in order; matching ignores case and decodes percent escapes; an `<a id>` anchor matches nothing; the Editor's and the panel's outlines give the same names for one file. Then add `Plugins/markdown/HeadingNames.swift`; verify the tests pass
- [x] 1.2 Write failing tests for `LinkOpener.resolve(_:against:)`: `other.md`, `./notes/a.txt`, `../up.md`, `docs/guide.md#setup` (fragment kept), `my%20notes.md` and a `<my notes.md>` destination resolve against the file's folder; `/abs/x.md` starts at the disk's root; a query is dropped; `#install` alone resolves to the file itself with that fragment; `https:`, `mailto:` and `file:` destinations are left to `open` as today. Then add it; verify the tests pass

## 2. The contract and the history (PeekerKit and host, no UI yet)

- [x] 2.1 Add `LinkFollowing` to `Sources/PeekerKit/Plugin.swift` as in the design, with doc comments; verify `scripts/build.sh test` passes and the plugin import check still holds
- [x] 2.2 Write failing tests for `NavigationHistory`: starts with one entry and nothing back or forward; push moves forward; back and forward several steps; push after back drops the entries ahead; `move(to:)` any index; recording a position on the current entry and reading it back after back then forward; Open With replaces the current entry's plugin and clears its position. Then add `Sources/Host/Documents/NavigationHistory.swift`; verify the tests pass
- [x] 2.3 Write failing tests for `LinkRoute` with stub lookups: missing file → beep; same file with a name → place; same file without one → nothing; file open in another window → bring it forward; owned by the current entry's plugin → same tab; owned by another enabled plugin → own tab; no enabled plugin, or a folder → ask; same-file and open-elsewhere checks see through a symlink. Then add `Sources/Host/Documents/LinkRoute.swift`; verify the tests pass

## 3. Markdown documents adopt the contract

- [x] 3.1 Write failing tests for `MarkdownEditor`: Cmd-click on `other.md` calls `onFollowLink` with the resolved URL and on a web link still calls `LinkOpener`; a plain click on a link places the cursor; `go(to: "install")` puts the cursor at the start of the Install line and returns "Install", and returns nil for a missing name; in a file over 64 KB `go(to:)` finds a heading past the first parse; `position` then `restore` after scrolling elsewhere returns to the same top line and selection, and clamps after the text got shorter. Then adopt `LinkFollowing` in `MarkdownEditor.swift`; verify the tests pass
- [x] 3.2 Write failing tests for `MarkdownDocument` (Peek panel): a click on a relative link calls `onFollowLink` with the URL resolved against the file; `go(to:)` scrolls to the heading and returns its title; `position`/`restore` round-trip. Then adopt it in `MarkdownDocument.swift`; verify the tests pass

## 4. Following links in Editor windows

- [x] 4.1 Write failing tests: `DocumentViewController` forwards `onFollowLink` from a document that adopts the protocol and sets nothing on one that doesn't. Then wire it; verify the tests pass
- [x] 4.2 Write failing tests in a window test suite: following `#install` moves the view and pushes an entry, a missing heading beeps and pushes nothing; following `other.md` shows it in the same tab with the window's title, `representedURL` and Open With choices following, and `AppDelegate` finds the window by its new file; `other.md#setup` lands at Setup once the content shows; a `.txt` link opens a new tab and leaves the history alone; a file no plugin opens asks first; a link to a file open in another window brings that window forward. Then move `url` to `private(set) var` and add `DocumentWindowController+Navigation.swift`; verify the tests pass and `DocumentWindowController.swift` stays under 500 lines
- [x] 4.3 Write failing tests: Back after a file jump restores the earlier file at its recorded position; two Backs then Forward land on the right entry; a new jump after Back drops Forward; Back within one file only restores the position; Back to a deleted file or one whose plugin is now off beeps and keeps the index; Back returns to a file with the plugin it was shown with after Open With. Then add Back, Forward and `move(to:)`; verify the tests pass
- [x] 4.4 Write failing tests with `askToSave` answering directly: leaving an edited file through a link, Back, Forward or a crumb asks; Cancel keeps the file, its edits and the history index; Don't Save goes on and Back shows the saved text; Save writes then goes on; a heading jump in an edited file never asks. Then route file switches through `resolveUnsavedEdits()`; verify the tests pass
- [x] 4.5 Write a failing test: after following links, a crash-recovered window for the edited file opens with one history entry, and closing the tab drops its history. Then fix anything it shows; verify the test passes

## 5. Controls: toolbar, Go menu, trail

- [x] 5.1 Write failing tests: a Markdown window's toolbar has Back then Forward after the sidebar button and its tracking separator and before Open With, labeled and greyed out at first; a PDF or text window has neither; Back enables after a jump and Forward after Back; after a same-tab switch both are in the rebuilt toolbar before the new content shows. Then add the toolbar items and their validation; verify the tests pass
- [x] 5.2 Write failing tests in `MainMenuTests`: the menu bar holds Peeker, File, Edit, View, Go, Tools, Window, Help; Go has Back (Cmd-[) and Forward (Cmd-]); both greyed out with no Editor window in front and in a window with no history in that direction; the fixed-shortcut list still refuses existing keys. Then add Go to `MainMenu.make` and the actions on the window controller; verify the tests pass
- [x] 5.3 Write failing tests for `HistoryTrail`: hidden with one entry, shown with two; crumbs read `README.md`, `Install`, `other.md` with the current one marked; each crumb has an accessibility label and a tooltip with file name and heading; clicking a crumb moves the history there through the same path as Back. Then add the trail as a bottom titlebar accessory; verify the tests pass
- [x] 5.4 Render a Markdown window with a three-entry trail in light and dark, with the sidebar shown and hidden and at the minimum width, and check the trail under the toolbar against the macOS design guidance; move it above the content (design's fallback) if it sits badly over the sidebar; verify with the screenshots

## 6. Peek panel

- [x] 6.1 Write failing tests in `PeekPanelTests`: a heading link scrolls the panel and opens nothing; a link to another Markdown file dismisses the panel and opens it in an Editor window at the named heading; a `.txt` link does the same with Plain Text; a missing file beeps and the panel stays; no history is kept. Then handle `onFollowLink` for the panel in `AppDelegate` and add `openInWindow(_:place:)`; verify the tests pass

## 7. Docs, specs and screen flow

- [x] 7.1 Add a CHANGELOG line under Unreleased (links to other files and headings in Markdown work, with Back, Forward and a trail); in `openspec/gaps.md` drop "relative links such as `other.md` most likely do nothing (untested)" from the Markdown line, leaving whatever the `markdown-local-images` change left; verify `openspec validate --all --strict` passes
- [x] 7.2 Extend `scripts/screen/markdown-edit-flow.sh`: write `notes.md` linking to `#later` and to a new `other.md`, Cmd-click the heading link and check the cursor's line, Cmd-click the file link and check the window title is `other.md`, read the trail's crumbs through Accessibility, press Cmd-[ and check `notes.md` is back at its scroll position, click a crumb; and in the panel click the file link and check an Editor window opens. Verify `bash -n`; add the run to `.local/screen-queue.md` for the maintainer's go
- [x] 7.3 Bump `MARKETING_VERSION` in `project.yml` to the next minor version in its own commit after this change's (from `0.6.1-dev` to `0.7.0-dev` unless another change bumped it first); verify `scripts/build.sh` builds

## 8. Wrap-up

- [x] 8.1 Run `scripts/build.sh` and `scripts/build.sh test` twice; verify every test passes with no warnings
- [x] 8.2 With the maintainer's go, run `scripts/bench-ab.sh <commit before this change>` and verify opening Markdown in a window and in the Peek panel doesn't regress
- [x] 8.3 With the maintainer's go, run `scripts/screen-test.sh` and verify every flow passes, the new Markdown steps included

## Workflow follow-up

- Archive with `/opsx:archive` once the maintainer accepts the change.

The four changes landed together, so they share one bump, to `0.7.0-dev` (8a40ced).
