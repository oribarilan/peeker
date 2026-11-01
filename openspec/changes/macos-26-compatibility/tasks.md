# Tasks

## 1. Tests on every push

- [ ] 1.1 Add `.github/workflows/tests.yml` (design decision 5); verify it runs on a push to `main` and shows the same 15 failures as the release dry run

## 2. Probe

- [x] 2.1 Write the probe suite and workflow on a throwaway branch `probe/macos-26` (design decision 1) and push it; verify a run prints, for `/NM`, `/PeekerID` and the style key, whether each survives saving as PDFKit reads it and as CoreGraphics reads it, and whether a copied page shares its original's `pageRef`
- [x] 2.2 Decide fix or fallback by design decision 2 within about five runs; record what the probes showed and the outcome in `design.md`, update the `pdf` spec delta if it's the fallback, then delete the probe branch and its workflow; verify `openspec validate macos-26-compatibility --strict` passes and `git ls-remote --heads origin probe/macos-26` finds nothing

## 3. Saved marks on macOS 26

- [x] 3.1 Fix (design decision 2) or fall back (design decision 3) as decided; for a fix, the 13 mark tests pass on macOS 26 and 27 and a new test reads a mark saved by the previous build; for the fallback, a test checks the Edit mode reason on macOS 26 and the mark tests are enabled only on macOS 27; verify `scripts/build.sh test` passes locally (macOS 27) and in CI (macOS 26)

## 4. Drag on macOS 26

- [x] 4.1 Make thumbnails draggable only on macOS 27 or later (design decision 4), with the drag tests enabled only there and a new test that thumbnails aren't draggable on macOS 26; verify locally (macOS 27) and in CI (macOS 26)

## 5. Checks

- [x] 5.1 Remove the macOS 26 entry from `openspec/gaps.md`, adding a line that screen tests run only on macOS 27, and update the roadmap in `openspec/config.yaml`; verify `openspec validate --all --strict` passes
- [ ] 5.2 Verify the tests workflow is green on `main` after a push (with the maintainer's OK), `scripts/build.sh test` and `scripts/check-plugin-imports.sh` pass locally with no warnings, and the pdf-edit and pdf-pages screen flows pass locally (with the maintainer's go)

## Workflow follow-up

- Archive `pdf-fill-and-sign` and `pdf-page-operations` before this change, then archive it with `/opsx:archive`.
- Resume the releases change: its GitHub dry run, the on-screen image flow and its final check.
