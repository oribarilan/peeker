# Tasks

## 1. Highlighter

- [x] 1.1 Add the armed highlighter to `EditController` and `PeekerPDFView.mouseUp` (design decision 1), make the highlight command highlight a selection and arm, and rename it "Highlight"; tests first: arming then a selection highlights it once and disarms, a selection made first is highlighted and the highlighter stays armed, Escape and Text Box disarm, and the command's title is "Highlight"; verify `scripts/build.sh test` passes

## 2. Tool hints

- [x] 2.1 Add `activeCommand` and `onActiveCommandChange` to `PluginDocument` with defaults, and show the active command as the toolbar's selected item and checked in the Commands menu (design decision 6); tests first with a stub document: naming a command selects its toolbar item and checks its menu item, naming none clears both
- [x] 2.2 Have `PDFPluginDocument` name its active tool (text-box, sign, highlight) from `EditController`, reporting each change (design decision 6); tests first: arming the highlighter or choosing Text Box or Sign names it, using or dismissing the tool names none
- [x] 2.3 Show each waiting tool's cursor over the page (design decision 7); verify on screen with screenshots of the toolbar and the pointer while Highlight and Text Box wait (with the maintainer's go)

## 3. Clearing a shortcut

- [x] 3.1 Add `Config.noShortcut` with `off` in reading, rendering and the schema (design decision 2), and make recording and Reset update it; tests first: `off` leaves a command without a shortcut and without a problem, a rendered config round-trips `off`, and Reset brings the default back; update the README's config section
- [x] 3.2 Add the clear button beside each recorder (design decision 3), with the recorder showing "None" for a cleared command; unit test that clearing through the settings model writes `off`
- [x] 3.3 Add a step to `record-flows.sh` that clears Zoom In's shortcut in the PDF pane and checks `config.json`, then resets it; verify the flow passes on screen (with the maintainer's go)

## 4. Settings on a hand launch

- [x] 4.1 Add `showsSettingsAtLaunch` and the reopen handling (design decision 4), reading the login marker in `applicationWillFinishLaunching`; tests first for the decision (nothing opened and not at login: show; a file or a recovered window opened: don't; at login: don't)
- [x] 4.2 Make `record-flows.sh` check that its launch with no file shows Settings and close it before the Space checks; verify the full screen-test suite passes (with the maintainer's go)

## 5. Checks

- [x] 5.1 Run `scripts/build.sh test` (no new warnings), `scripts/check-plugin-imports.sh` and `openspec validate --all --strict`; reinstall the app in /Applications for the maintainer, and list for them what to try by hand: the highlighter on a real PDF, and a login launch staying quiet

## Workflow follow-up

- Archive `settings-window` before this change (its plugin pane requirement comes first), then archive this one with `/opsx:archive`.
