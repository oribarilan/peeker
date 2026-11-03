# Tasks

## 1. Toolbar

- [x] 1.1 Write failing tests: with a sidebar, the default toolbar items start with the sidebar button and a sidebar tracking separator, then Open With; without one, Open With comes first; Wrap Lines' symbol is `text.alignleft`. Then update `DocumentWindowController` and `TextPlugin`; verify the tests pass

## 2. Outline

- [x] 2.1 Write failing tests: moving the pointer over an outline row marks it hovered and leaving clears it, without changing the selection or calling back; `mark` selects a row, or none, without calling back. Then update `OutlineList`; verify the tests pass
- [x] 2.2 Write failing tests: in the Editor, moving the cursor under a heading marks that heading in the outline; above the first heading nothing is marked; clicking a heading marks it; after typing a new heading and the refresh, moving into it marks it. Then wire `MarkdownEditor`; verify the tests pass

## 3. Docs and version

- [x] 3.1 Add Unreleased lines to CHANGELOG and bump `MARKETING_VERSION` to `0.5.0-dev`, committed after this change; verify `openspec validate --all --strict`

## 4. Screen tests

- [x] 4.1 Add steps: in the markdown-edit flow, the sidebar button sits left of the sidebar's right edge (its frame against the outline's), and moving the cursor into a section marks its heading (the outline row's selected state); in the viewer flow, the Wrap Lines button is found by its label as before. Verify `bash -n`

## 5. Wrap-up

- [x] 5.1 Run `scripts/build.sh` and `scripts/build.sh test` twice; verify all tests pass with no warnings
- [x] 5.2 Run `scripts/screen-test.sh`; verify every flow passes and look at the toolbar captures

## Workflow follow-up

- Archive with `/opsx:archive` once done.
