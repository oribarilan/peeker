# Tasks

## 1. Renames (no behavior change)

- [x] 1.1 Rename the PDF document's `tools` property (its `EditController`) to `editController`; verify the build and the PDF tests pass
- [x] 1.2 Rename "commands" to "tools" in code: `CommandSpec` → `ToolSpec`, `Plugin.commands` / `PluginDocument.commands` / `PluginEntry.commands` / `DocumentViewController.commands` → `tools`, `activeCommand` / `onActiveCommandChange` → `activeTool` / `onActiveToolChange`, `unavailableReason(for command:)` → `(for tool:)`, `runCommand` → `runTool`, `rebuildCommands` → `rebuildTools`, `Shortcut.Rules.command` → `.viewTool`, and tests and test plugins with them; verify `scripts/build.sh` has no warnings and `scripts/build.sh test` passes

## 2. The config's `tools` section

- [x] 2.1 Update the config tests first: `plugins.<id>.tools.<tool>.shortcut` sets a shortcut, `plugins.<id>.commands` is reported as an unknown key and leaves defaults, rendering writes `tools`, the schema has `tools` and no `commands`, and the README example uses `tools`; watch them fail. Then change reading, rendering, the schema and the README; verify the tests pass

## 3. Editability in the contract and the host

- [x] 3.1 Write failing tests: a document's `editability` defaults to `.notEditable`; an editable document opens in the Editor with its edit tools in the toolbar and Tools menu and no Edit button; Tools shows a greyed No Tools item for a document without edit tools and with no Editor window; a recovered record applies to an editable document straight away. Then replace `EditMode`/`editMode`/`setEditing` with `Editability`/`editability`, remove `isEditing`, `toggleEditing`, the leave-Edit-mode prompt, the Edit button, Tools > Edit Mode and `Shortcut.editMode`; verify the tests pass
- [x] 3.2 Write failing tests for read-only documents: every edit tool's menu item and toolbar button is greyed out with the reason as tooltip; an edit tool's shortcut shows the reason and runs nothing; the window shows a one-line note under the toolbar with the reason; a replacement that becomes editable removes the note. Then add the host's read-only handling and `ReadOnlyNote`; verify the tests pass
- [x] 3.3 Write failing tests for single keys: C starts Crop in an editable image window right after opening; a focused text field gets the "c"; a read-only image ignores C. Then change the key monitor; verify the tests and the existing single-key tests pass

## 4. Plugins

- [x] 4.1 Write failing PDF tests: right after opening, typing into a form field changes it and marks the document edited; Text Box, Sign, Highlight and the page tools work without any mode switch; a thumbnail drag reorders pages right after opening; an XFA, permission-locked, signed or password-unlocked PDF is `.readOnly` with today's reasons, refuses field input and thumbnail drags; the edit machinery isn't created until a tool or field is first used. Then move the PDF plugin to `Editability` with `prepareEditing()` on first use; verify the tests and the existing PDF suites pass
- [x] 4.2 Write failing image tests: an editable image crops and opens Rotate & Resize right after opening; an animated GIF, a RAW file and an over-100 MP image are `.readOnly` with today's reasons. Then move the image plugin to `Editability`; verify the tests and the existing image suites pass
- [x] 4.3 Move the text and Markdown plugins and every test plugin to the new contract (text stays editable with no edit tools, Markdown `.notEditable`); verify `scripts/build.sh test` passes, including the plugin import check

## 5. Peek panel and Settings

- [x] 5.1 Change the Peek panel's button to "Open in Peeker" and Settings' plugin panes to say "Tools"; add a test for the button's title; verify the tests pass

## 6. Terminology in docs and comments

- [x] 6.1 Update README, AGENTS.md, `.claude/skills/run-peeker/SKILL.md`, `openspec/config.yaml`'s Direction paragraph, `openspec/gaps.md` and code comments: Editor for the window's role, tools for commands, no Edit mode or read view; verify a grep for "Edit mode", "read view", "command" in the plugin sense and "document window" over current files (history excluded) finds only intended uses

## 7. Screen tests

- [x] 7.1 Remove every `menu Peeker Tools "Edit Mode"` step; pdf-edit checks the Peek panel's button reads Open in Peeker and the panel ignores typing into a field and that fields fill right after opening, and adds a read-only PDF check (greyed tools and the note, with a `pdf-tool` fixture if needed); pdf-pages ends by closing with Don't Save instead of leaving Edit mode; image-edit crops right after opening; recovery checks the PDF comes back with its edits; update the run-peeker skill; verify `bash -n` on each script and that the driver and `pdf-tool` build

## 8. Wrap-up

- [x] 8.1 Add Unreleased lines to `CHANGELOG.md`; verify `openspec validate --all --strict`
- [x] 8.2 Run `scripts/build.sh` and `scripts/build.sh test` twice; verify all tests pass with no new warnings
- [x] 8.3 With the maintainer's go, run `scripts/screen-test.sh`; verify every flow passes and look at the PDF, image and read-only captures and the Peek panel capture for the button's title
- [x] 8.4 With the maintainer's go, run `scripts/bench-ab.sh <base> --launches 15` against the commit before this change; verify PDF and image window opens don't regress

## Workflow follow-up

- Archive with `/opsx:archive`, then retitle any scenario OpenSpec couldn't rename (for example "A menu key refused for a command" in `plugin-host`) and run `openspec validate --all --strict`.
