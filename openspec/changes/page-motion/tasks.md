# Tasks

## 1. Motion

- [x] 1.1 Port the prototype's tests to `Tests/PDFPageMotionTests.swift` (rotate turns while the edit is already applied, delete shrinks, undoing a delete grows, Reduce Motion and edits outside a window don't animate, only pages on screen do) and watch them fail.
- [x] 1.2 Add `Plugins/pdf/PageMotion.swift` and call it from `PDFPluginDocument.applyLive`; verify the tests pass and `scripts/build.sh test` has no warnings.

## 2. Checks

- [ ] 2.1 Run the `pdf-pages` screen flow; record a rotate, a delete and an undo in light and dark, and with Reduce Motion, and look at them.
- [x] 2.2 Add a CHANGELOG line under Unreleased and verify `openspec validate --all --strict`.

## Workflow follow-up

- Commit the change, then bump the minor version in its own commit; archive.
