# Tasks

## 1. Editor

- [x] 1.1 File > Show in Finder after Open With, no key, answered only by `DocumentWindowController`, which reveals the tab's file through an injected `revealInFinder`. Tests: placement, no key, reveals the tab's URL.
- [x] 1.2 Toolbar button `showInFinder` after Open With in every window. Tests: toolbar order with and without a sidebar; the button reveals the file.

## 2. Peek panel

- [x] 2.1 `OpenWithItem.showInFinder` last in the button's menu; choosing it closes the panel and reveals the file. Tests: menu order, reveal without opening anything.
- [x] 2.2 Folder button left of Open in Peeker in the title bar, laid out with it when the title changes. Test: target, action, tooltip, placement.

## 3. Checks and docs

- [x] 3.1 `scripts/build.sh test` passes with no warnings.
- [ ] 3.2 On screen: the toolbar button and the panel's folder button look right in light and dark, a long file name still fits the panel's title bar, and each opens Finder with the file selected; add a step to a screen flow (queued until the maintainer's go).
- [x] 3.3 CHANGELOG line; backlog line for the tab's right-click menu; `openspec validate --all` passes.

## Workflow follow-up

- Commit to local main, then bump `MARKETING_VERSION` to the next minor `-dev` in its own commit.
- Archive once the screen step has passed.
