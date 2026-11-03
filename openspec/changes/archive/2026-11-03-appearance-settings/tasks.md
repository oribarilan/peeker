# Tasks

## 1. Text appearance

- [x] 1.1 Write failing tests: `TextTheme.appearance` defaults to nil (Match App); setting another value posts `didChange`, setting the same doesn't. Then add it to `TextTheme`; verify the tests pass

## 2. Config and app

- [x] 2.1 Write failing tests: `appearance` and `textAppearance` read, render and round-trip; missing keys give `system` and `app`; an unknown value or a non-string is a problem naming the allowed values and leaves the default; the schema has an enum and default for each; `textTheme` still behaves as before. Then add them to `Config` with one reader for the three named choices, rendering and schema; verify the tests pass
- [x] 2.2 Write failing tests: the app sets `NSApp.appearance` and `TextTheme.appearance` from the config at launch and when it changes; `SettingsModel` saves both. Then wire `AppDelegate` and the model; verify the tests pass

## 3. Views

- [x] 3.1 Write failing tests: a text document, the Markdown Editor and the Peek panel's Markdown view take the text appearance on their scroll view, resolve the theme in that variant (Paper's light background with Light while the app is dark, and the reverse), follow a change at once keeping text and edits, and go back to the app's look with Match App. Then update `TextDocument`, `MarkdownEditor` and `MarkdownDocument`; verify the tests pass

## 4. Settings

- [x] 4.1 Write failing tests: the sidebar order is General, Appearance, the plugins, Permissions, Config File; `.appearance` round-trips its storage key; a card's colors resolve to the theme's light or dark values for the chosen variant, and to the pane's own scheme for Match App. Then add `.appearance`, `AppearancePane` with the two pickers and the card grid, and remove the pop-up from `GeneralPane`; verify the tests pass

## 5. Find highlights

- [x] 5.1 Bring in the experiment's outcome: themed find highlights through the views' own text finder (`ThemedFindTextView`), with a fallback to the system find bar if that finder ever refuses to show, and their tests; the text-themes delta says the current match keeps the system's indicator; verify `openspec validate --all --strict`

## 6. Docs and version

- [x] 6.1 Update README (Settings and config lines) and CHANGELOG (Unreleased), and bump `MARKETING_VERSION` to `0.4.0-dev`; verify `openspec validate --all --strict`

## 7. Screen tests

- [x] 7.1 Update the theme flow: open Settings > Appearance, click the Paper card and check `"textTheme": "paper"` and the windows' Paper background; pick Dark for Appearance and check the config and a dark Settings window; pick Light for Text appearance and check the Markdown window shows Paper's light background in the dark app; the unknown-theme step still passes; reset at the end. Check the flows suite's sidebar steps still find their rows; verify `bash -n`

## 8. Wrap-up

- [x] 8.1 Run `scripts/build.sh` and `scripts/build.sh test` twice; verify all tests pass with no warnings
- [x] 8.2 Run `scripts/screen-test.sh`; verify every flow passes and look at the Appearance captures

## Workflow follow-up

- The benchmark waits for the maintainer, who postponed it.
- Archive with `/opsx:archive` once done.
