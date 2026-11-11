# Tasks

## 1. Prove the risky part

- [x] 1.1 In a scratch build, show an `NSOpenPanel` as a sheet on the Peek panel after `NSApp.activate()`, then Cancel and reactivate Finder; verify by hand in the real app that the picker takes typing and that the arrow keys move Finder's selection afterwards. If it fails, stop and ask the maintainer.

## 2. Config

- [x] 2.1 Add `peekPanelOpenWith` to `Config`, read `peekPanel.openWith` in `ConfigReader` with a problem per bad entry; failing tests first in `Tests/ConfigTests.swift` (normalized `.SWIFT`, a number value, `noExtension`, an unknown key under `peekPanel` still reported).
- [x] 2.2 Render `openWith` in `Config.json(plugins:)` and describe it in `ConfigSchema`; tests: round trip keeps entries, an empty config writes `{}`, the schema lists `openWith`.

## 3. Menu contents

- [x] 3.1 Add `PeekOpenWithMenu` (new file in `Sources/Host/PeekPanel/`) building the ordered items: Mac default first, rest A to Z, no Peeker, no button app, one per bundle ID; Peeker and Always Open in Peeker when another app is the default; Other… last. Tests in `Tests/PeekPanelTests.swift`.

## 4. The panel

- [x] 4.1 Replace the button with a split `NSComboButton`; its title comes from `openWith` and the injected app lookup ("Open in Xcode", or Open in Peeker when there's no entry or the app is missing); tests for both titles and the unchanged default.
- [x] 4.2 Fill the menu in `menuNeedsUpdate(_:)` from `urlsForApplications(toOpen:)` with icons; picking an app dismisses and opens with `activates = true`; Peeker opens the Editor; Always Open in Peeker reports `onSetDefault(ext, nil)` and opens the Editor. Test the actions with injected open and save functions.
- [x] 4.3 Other…: the open-panel sheet with the Always checkbox (left out for no extension), `onSetDefault(ext, id)` when ticked, Finder reactivated on Cancel. Unit-test the checkbox title and that it's absent without an extension.
- [x] 4.4 Wire it in `AppDelegate`: pass `config.peekPanelOpenWith` in `showInPanel`, save `onSetDefault` through `ConfigStore.save`, alert on the panel when saving fails. Verify with `scripts/build.sh test`, and a build that has no warnings.

## 5. Checks and docs

- [x] 5.1 Add a screen-flow step: the panel's menu lists Other…, and with a default in the config the button reads Open in <app> (run with the maintainer's go).
- [x] 5.2 Check by hand: pick an app once, choose a default through Other…, Always Open in Peeker, Cancel then arrow keys with two Finder windows.
- [x] 5.3 CHANGELOG line under Unreleased; backlog: drop the Open With line and add "Other apps in the Editor's File > Open With"; `openspec validate --all` passes.
- [x] 5.4 `scripts/bench-ab.sh main` shows no regression on the Peek panel.

## Workflow follow-up

- Commit the change, then bump `MARKETING_VERSION` to the next minor `-dev` in its own commit.
- Archive with `/opsx:archive` once the screen step has passed.
